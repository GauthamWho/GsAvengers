// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)
// G's Avengers — the Windows-keyboard-on-a-Mac translation table.
// One pure function: Windows key + held Windows modifiers + front app -> what the Mac should get.
// No CGEvents here (Injector.swift posts them), so every rule is unit-tested in mac/Tests.
import Foundation

/// The Mac modifiers a held Windows modifier stands for until it is released (Alt+Tab keeps ⌘ down).
struct Latch: Equatable { var host: HostMod; var mac: MacMod }

struct KeyChord: Equatable {
    var mods: Set<MacMod>
    var key: UInt16
}

enum MacAction: String, Equatable { case openFinder }

enum KeyResult: Equatable {
    case chord(KeyChord, latch: Latch?)
    case action(MacAction)
    case drop
}

/// What the Mac is doing right now, as far as the rules care.
struct KeyContext: Equatable {
    var app: String? = nil          // bundle id of the front app
    var editingText = false         // a text field has focus (only looked up when Finder is in front)

    static let finder = "com.apple.finder"
    static let terminals: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
                                         "net.kovidgoyal.kitty", "org.alacritty", "io.alacritty", "co.zeit.hyper", "com.github.wez.wezterm"]
    var isTerminal: Bool { app.map { KeyContext.terminals.contains($0) } ?? false }
    var finderBrowsing: Bool { app == KeyContext.finder && !editingText }
}

/// Which switches are on. Unset ids use the switch's default.
struct KeyOptions {
    var overrides: [String: Bool] = [:]
    func on(_ id: String) -> Bool { overrides[id] ?? (KeyRules.toggle(id)?.defaultOn ?? false) }
}

/// One line in the settings: a switch the owner can flip.
struct KeyToggle: Identifiable {
    let id: String
    let group: String
    let windows: String     // what you press on the Windows keyboard
    let mac: String         // what the Mac gets, in plain words
    let defaultOn: Bool
}

enum RuleScope {
    case any
    case text           // normal apps: not a terminal, not Finder browsing files
    case notFinder      // anywhere except Finder browsing files
    case finder         // Finder in front and no text field being edited
    case terminal
    func matches(_ c: KeyContext) -> Bool {
        switch self {
        case .any: return true
        case .text: return !c.isTerminal && !c.finderBrowsing
        case .notFinder: return !c.finderBrowsing
        case .finder: return c.finderBrowsing
        case .terminal: return c.isTerminal
        }
    }
}

enum RuleOut {
    case chord(Set<MacMod>, UInt16)
    case hold(Set<MacMod>, UInt16, Latch)   // keeps a modifier down while the Windows one stays held
    case action(MacAction)
}

struct KeyRule {
    let toggle: String
    let mods: Set<HostMod>
    let vk: UInt16
    var shiftFollows = false        // Shift+(this) also matches and adds ⇧ (Shift+Home selects)
    var scope: RuleScope = .any
    let out: RuleOut
}

enum KeyRules {
    // Windows virtual keys
    static let vkBack: UInt16 = 0x08, vkTab: UInt16 = 0x09, vkEnter: UInt16 = 0x0D, vkEsc: UInt16 = 0x1B, vkSpace: UInt16 = 0x20
    static let vkEnd: UInt16 = 0x23, vkHome: UInt16 = 0x24, vkLeft: UInt16 = 0x25, vkUp: UInt16 = 0x26, vkRight: UInt16 = 0x27, vkDown: UInt16 = 0x28
    static let vkPrint: UInt16 = 0x2C, vkDelete: UInt16 = 0x2E, vkF2: UInt16 = 0x71, vkF4: UInt16 = 0x73
    static let vkPeriod: UInt16 = 0xBE, vkSemicolon: UInt16 = 0xBA
    static func vk(_ letter: Character) -> UInt16 { UInt16(letter.asciiValue!) }

