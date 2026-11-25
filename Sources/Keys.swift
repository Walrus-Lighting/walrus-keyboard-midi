import Foundation

/// One physical key: its LED number on the miniSTREAK, its macOS keycode, and where it sits in the picture.
struct KeyDef: Identifiable {
    let id: String          // internal name, e.g. "1", "esc", "caps_lock"
    let label: String       // what is drawn on the key
    let led: Int            // LED index on the keyboard
    let code: Int           // macOS virtual keycode
    let width: Double       // width in key units
    let isModifier: Bool    // modifiers can only be coloured, never sent as notes
}

struct LayoutItem: Identifiable {
    let id = UUID()
    let key: KeyDef?        // nil = blank space
    let width: Double
}

enum Board {
    private static func k(_ id: String, _ label: String, led: Int, code: Int, w: Double = 1, mod: Bool = false) -> KeyDef {
        KeyDef(id: id, label: label, led: led, code: code, width: w, isModifier: mod)
    }
    private static func gap(_ w: Double) -> LayoutItem { LayoutItem(key: nil, width: w) }
    private static func item(_ key: KeyDef) -> LayoutItem { LayoutItem(key: key, width: key.width) }

    static let all: [KeyDef] = [
        k("esc", "Esc", led: 1, code: 53),
        k("f1", "F1", led: 7, code: 122), k("f2", "F2", led: 13, code: 120), k("f3", "F3", led: 19, code: 99),
        k("f4", "F4", led: 25, code: 118), k("f5", "F5", led: 31, code: 96), k("f6", "F6", led: 37, code: 97),
        k("f7", "F7", led: 43, code: 98), k("f8", "F8", led: 49, code: 100), k("f9", "F9", led: 55, code: 101),
        k("f10", "F10", led: 67, code: 109), k("f11", "F11", led: 73, code: 103), k("f12", "F12", led: 79, code: 111),
        k("print_screen", "PrtSc", led: 90, code: 105), k("scroll_lock", "ScrLk", led: 93, code: 107), k("pause", "Pause", led: 98, code: 113),

        k("`", "`", led: 2, code: 50),
        k("1", "1", led: 8, code: 18), k("2", "2", led: 14, code: 19), k("3", "3", led: 20, code: 20),
        k("4", "4", led: 26, code: 21), k("5", "5", led: 32, code: 23), k("6", "6", led: 38, code: 22),
        k("7", "7", led: 44, code: 26), k("8", "8", led: 50, code: 28), k("9", "9", led: 56, code: 25),
        k("0", "0", led: 61, code: 29), k("-", "-", led: 62, code: 27), k("=", "=", led: 68, code: 24),
        k("backspace", "Bksp", led: 80, code: 51, w: 2),
        k("insert", "Ins", led: 89, code: 114), k("home", "Home", led: 94, code: 115), k("page_up", "PgUp", led: 99, code: 116),

        k("tab", "Tab", led: 3, code: 48, w: 1.5),
        k("q", "Q", led: 9, code: 12), k("w", "W", led: 15, code: 13), k("e", "E", led: 21, code: 14),
        k("r", "R", led: 27, code: 15), k("t", "T", led: 33, code: 17), k("y", "Y", led: 39, code: 16),
        k("u", "U", led: 45, code: 32), k("i", "I", led: 51, code: 34), k("o", "O", led: 57, code: 31),
        k("p", "P", led: 63, code: 35), k("[", "[", led: 69, code: 33), k("]", "]", led: 75, code: 30),
        k("\\", "\\", led: 81, code: 42, w: 1.5),
        k("delete", "Del", led: 88, code: 117), k("end", "End", led: 95, code: 119), k("page_down", "PgDn", led: 96, code: 121),

        k("caps_lock", "Caps", led: 4, code: 57, w: 1.75, mod: true),
        k("a", "A", led: 10, code: 0), k("s", "S", led: 16, code: 1), k("d", "D", led: 22, code: 2),
        k("f", "F", led: 28, code: 3), k("g", "G", led: 34, code: 5), k("h", "H", led: 40, code: 4),
        k("j", "J", led: 46, code: 38), k("k", "K", led: 52, code: 40), k("l", "L", led: 58, code: 37),
        k(";", ";", led: 64, code: 41), k("'", "'", led: 70, code: 39),
        k("enter", "Enter", led: 82, code: 36, w: 2.25),

        k("shift", "Shift", led: 5, code: 56, w: 2.25, mod: true),
        k("z", "Z", led: 17, code: 6), k("x", "X", led: 23, code: 7), k("c", "C", led: 29, code: 8),
        k("v", "V", led: 35, code: 9), k("b", "B", led: 41, code: 11), k("n", "N", led: 47, code: 45),
        k("m", "M", led: 53, code: 46), k(",", ",", led: 59, code: 43), k(".", ".", led: 65, code: 47),
        k("/", "/", led: 66, code: 44),
        k("shift_r", "Shift", led: 77, code: 60, w: 2.75, mod: true),
        k("up", "↑", led: 87, code: 126),

        k("ctrl_l", "Ctrl", led: 6, code: 59, w: 1.25, mod: true),
        k("cmd", "⌘", led: 12, code: 55, w: 1.25, mod: true),
        k("alt_l", "Alt", led: 18, code: 58, w: 1.25, mod: true),
        k("space", "Space", led: 36, code: 49, w: 6.25),
        k("alt_r", "Alt", led: 60, code: 61, w: 1.25, mod: true),
        k("menu", "Menu", led: 78, code: 110, w: 1.25),
        k("ctrl_r", "Ctrl", led: 83, code: 62, w: 1.25, mod: true),
        k("left", "←", led: 84, code: 123), k("down", "↓", led: 85, code: 125), k("right", "→", led: 86, code: 124),
    ]

