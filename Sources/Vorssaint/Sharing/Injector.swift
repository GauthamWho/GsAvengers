// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)
// G's Avengers — turns events from the Windows keyboard/mouse into real Mac input
import AppKit
import CoreGraphics

final class Injector {
    var config: () -> Config
    private let src = CGEventSource(stateID: .hidSystemState)
    // keyboard state
    private var hostMods: [UInt16: HostMod] = [:]   // Windows modifier keys held (normalised VK -> which)
    private var macMods = Set<MacMod>()             // Mac modifiers we have pressed
    private var pressed: [UInt16: UInt16] = [:]     // Windows key held -> Mac key we pressed for it
    private var swallowed = Set<UInt16>()           // Windows keys whose press did an action / nothing
    private var latch: Latch?                       // Alt+Tab: Alt keeps ⌘ down until released
    var context: () -> KeyContext = { KeyContext() }
    var perform: (MacAction) -> Void = { _ in }
    var log: ((String) -> Void)?

    // mouse state
    private var buttonsDown = Set<Int>()
    private var lastClick: (button: Int, time: TimeInterval, pos: CGPoint, count: Int64)?
    private var scrollAcc = CGPoint.zero

    /// Every event we post carries this in kCGEventSourceUserData, so the local-input watcher can tell
    /// our events from the Mac's own trackpad and keyboard.
    static let marker: Int64 = 0x4753_4156 // "GSAV"

    init(config: @escaping () -> Config) { self.config = config }

    private func post(_ e: CGEvent) {
        e.setIntegerValueField(.eventSourceUserData, value: Injector.marker)
        e.post(tap: .cghidEventTap)
    }

    // MARK: flags

    private func flags() -> CGEventFlags {
        var f = CGEventFlags(rawValue: 0x100) // NX_NONCOALSESCEDMASK, as hardware events carry
        for m in macMods {
            switch m {
            case .shift: f.insert(.maskShift); f.insert(CGEventFlags(rawValue: 0x2))
            case .control: f.insert(.maskControl); f.insert(CGEventFlags(rawValue: 0x1))
            case .option: f.insert(.maskAlternate); f.insert(CGEventFlags(rawValue: 0x20))
            case .command: f.insert(.maskCommand); f.insert(CGEventFlags(rawValue: 0x8))
            case .fn: f.insert(.maskSecondaryFn)
            }
        }
        return f
    }

    // MARK: keyboard

