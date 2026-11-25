import Foundation
import SwiftUI
import AppKit

struct RGB: Codable, Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let off = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 255, g: 255, b: 255)
    static let tapWaiting = RGB(r: 255, g: 190, b: 0)   // yellow
    static let tapReady = RGB(r: 0, g: 0, b: 255)       // blue

    var color: Color { Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }

    init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }

    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        r = UInt8(max(0, min(255, (c.redComponent * 255).rounded())))
        g = UInt8(max(0, min(255, (c.greenComponent * 255).rounded())))
        b = UInt8(max(0, min(255, (c.blueComponent * 255).rounded())))
    }
}

/// What a key does.
enum KeyType: String, Codable, CaseIterable, Identifiable {
    case off, steady, toggle, flash, tap, beat, double, half
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .steady: return "Static"
        case .toggle: return "Toggle"
        case .flash: return "Flash"
        case .tap: return "Tap"
        case .beat: return "Beat"
        case .double: return "×2"
        case .half: return "÷2"
        }
    }
    var explanation: String {
        switch self {
        case .off: return "Key is dark and does nothing."
        case .steady: return "Key is always lit in its colour. Sends nothing to Lightkey."
        case .toggle: return "Press: the key flashes in its colour and a note goes to Lightkey. Press again: it stops."
        case .flash: return "Key shows its colour and turns white while held. Note on when pressed, note off when released."
        case .tap: return "Tap tempo. Tap 4 times in rhythm and the BPM is set to the average. The key is yellow while it waits for taps and blue when the tempo is set. Its colour is fixed."
        case .beat: return "Pulses in its colour on every beat of the tempo. Lighting only, sends nothing."
        case .double: return "Doubles the tempo each time it is pressed (up to 300). Shows its colour and turns white while held."
        case .half: return "Halves the tempo each time it is pressed. Shows its colour and turns white while held."
        }
    }
}

enum SwallowMode: String, Codable, CaseIterable, Identifiable {
    case lightkey, always, never
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lightkey: return "Only while Lightkey is in front"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

struct KeyConfig: Codable, Equatable {
    var type: KeyType = .off
    var colour: RGB = .white
    var note: Int? = nil
}

struct Settings: Codable, Equatable {
    var keys: [String: KeyConfig] = [:]
    var flashSeconds: Double = 0.25
    var exclusiveToggles = true
    var swallow: SwallowMode = .lightkey
    var keyboardType: Int = 40          // macOS tags each key press with the keyboard it came from
    var enabled = true
    var bpm: Double = 120
    var sendClock = true                // act as Lightkey's tempo source via MIDI clock
    var beatSetupDone = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case keys, flashSeconds, exclusiveToggles, swallow, keyboardType, enabled, bpm, sendClock, beatSetupDone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keys = try c.decodeIfPresent([String: KeyConfig].self, forKey: .keys) ?? [:]
        flashSeconds = try c.decodeIfPresent(Double.self, forKey: .flashSeconds) ?? 0.25
        exclusiveToggles = try c.decodeIfPresent(Bool.self, forKey: .exclusiveToggles) ?? true
        swallow = try c.decodeIfPresent(SwallowMode.self, forKey: .swallow) ?? .lightkey
        keyboardType = try c.decodeIfPresent(Int.self, forKey: .keyboardType) ?? 40
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        bpm = try c.decodeIfPresent(Double.self, forKey: .bpm) ?? 120
        sendClock = try c.decodeIfPresent(Bool.self, forKey: .sendClock) ?? true
        beatSetupDone = try c.decodeIfPresent(Bool.self, forKey: .beatSetupDone) ?? false
    }

    /// The nine Lightkey colour buttons.
    static let palette: [(name: String, rgb: RGB)] = [
        ("White", RGB(r: 255, g: 255, b: 255)), ("Red", RGB(r: 255, g: 0, b: 0)),
        ("Orange", RGB(r: 255, g: 70, b: 0)), ("Yellow", RGB(r: 255, g: 190, b: 0)),
        ("Green", RGB(r: 0, g: 255, b: 0)), ("Cyan", RGB(r: 0, g: 255, b: 255)),
        ("Blue", RGB(r: 0, g: 0, b: 255)), ("Violet", RGB(r: 130, g: 0, b: 255)),
        ("Magenta", RGB(r: 255, g: 0, b: 200)),
    ]

    static func makeDefault() -> Settings {
        var s = Settings()
        for (i, d) in "123456789".enumerated() {
            s.keys[String(d)] = KeyConfig(type: .toggle, colour: palette[i].rgb, note: nil)
        }
        s.fillMissingNotes()
        return s
    }

    mutating func reassignAllNotes() {
        let notes = Board.autoAssignNotes()
        for key in Board.all where !key.isModifier {
            var c = keys[key.id] ?? KeyConfig()
            c.note = notes[key.id]
            keys[key.id] = c
        }
    }

    /// Tap tempo on Enter and a beat light on Backspace, unless those keys are already in use.
    mutating func applyBeatDefaults() {
        var b = config("backspace")
        if b.type == .off { b.type = .beat; b.colour = .white; keys["backspace"] = b }
        var e = config("enter")
        if e.type == .off { e.type = .tap; e.colour = .tapReady; keys["enter"] = e }
        beatSetupDone = true
    }

    mutating func fillMissingNotes() {
        let notes = Board.autoAssignNotes()
        for key in Board.all where !key.isModifier {
            var c = keys[key.id] ?? KeyConfig()
            if c.note == nil { c.note = notes[key.id] }
            keys[key.id] = c
        }
    }

    func config(_ id: String) -> KeyConfig { keys[id] ?? KeyConfig() }

    // MARK: saving

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WalrusKeyboardMIDI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    static func load() -> Settings {
        if let data = try? Data(contentsOf: fileURL), var s = try? JSONDecoder().decode(Settings.self, from: data) {
            s.fillMissingNotes()
            if !s.beatSetupDone { s.applyBeatDefaults() }
            return s
        }
        var s = makeDefault()
        s.applyBeatDefaults()
        return s
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) { try? data.write(to: Settings.fileURL, options: .atomic) }
    }
}