    // Mac key codes
    static let mReturn: UInt16 = 0x24, mTab: UInt16 = 0x30, mSpace: UInt16 = 0x31, mDelete: UInt16 = 0x33, mEsc: UInt16 = 0x35
    static let mFwdDelete: UInt16 = 0x75, mLeft: UInt16 = 0x7B, mRight: UInt16 = 0x7C, mDown: UInt16 = 0x7D, mUp: UInt16 = 0x7E
    static let mA: UInt16 = 0x00, mC: UInt16 = 0x08, mV: UInt16 = 0x09, mZ: UInt16 = 0x06, mE: UInt16 = 0x0E, mQ: UInt16 = 0x0C
    static let mW: UInt16 = 0x0D, m4: UInt16 = 0x15, mLeftBracket: UInt16 = 0x21, mF11: UInt16 = 0x67

    static let toggles: [KeyToggle] = [
        KeyToggle(id: "ctrl.cmd", group: "Main keys", windows: "Ctrl", mac: "⌘ Command — Ctrl+C, V, X, Z, A, S, F, N, O, P, T, W, R, L…", defaultOn: true),
        KeyToggle(id: "win.fn", group: "Main keys", windows: "⊞ Windows key", mac: "fn — ⊞+Space dictation, ⊞+V clipboard, ⊞+E emoji", defaultOn: true),
        KeyToggle(id: "ctrl.space", group: "Main keys", windows: "Ctrl+Space", mac: "fn Space — dictation shortcut", defaultOn: true),

        KeyToggle(id: "redo", group: "Typing", windows: "Ctrl+Y", mac: "⌘⇧Z — redo", defaultOn: true),
        KeyToggle(id: "line", group: "Typing", windows: "Home / End (+Shift)", mac: "start / end of the line (select with Shift)", defaultOn: true),
        KeyToggle(id: "doc", group: "Typing", windows: "Ctrl+Home / Ctrl+End", mac: "top / bottom of the document", defaultOn: true),
        KeyToggle(id: "word", group: "Typing", windows: "Ctrl+← / → (+Shift)", mac: "jump (or select) a word at a time", defaultOn: true),
        KeyToggle(id: "delword", group: "Typing", windows: "Ctrl+Backspace / Ctrl+Delete", mac: "delete a whole word", defaultOn: true),
        KeyToggle(id: "tabs", group: "Typing", windows: "Ctrl+Tab (+Shift)", mac: "next / previous browser tab", defaultOn: true),

        KeyToggle(id: "alttab", group: "Windows and apps", windows: "Alt+Tab (hold Alt)", mac: "⌘Tab app switcher, keeps cycling while Alt is held", defaultOn: true),
        KeyToggle(id: "altf4", group: "Windows and apps", windows: "Alt+F4", mac: "⌘Q — close the app", defaultOn: true),
        KeyToggle(id: "ctrlf4", group: "Windows and apps", windows: "Ctrl+F4", mac: "⌘W — close the window or tab", defaultOn: true),
        KeyToggle(id: "taskmgr", group: "Windows and apps", windows: "Ctrl+Shift+Esc", mac: "⌘⌥Esc — Force Quit", defaultOn: true),
        KeyToggle(id: "prtsc", group: "Windows and apps", windows: "Print Screen", mac: "⌘⌃⇧4 — snip an area to the clipboard", defaultOn: true),
        KeyToggle(id: "winl", group: "Windows and apps", windows: "⊞+L", mac: "⌃⌘Q — lock the Mac", defaultOn: true),
        KeyToggle(id: "wind", group: "Windows and apps", windows: "⊞+D", mac: "show the desktop (F11)", defaultOn: true),
        KeyToggle(id: "wintab", group: "Windows and apps", windows: "⊞+Tab", mac: "Mission Control (⌃↑)", defaultOn: true),
        KeyToggle(id: "windot", group: "Windows and apps", windows: "⊞+.", mac: "emoji panel (fn E)", defaultOn: true),
        KeyToggle(id: "wine", group: "Windows and apps", windows: "⊞+E", mac: "open a Finder window (off: ⊞+E is fn E = emoji)", defaultOn: false),

        KeyToggle(id: "finder.f2", group: "Finder", windows: "F2", mac: "rename (Return)", defaultOn: true),
        KeyToggle(id: "finder.del", group: "Finder", windows: "Delete", mac: "⌘⌫ — move to Trash", defaultOn: true),
        KeyToggle(id: "finder.enter", group: "Finder", windows: "Enter", mac: "⌘↓ — open", defaultOn: true),
        KeyToggle(id: "finder.back", group: "Finder", windows: "Backspace", mac: "⌘[ — back a folder", defaultOn: true),

        KeyToggle(id: "term.ctrl", group: "Terminals", windows: "Ctrl in a terminal", mac: "stays ⌃ Control — Ctrl+C stops, Ctrl+R, Ctrl+D…", defaultOn: true),
        KeyToggle(id: "term.copypaste", group: "Terminals", windows: "Ctrl+V, Ctrl+Shift+C / V", mac: "⌘V paste, ⌘C copy (like Windows Terminal)", defaultOn: true),
        KeyToggle(id: "term.line", group: "Terminals", windows: "Home / End, Ctrl+Backspace", mac: "⌃A / ⌃E line ends, ⌃W delete word", defaultOn: true),
    ]
    static func toggle(_ id: String) -> KeyToggle? { toggles.first { $0.id == id } }