    private func postModifier(_ m: MacMod, down: Bool) {
        if down { macMods.insert(m) } else { macMods.remove(m) }
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: KeyMap.macModKey(m), keyDown: down) else { return }
        e.type = .flagsChanged
        e.flags = flags()
        post(e)
    }

    /// Press / release Mac modifiers until exactly `target` is down.
    private func syncMods(_ target: Set<MacMod>) {
        for m in macMods.subtracting(target) { postModifier(m, down: false) }
        for m in MacMod.allCases where target.contains(m) && !macMods.contains(m) { postModifier(m, down: true) }
    }

    private func postKey(_ key: UInt16, down: Bool, repeat isRepeat: Bool = false) {
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down) else { return }
        var f = flags()
        let hw = KeyMap.hardwareFlags(key)
        if hw.fn { f.insert(.maskSecondaryFn) }
        if hw.pad { f.insert(.maskNumericPad) }
        e.flags = f
        if isRepeat { e.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        post(e)
        if !isRepeat { log?("key \(down ? "down" : "up  ") mac=0x\(String(key, radix: 16)) mods=\(macMods.map(\.rawValue).sorted())") }
    }

    private var options: KeyOptions { KeyOptions(overrides: config().keyRules) }
    private func base(_ ctx: KeyContext) -> Set<MacMod> {
        KeyRules.baseMods(held: Set(hostMods.values), latch: latch, ctx: ctx, opts: options)
    }

    func key(vk rawVK: UInt16, extended: Bool, down: Bool) {
        let vk = KeyMap.normalize(vk: rawVK, extended: extended)

        // Windows modifier keys: the Mac gets the matching modifier straight away (Ctrl+click = ⌘click)
        if let m = KeyMap.hostMod(vk) {
            if down { hostMods[vk] = m } else {
                hostMods[vk] = nil
                if let l = latch, l.host == m, !hostMods.values.contains(m) { latch = nil } // Alt let go: switch app
            }
            if pressed.isEmpty { syncMods(base(context())) }
            return
        }

        if vk == 0x14 { // Caps Lock toggles on press only
            if down { for d in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: KeyMap.kCaps, keyDown: d) else { continue }
                e.type = .flagsChanged; e.flags = flags(); post(e)
            } }
            return
        }

        if !down {
            if let mac = pressed.removeValue(forKey: vk) {
                postKey(mac, down: false)
                if pressed.isEmpty { syncMods(base(context())) }
            } else { swallowed.remove(vk) }
            return
        }
        if let mac = pressed[vk] { postKey(mac, down: true, repeat: true); return } // held: auto-repeat
        if swallowed.contains(vk) { return }

        let ctx = context()
        let cfg = config()
        let r = KeyRules.translate(vk: vk, held: Set(hostMods.values), latch: latch, ctx: ctx,
                                   opts: KeyOptions(overrides: cfg.keyRules), custom: cfg.remaps)
        switch r {
        case .chord(let c, let l):
            if let l = l { latch = l }
            syncMods(c.mods)
            postKey(c.key, down: true)
            pressed[vk] = c.key
        case .action(let a):
            swallowed.insert(vk)
            log?("action \(a.rawValue)")
            perform(a)
        case .drop:
            swallowed.insert(vk)
        }
    }

    func releaseAll() {
        for (_, k) in pressed { postKey(k, down: false) }
        pressed.removeAll(); swallowed.removeAll(); hostMods.removeAll(); latch = nil
        syncMods([])
        for b in buttonsDown { button(b, down: false) }
    }

    // MARK: mouse

    static func cursor() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }

    static func displays() -> [CGRect] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16); var n: UInt32 = 0
        CGGetActiveDisplayList(16, &ids, &n)
        return (0..<Int(n)).map { CGDisplayBounds(ids[$0]) }
    }

    func warp(to p: CGPoint) {
        CGWarpMouseCursorPosition(p)
        CGAssociateMouseAndMouseCursorPosition(1)
        move(to: p, dx: 0, dy: 0)
    }

    func move(to p: CGPoint, dx: Int, dy: Int) {
        let type: CGEventType
        var btn: CGMouseButton = .left
        if buttonsDown.contains(0) { type = .leftMouseDragged }
        else if buttonsDown.contains(1) { type = .rightMouseDragged; btn = .right }
        else if let b = buttonsDown.first { type = .otherMouseDragged; btn = CGMouseButton(rawValue: UInt32(b))! }
        else { type = .mouseMoved }
        guard let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: p, mouseButton: btn) else { return }
        e.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        e.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        e.flags = flags()
        post(e)
    }

    /// 0 left, 1 right, 2 middle, 3 back, 4 forward
    func button(_ b: Int, down: Bool) {
        let p = Injector.cursor()
        if down { buttonsDown.insert(b) } else { buttonsDown.remove(b) }
        let type: CGEventType
        let cgButton: CGMouseButton
        switch b {
        case 0: type = down ? .leftMouseDown : .leftMouseUp; cgButton = .left
        case 1: type = down ? .rightMouseDown : .rightMouseUp; cgButton = .right
        default: type = down ? .otherMouseDown : .otherMouseUp; cgButton = CGMouseButton(rawValue: UInt32(b == 2 ? 2 : b))!
        }
        var count: Int64 = 1
        let now = ProcessInfo.processInfo.systemUptime
        if down {
            if let l = lastClick, l.button == b, now - l.time < NSEvent.doubleClickInterval, abs(l.pos.x - p.x) < 5, abs(l.pos.y - p.y) < 5 {
                count = l.count + 1
            }
            lastClick = (b, now, p, count)
        } else if let l = lastClick, l.button == b { count = l.count }
        guard let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: p, mouseButton: cgButton) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: count)
        if b >= 2 { e.setIntegerValueField(.mouseEventButtonNumber, value: Int64(b)) }
        e.flags = flags()
        post(e)
    }

    /// dx/dy in Windows wheel units (120 per notch); dy > 0 = wheel away from you
    func wheel(dx: Int, dy: Int) {
        let cfg = config()
        let k = 0.5 * cfg.scrollSpeed * (cfg.reverseScroll ? -1 : 1) // 120 -> 60 px per notch
        scrollAcc.x += CGFloat(Double(-dx) * k)
        scrollAcc.y += CGFloat(Double(dy) * k)
        let px = Int32(scrollAcc.x.rounded(.towardZero)), py = Int32(scrollAcc.y.rounded(.towardZero))
        scrollAcc.x -= CGFloat(px); scrollAcc.y -= CGFloat(py)
        if px == 0 && py == 0 { return }
        guard let e = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 2, wheel1: py, wheel2: px, wheel3: 0) else { return }
        e.flags = flags()
        post(e)
    }
}
