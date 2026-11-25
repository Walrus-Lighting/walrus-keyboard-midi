import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<BoardEngine>.fromOpaque(refcon).takeUnretainedValue()
    return engine.handle(type: type, event: event)
}

final class BoardEngine: ObservableObject {
    static let lightkeyID = "de.monospc.Lightkey"

    @Published var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            if oldValue.bpm != settings.bpm { beatEpoch = Date().timeIntervalSince1970 }
            if oldValue.bpm != settings.bpm { restartClock(reset: true) }
            else if oldValue.sendClock != settings.sendClock { restartClock() }
            // Drop state for keys that are no longer toggles / no longer configured.
            active = active.filter { settings.config($0).type == .toggle }
            pressed = pressed.filter { settings.config($0).type != .off }
        }
    }
    @Published var keyboardConnected = false
    @Published var midiReady = false
    @Published var hasAccessibility = false
    @Published var tapRunning = false
    @Published var pressed: Set<String> = []     // keys currently held down
    @Published var active: Set<String> = []      // toggle keys that are currently flashing
    @Published var detecting = false
    @Published var tapsCollected = 0             // 0 = tempo is set; 1-3 = waiting for the rest of the taps
    @Published var statusLine = ""

    private let hid = HIDLink()
    private let midi = MIDIPort()
    private let hidQueue = DispatchQueue(label: "walruskeyboardmidi.hid")
    private var sending = false
    private var lastFrame: [RGB] = []
    private var tap: CFMachPort?
    private var swallowedDown = Set<Int>()
    private var started = false

    // tempo
    private var beatEpoch = Date().timeIntervalSince1970   // moment of a beat; Beat keys and the MIDI clock both count from here
    private var tapTimes: [TimeInterval] = []
    private var tapTimeout: DispatchWorkItem?
    let tapsNeeded = 4
    private let tapGiveUp: TimeInterval = 3.0   // no tap for this long: forget the taps, keep the old BPM
    private var clockTimer: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "walruskeyboardmidi.clock", qos: .userInteractive)

    init() {
        settings = Settings.load()
    }

    // MARK: start up

    func start() {
        guard !started else { return }
        started = true
        midi.onNote = { [weak self] note, on in self?.feedback(note: note, on: on) }
        midi.start()
        midiReady = midi.isReady

        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.tick() }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.watch() }
        restartClock()
        watch()
    }

    /// Once a second: reconnect to the keyboard, retry the key tap, refresh permission status.
    private func watch() {
        hasAccessibility = AXIsProcessTrusted()
        ensureTap()
        hidQueue.async { [weak self] in
            guard let self = self else { return }
            let was = self.hid.isConnected
            let ok = self.hid.connect()
            DispatchQueue.main.async {
                if ok && !was { self.lastFrame = [] }   // send a full frame on (re)connect
                self.keyboardConnected = ok
            }
        }
        if !midiReady { midi.start(); midiReady = midi.isReady }
    }

    // MARK: lights

    /// 0 at the instant of a beat, rising to just under 1 before the next one.
    private var beatPhase: Double {
        let period = 60.0 / max(10, settings.bpm)
        let x = (Date().timeIntervalSince1970 - beatEpoch) / period
        return x - x.rounded(.down)
    }

    private func buildFrame(flashOn: Bool) -> [RGB] {
        var cols = [RGB](repeating: .off, count: Board.ledCount)
        for key in Board.all {
            let cfg = settings.config(key.id)
            let c: RGB
            switch cfg.type {
            case .off: c = .off
            case .steady: c = cfg.colour
            case .toggle: c = active.contains(key.id) ? (flashOn ? cfg.colour : .off) : cfg.colour
            case .flash, .double, .half: c = pressed.contains(key.id) ? .white : cfg.colour
            case .tap: c = tapsCollected > 0 ? .tapWaiting : .tapReady
            case .beat: c = beatPhase < 0.3 ? cfg.colour : .off
            }
            if key.led < cols.count { cols[key.led] = c }
        }
        return cols
    }

    private func tick() {
        guard settings.enabled, keyboardConnected, !sending else { return }
        let speed = max(0.05, settings.flashSeconds)
        let flashOn = Int(Date().timeIntervalSince1970 / speed) % 2 == 0
        let frame = buildFrame(flashOn: flashOn)
        let changed = frame != lastFrame
        lastFrame = frame
        sending = true
        hidQueue.async { [weak self] in
            guard let self = self else { return }
            let ok = changed ? self.hid.sendFrame(frame) : self.hid.keepAlive()
            DispatchQueue.main.async {
                self.sending = false
                if !ok { self.keyboardConnected = false }
            }
        }
    }

    // MARK: key presses

    private func ensureTap() {
        if let t = tap {
            if !CGEvent.tapIsEnabled(tap: t) { CGEvent.tapEnable(tap: t, enable: true) }
            tapRunning = CGEvent.tapIsEnabled(tap: t)
            return
        }
        guard AXIsProcessTrusted() else { tapRunning = false; return }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: eventTapCallback, userInfo: refcon) else {
            tapRunning = false
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        tapRunning = true
    }

    private func shouldSwallow() -> Bool {
        switch settings.swallow {
        case .always: return true
        case .never: return false
        case .lightkey: return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == BoardEngine.lightkeyID
        }
    }

    /// Runs for every key press on the whole Mac, before any app sees it. Returning nil swallows the key.
    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return pass
        }
        guard type == .keyDown || type == .keyUp else { return pass }

        let ktype = Int(event.getIntegerValueField(.keyboardEventKeyboardType))
        if detecting {
            if type == .keyDown {
                settings.keyboardType = ktype
                detecting = false
                statusLine = "Fnatic keyboard detected (type \(ktype))."
            }
            return pass
        }
        guard settings.enabled, ktype == settings.keyboardType else { return pass }

        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard let key = Board.byCode[code], !key.isModifier else { return pass }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) { return pass }

        let cfg = settings.config(key.id)
        guard [.toggle, .flash, .tap, .double, .half].contains(cfg.type) else { return pass }
        let noNote = [KeyType.tap, .double, .half].contains(cfg.type)
        guard let note = cfg.note ?? (noNote ? 0 : nil) else { return pass }

        if type == .keyDown {
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                return swallowedDown.contains(code) ? nil : pass
            }
            let swallow = shouldSwallow()
            if swallow { swallowedDown.insert(code) }
            press(key.id, cfg, note)
            return swallow ? nil : pass
        } else {
            let swallow = swallowedDown.remove(code) != nil
            release(key.id, cfg, note)
            return swallow ? nil : pass
        }
    }

    private func press(_ id: String, _ cfg: KeyConfig, _ note: Int) {
        pressed.insert(id)
        switch cfg.type {
        case .toggle:
            if active.contains(id) {
                active.remove(id)
            } else {
                if settings.exclusiveToggles { active.removeAll() }
                active.insert(id)
            }
            midi.send(note: note, on: true)
            midi.send(note: note, on: false)
        case .flash:
            midi.send(note: note, on: true)
        case .tap:
            tapTempo()
        case .double:
            setBPM(settings.bpm * 2)
        case .half:
            setBPM(settings.bpm / 2)
        default: break
        }
    }

    private func release(_ id: String, _ cfg: KeyConfig, _ note: Int) {
        pressed.remove(id)
        if cfg.type == .flash { midi.send(note: note, on: false) }
    }

    // MARK: tempo

    /// Tap 4 times in rhythm. Nothing changes until the 4th tap, then the BPM becomes the average of the taps
    /// and a beat lands on that last tap. While waiting, the tap key is yellow; once the tempo is set it is blue.
    func tapTempo() {
        let now = Date().timeIntervalSince1970
        if let last = tapTimes.last, now - last > tapGiveUp { tapTimes = [] }
        tapTimes.append(now)
        tapTimeout?.cancel()

        if tapTimes.count >= tapsNeeded {
            let used = Array(tapTimes.suffix(tapsNeeded))
            let averageGap = (used.last! - used.first!) / Double(tapsNeeded - 1)
            tapTimes = []
            tapsCollected = 0
            setBPM(60.0 / averageGap)
        } else {
            tapsCollected = tapTimes.count
            let giveUp = DispatchWorkItem { [weak self] in
                self?.tapTimes = []
                self?.tapsCollected = 0
            }
            tapTimeout = giveUp
            DispatchQueue.main.asyncAfter(deadline: .now() + tapGiveUp, execute: giveUp)
        }
    }

    func setBPM(_ value: Double) {
        let clamped = min(300, max(10, (value * 10).rounded() / 10))
        if clamped == settings.bpm {
            beatEpoch = Date().timeIntervalSince1970
            restartClock(reset: true)
        } else {
            settings.bpm = clamped      // the settings observer restarts the beat and the clock
        }
    }

    /// 24 MIDI clock pulses per beat, so Lightkey ("Sync beat to: Walrus Keyboard MIDI") follows this tempo.
    /// reset = also send MIDI Stop then Start, which makes a tempo follower drop its averaged tempo and jump.
    private func restartClock(reset: Bool = false) {
        clockTimer?.cancel()
        clockTimer = nil
        guard settings.sendClock else { return }
        let interval = 60.0 / (max(10, settings.bpm) * 24.0)
        if reset {
            midi.sendRaw([0xFC])
            midi.sendRaw([0xFA])
        }
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: clockQueue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .microseconds(100))
        timer.setEventHandler { [weak self] in self?.midi.sendRaw([0xF8]) }
        timer.resume()
        clockTimer = timer
    }

    // MARK: feedback from Lightkey

    private func feedback(note: Int, on: Bool) {
        guard let entry = settings.keys.first(where: { $0.value.note == note && $0.value.type == .toggle }) else { return }
        if on { active.insert(entry.key) } else { active.remove(entry.key) }
    }

    // MARK: used by the window

    func update(_ ids: Set<String>, _ change: (inout KeyConfig) -> Void) {
        var s = settings
        for id in ids {
            var c = s.config(id)
            change(&c)
            s.keys[id] = c
        }
        settings = s
    }

    func sendTestNote(_ id: String) {
        guard let note = settings.config(id).note else { return }
        midi.send(note: note, on: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.midi.send(note: note, on: false) }
    }

    func requestPermissions() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        _ = CGRequestListenEventAccess()
    }

    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    func applyBeatSetup() {
        var s = settings
        var b = s.config("backspace"); b.type = .beat; b.colour = .white; s.keys["backspace"] = b
        var e = s.config("enter"); e.type = .tap; e.colour = .tapReady; s.keys["enter"] = e
        settings = s
    }

    func applyLightkeyPalette() {
        var s = settings
        for (i, d) in "123456789".enumerated() {
            var c = s.config(String(d))
            c.type = .toggle
            c.colour = Settings.palette[i].rgb
            s.keys[String(d)] = c
        }
        settings = s
    }
}