    static let rules: [KeyRule] = [
        KeyRule(toggle: "ctrl.space", mods: [.ctrl], vk: vkSpace, out: .chord([.fn], mSpace)),

        KeyRule(toggle: "redo", mods: [.ctrl], vk: vk("Y"), out: .chord([.command, .shift], mZ)),
        KeyRule(toggle: "line", mods: [], vk: vkHome, shiftFollows: true, scope: .text, out: .chord([.command], mLeft)),
        KeyRule(toggle: "line", mods: [], vk: vkEnd, shiftFollows: true, scope: .text, out: .chord([.command], mRight)),
        KeyRule(toggle: "doc", mods: [.ctrl], vk: vkHome, shiftFollows: true, scope: .notFinder, out: .chord([.command], mUp)),
        KeyRule(toggle: "doc", mods: [.ctrl], vk: vkEnd, shiftFollows: true, scope: .notFinder, out: .chord([.command], mDown)),
        KeyRule(toggle: "word", mods: [.ctrl], vk: vkLeft, shiftFollows: true, scope: .notFinder, out: .chord([.option], mLeft)),
        KeyRule(toggle: "word", mods: [.ctrl], vk: vkRight, shiftFollows: true, scope: .notFinder, out: .chord([.option], mRight)),
        KeyRule(toggle: "word", mods: [.ctrl], vk: vkUp, shiftFollows: true, scope: .notFinder, out: .chord([.option], mUp)),
        KeyRule(toggle: "word", mods: [.ctrl], vk: vkDown, shiftFollows: true, scope: .notFinder, out: .chord([.option], mDown)),
        KeyRule(toggle: "delword", mods: [.ctrl], vk: vkBack, scope: .text, out: .chord([.option], mDelete)),
        KeyRule(toggle: "delword", mods: [.ctrl], vk: vkDelete, scope: .text, out: .chord([.option], mFwdDelete)),
        KeyRule(toggle: "tabs", mods: [.ctrl], vk: vkTab, shiftFollows: true, out: .chord([.control], mTab)),

        KeyRule(toggle: "alttab", mods: [.alt], vk: vkTab, shiftFollows: true, out: .hold([.command], mTab, Latch(host: .alt, mac: .command))),
        KeyRule(toggle: "altf4", mods: [.alt], vk: vkF4, out: .chord([.command], mQ)),
        KeyRule(toggle: "ctrlf4", mods: [.ctrl], vk: vkF4, out: .chord([.command], mW)),
        KeyRule(toggle: "taskmgr", mods: [.ctrl, .shift], vk: vkEsc, out: .chord([.command, .option], mEsc)),
        KeyRule(toggle: "prtsc", mods: [], vk: vkPrint, out: .chord([.command, .control, .shift], m4)),
        KeyRule(toggle: "winl", mods: [.win], vk: vk("L"), out: .chord([.control, .command], mQ)),
        KeyRule(toggle: "wind", mods: [.win], vk: vk("D"), out: .chord([], mF11)),
        KeyRule(toggle: "wintab", mods: [.win], vk: vkTab, out: .chord([.control], mUp)),
        KeyRule(toggle: "windot", mods: [.win], vk: vkPeriod, out: .chord([.fn], mE)),
        KeyRule(toggle: "windot", mods: [.win], vk: vkSemicolon, out: .chord([.fn], mE)),
        KeyRule(toggle: "wine", mods: [.win], vk: vk("E"), out: .action(.openFinder)),

        KeyRule(toggle: "finder.f2", mods: [], vk: vkF2, scope: .finder, out: .chord([], mReturn)),
        KeyRule(toggle: "finder.del", mods: [], vk: vkDelete, scope: .finder, out: .chord([.command], mDelete)),
        KeyRule(toggle: "finder.enter", mods: [], vk: vkEnter, scope: .finder, out: .chord([.command], mDown)),
        KeyRule(toggle: "finder.back", mods: [], vk: vkBack, scope: .finder, out: .chord([.command], mLeftBracket)),

        KeyRule(toggle: "term.copypaste", mods: [.ctrl, .shift], vk: vk("C"), scope: .terminal, out: .chord([.command], mC)),
        KeyRule(toggle: "term.copypaste", mods: [.ctrl, .shift], vk: vk("V"), scope: .terminal, out: .chord([.command], mV)),
        KeyRule(toggle: "term.copypaste", mods: [.ctrl], vk: vk("V"), scope: .terminal, out: .chord([.command], mV)),
        KeyRule(toggle: "term.line", mods: [], vk: vkHome, scope: .terminal, out: .chord([.control], mA)),
        KeyRule(toggle: "term.line", mods: [], vk: vkEnd, scope: .terminal, out: .chord([.control], 0x0E)),
        KeyRule(toggle: "term.line", mods: [.ctrl], vk: vkBack, scope: .terminal, out: .chord([.control], mW)),
    ]

