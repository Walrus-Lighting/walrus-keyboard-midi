import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var engine: BoardEngine
    @State private var selection: Set<String> = []

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                StatusBar()
                KeyboardView(selection: $selection)
                QuickSelect(selection: $selection)
                Spacer(minLength: 0)
            }
            .padding(18)
            Divider()
            Inspector(selection: $selection)
                .frame(width: 330)
        }
        .frame(minWidth: 1120, minHeight: 600)
    }
}

// MARK: status

struct StatusDot: View {
    let label: String
    let ok: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 9, height: 9)
            Text(label).font(.callout)
        }
    }
}

struct StatusBar: View {
    @EnvironmentObject var engine: BoardEngine
    var body: some View {
        HStack(spacing: 18) {
            StatusDot(label: engine.keyboardConnected ? "Keyboard connected" : "Keyboard not found", ok: engine.keyboardConnected)
            StatusDot(label: engine.midiReady ? "MIDI device ready" : "MIDI unavailable", ok: engine.midiReady)
            StatusDot(label: engine.tapRunning ? "Key capture on" : "Key capture off", ok: engine.tapRunning)
            if !engine.tapRunning {
                Button("Grant permissions…") { engine.requestPermissions() }
            }
            Spacer()
            Toggle("Running", isOn: Binding(get: { engine.settings.enabled },
                                            set: { engine.settings.enabled = $0 }))
                .toggleStyle(.switch)
        }
        if !engine.tapRunning {
            HStack {
                Text("Key capture needs Accessibility and Input Monitoring. Switch this app on in both, then quit and reopen it.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Accessibility") { engine.openPrivacy("Privacy_Accessibility") }.controlSize(.small)
                Button("Input Monitoring") { engine.openPrivacy("Privacy_ListenEvent") }.controlSize(.small)
            }
        }
        if !engine.keyboardConnected {
            Text("Plug in the keyboard and close any other app that controls its lights.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: keyboard picture

struct KeyboardView: View {
    @EnvironmentObject var engine: BoardEngine
    @Binding var selection: Set<String>

    var body: some View {
        GeometryReader { geo in
            let unit = max(30, min(60, (geo.size.width - 4) / 18.5))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Board.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(row) { item in
                            if let key = item.key {
                                KeyCap(key: key,
                                       cfg: engine.settings.config(key.id),
                                       selected: selection.contains(key.id),
                                       pressed: engine.pressed.contains(key.id),
                                       active: engine.active.contains(key.id),
                                       tapWaiting: engine.tapsCollected > 0)
                                    .frame(width: unit * item.width, height: unit)
                                    .onTapGesture { tap(key.id) }
                            } else {
                                Color.clear.frame(width: unit * item.width, height: unit)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 6 * 60 + 8)
    }

    private func tap(_ id: String) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            selection = [id]
        }
    }
}

struct KeyCap: View {
    let key: KeyDef
    let cfg: KeyConfig
    let selected: Bool
    let pressed: Bool
    let active: Bool
    let tapWaiting: Bool

    /// The tap key ignores its stored colour: yellow while waiting for taps, blue when the tempo is set.
    private var rgb: RGB { cfg.type == .tap ? (tapWaiting ? .tapWaiting : .tapReady) : cfg.colour }

    private var shown: Color {
        switch cfg.type {
        case .off: return Color(white: 0.2)
        case .flash, .double, .half: return pressed ? .white : cfg.colour.color
        default: return rgb.color
        }
    }
    private var textColour: Color {
        if cfg.type == .off { return Color(white: 0.7) }
        let lum = 0.299 * Double(rgb.r) + 0.587 * Double(rgb.g) + 0.114 * Double(rgb.b)
        return ([.flash, .double, .half].contains(cfg.type) && pressed) || lum > 150 ? .black : .white
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(shown.opacity(cfg.type == .off ? 1 : (pressed || active ? 1 : 0.82)))
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: selected ? 3 : 1)
            if active {
                RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white, lineWidth: 2).padding(3)
            }
            VStack(spacing: 1) {
                Text(key.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(textColour)
                    .lineLimit(1).minimumScaleFactor(0.55)
                if cfg.type == .tap {
                    Text(tapWaiting ? "TAP…" : "TAP").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(textColour.opacity(0.8))
                } else if cfg.type == .double || cfg.type == .half {
                    Text(cfg.type == .double ? "TEMPO ×2" : "TEMPO ÷2").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(textColour.opacity(0.8))
                } else if cfg.type == .beat {
                    Text("♪ BEAT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(textColour.opacity(0.8))
                } else if cfg.type == .toggle || cfg.type == .flash, let n = cfg.note {
                    Text("\(cfg.type == .toggle ? "T" : "F") \(n)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(textColour.opacity(0.8))
                }
            }
        }
        .padding(2)
        .contentShape(Rectangle())
    }
}

struct QuickSelect: View {
    @Binding var selection: Set<String>
    var body: some View {
        HStack(spacing: 8) {
            Text("Select:").font(.callout).foregroundStyle(.secondary)
            Button("All") { selection = Set(Board.all.map(\.id)) }
            Button("None") { selection = [] }
            Button("Number row") { selection = Set("1234567890".map(String.init)) }
            Button("Letters") { selection = Set("abcdefghijklmnopqrstuvwxyz".map(String.init)) }
            Button("F-keys") { selection = Set((1...12).map { "f\($0)" }) }
            Button("Arrows") { selection = ["up", "down", "left", "right"] }
            Spacer()
            Text("Click a key. ⌘-click or ⇧-click to add more.").font(.caption).foregroundStyle(.secondary)
        }
        .controlSize(.small)
    }
}

// MARK: inspector

struct Inspector: View {
    @EnvironmentObject var engine: BoardEngine
    @Binding var selection: Set<String>

    private var selectedKeys: [KeyDef] { Board.all.filter { selection.contains($0.id) } }

    private var commonType: KeyType? {
        let types = Set(selectedKeys.map { engine.settings.config($0.id).type })
        return types.count == 1 ? types.first : nil
    }

    private var typeBinding: Binding<KeyType> {
        Binding(get: { commonType ?? .off }, set: { newType in
            for key in selectedKeys {
                var t = newType
                if key.isModifier && [.toggle, .flash, .tap, .double, .half].contains(t) { t = .steady }   // modifiers can't be pressed as keys
                engine.update([key.id]) { $0.type = t }
            }
        })
    }

    private var colourBinding: Binding<Color> {
        Binding(get: {
            let colours = selectedKeys.map { engine.settings.config($0.id).colour }
            return (colours.first ?? .white).color
        }, set: { setColour(RGB($0)) })
    }

    private func setColour(_ rgb: RGB) {
        engine.update(selection) { cfg in
            cfg.colour = rgb
            if cfg.type == .off { cfg.type = .steady }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(headline).font(.title3.bold())

                if selection.isEmpty {
                    Text("Pick one or more keys on the keyboard to set their type and colour.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(KeyType.allCases) { t in
                                Button { typeBinding.wrappedValue = t } label: {
                                    Text(t.title).frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(commonType == t ? Color.accentColor : Color(white: 0.3))
                            }
                        }
                        Text(commonType?.explanation ?? "The selected keys have different types. Choosing one sets them all.")
                            .font(.caption).foregroundStyle(.secondary)
                        if selectedKeys.contains(where: { $0.isModifier }) {
                            Text("Modifier keys (Shift, Ctrl, Alt, ⌘, Caps) can only be Off, Static or Beat.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Colour").font(.headline)
                        HStack {
                            ColorPicker("Custom", selection: colourBinding, supportsOpacity: false)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(Settings.palette, id: \.name) { p in
                                Button { setColour(p.rgb) } label: {
                                    VStack(spacing: 3) {
                                        Circle().fill(p.rgb.color).frame(width: 24, height: 24)
                                            .overlay(Circle().stroke(Color.white.opacity(0.3)))
                                        Text(p.name).font(.system(size: 9))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedKeys.count == 1, let key = selectedKeys.first, !key.isModifier,
                       [.toggle, .flash].contains(engine.settings.config(key.id).type) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MIDI note").font(.headline)
                            if let n = engine.settings.config(key.id).note {
                                Text("\(Board.noteName(n))  (note \(n)), channel 1").font(.system(.body, design: .monospaced))
                            }
                            Button("Send test note to Lightkey") { engine.sendTestNote(key.id) }
                            Text("In Lightkey: right-click a cue, External Control > Replace Trigger, then press this key (or this button).")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                TempoSection()
                Divider()
                Text("Board settings").font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Flash speed")
                        Spacer()
                        Text(String(format: "%.2f s", engine.settings.flashSeconds)).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { engine.settings.flashSeconds },
                                          set: { engine.settings.flashSeconds = $0 }), in: 0.1...1.0)
                }

                Toggle("Only one toggle flashes at a time", isOn: Binding(get: { engine.settings.exclusiveToggles },
                                                                          set: { engine.settings.exclusiveToggles = $0 }))
                Text("Like Lightkey's colour buttons. Lightkey's feedback still decides in the end.")
                    .font(.caption).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop Lightkey receiving the typed key")
                    Picker("", selection: Binding(get: { engine.settings.swallow }, set: { engine.settings.swallow = $0 })) {
                        ForEach(SwallowMode.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    Text("Toggle and Flash keys are sent as MIDI notes. This keeps the plain letter or number from also being typed.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Fnatic keyboard: type \(engine.settings.keyboardType)")
                        Spacer()
                        Button(engine.detecting ? "Press a key on the Fnatic…" : "Detect") { engine.detecting.toggle() }
                    }
                    Text("The Mac's own keyboard is never touched. Use Detect if keys on the Fnatic do nothing.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                HStack {
                    Button("Lightkey colours on 1–9") { engine.applyLightkeyPalette() }
                    Button("Re-assign all notes") {
                        var s = engine.settings
                        s.reassignAllNotes()
                        engine.settings = s
                    }
                }
                .controlSize(.small)
                Text("Notes are assigned automatically: 1–9 are notes 36–44, every other key follows.")
                    .font(.caption).foregroundStyle(.secondary)

                if !engine.statusLine.isEmpty {
                    Text(engine.statusLine).font(.caption).foregroundStyle(.green)
                }
            }
            .padding(18)
        }
    }

    private var headline: String {
        switch selectedKeys.count {
        case 0: return "No key selected"
        case 1: return "Key: \(selectedKeys[0].label)"
        default: return "\(selectedKeys.count) keys selected"
        }
    }
}


// MARK: tempo

struct TempoSection: View {
    @EnvironmentObject var engine: BoardEngine

    private var bpmBinding: Binding<Double> {
        Binding(get: { engine.settings.bpm }, set: { engine.setBPM($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tempo").font(.headline)
            HStack(spacing: 8) {
                TextField("BPM", value: bpmBinding, format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                Text("BPM").foregroundStyle(.secondary)
                Spacer()
                Button("−") { engine.setBPM(engine.settings.bpm - 1) }
                Button("+") { engine.setBPM(engine.settings.bpm + 1) }
                Button("÷2") { engine.setBPM(engine.settings.bpm / 2) }
                Button("×2") { engine.setBPM(engine.settings.bpm * 2) }
            }
            .controlSize(.small)
            Button { engine.tapTempo() } label: {
                Text(engine.tapsCollected > 0 ? "Tap tempo — \(engine.tapsCollected) of \(engine.tapsNeeded)…" : "Tap tempo — tap \(engine.tapsNeeded) times")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            Toggle("Send MIDI clock to Lightkey", isOn: Binding(get: { engine.settings.sendClock },
                                                                set: { engine.settings.sendClock = $0 }))
            Text("In Lightkey's beat panel choose External, then Walrus Keyboard MIDI. Lightkey follows this tempo, and Beat keys pulse on the same clock.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Tap on Enter, Beat light on Backspace") { engine.applyBeatSetup() }
                .controlSize(.small)
        }
    }
}