    static let byID: [String: KeyDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let byCode: [Int: KeyDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })

    /// The picture of the keyboard, row by row (a tenkeyless layout, 18.5 units wide).
    static let rows: [[LayoutItem]] = {
        func keys(_ ids: [String]) -> [LayoutItem] { ids.map { item(byID[$0]!) } }
        return [
            keys(["esc"]) + [gap(1)] + keys(["f1", "f2", "f3", "f4"]) + [gap(0.5)] + keys(["f5", "f6", "f7", "f8"])
                + [gap(0.5)] + keys(["f9", "f10", "f11", "f12"]) + [gap(0.5)] + keys(["print_screen", "scroll_lock", "pause"]),
            keys(["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "backspace"]) + [gap(0.5)] + keys(["insert", "home", "page_up"]),
            keys(["tab", "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", "\\"]) + [gap(0.5)] + keys(["delete", "end", "page_down"]),
            keys(["caps_lock", "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'", "enter"]),
            keys(["shift", "z", "x", "c", "v", "b", "n", "m", ",", ".", "/", "shift_r"]) + [gap(1.5)] + keys(["up"]),
            keys(["ctrl_l", "cmd", "alt_l", "space", "alt_r", "menu", "ctrl_r"]) + [gap(0.5)] + keys(["left", "down", "right"]),
        ]
    }()

    static let ledCount = 106

    /// Notes are handed out automatically: the digits 1-9 get notes 36-44 (so existing Lightkey mappings keep
    /// working), then every other key takes the next free note, 45 upward, then 0-35.
    static func autoAssignNotes() -> [String: Int] {
        var notes: [String: Int] = [:]
        var used = Set<Int>()
        for (i, d) in "123456789".enumerated() { notes[String(d)] = 36 + i; used.insert(36 + i) }
        var pool = Array(45...127) + Array(0...35)
        for key in all where !key.isModifier && notes[key.id] == nil {
            while let n = pool.first, used.contains(n) { pool.removeFirst() }
            guard let n = pool.first else { break }
            pool.removeFirst()
            notes[key.id] = n
            used.insert(n)
        }
        return notes
    }

    static func noteName(_ n: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return "\(names[n % 12])\(n / 12 - 2)"   // matches Lightkey: note 36 shows as C1
    }
}