    /// The Mac modifiers that stand for the Windows modifiers being held (no key involved).
    static func baseMods(held: Set<HostMod>, latch: Latch?, ctx: KeyContext, opts: KeyOptions) -> Set<MacMod> {
        let ctrlIsCmd = opts.on("ctrl.cmd") && !(ctx.isTerminal && opts.on("term.ctrl"))
        var out = Set<MacMod>()
        for h in held {
            if let l = latch, l.host == h { out.insert(l.mac); continue }
            switch h {
            case .shift: out.insert(.shift)
            case .alt: out.insert(.option)
            case .ctrl: out.insert(ctrlIsCmd ? .command : .control)
            case .win: out.insert(opts.on("win.fn") ? .fn : (opts.on("ctrl.cmd") ? .control : .command))
            }
        }
        return out
    }

    /// A non-modifier key went down on the Windows keyboard. `vk` is already normalised (KeyMap.normalize).
    static func translate(vk: UInt16, held: Set<HostMod>, latch: Latch? = nil, ctx: KeyContext, opts: KeyOptions, custom: [Remap] = []) -> KeyResult {
        // 1. the owner's own key swaps win
        let heldNames = Set(held.map(\.rawValue))
        if let r = custom.first(where: { $0.enabled && $0.fromKey == vk && Set($0.fromMods) == heldNames }) {
            return .chord(KeyChord(mods: Set(r.toMods.compactMap { MacMod(rawValue: $0) }), key: r.toKey), latch: nil)
        }
        // 2. built-in Windows habits
        for r in rules where r.vk == vk && opts.on(r.toggle) && r.scope.matches(ctx) {
            let exact = held == r.mods
            let withShift = r.shiftFollows && !r.mods.contains(.shift) && held == r.mods.union([.shift])
            guard exact || withShift else { continue }
            let extra: Set<MacMod> = withShift ? [.shift] : []
            switch r.out {
            case .chord(let m, let k): return .chord(KeyChord(mods: m.union(extra), key: k), latch: nil)
            case .hold(let m, let k, let l): return .chord(KeyChord(mods: m.union(extra), key: k), latch: l)
            case .action(let a): return .action(a)
            }
        }
        // 3. plain key with the held modifiers mapped one by one
        guard let mac = KeyMap.table[vk] else { return .drop }
        return .chord(KeyChord(mods: baseMods(held: held, latch: latch, ctx: ctx, opts: opts), key: mac), latch: nil)
    }
}
