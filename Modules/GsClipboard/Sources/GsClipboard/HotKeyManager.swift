// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import Carbon.HIToolbox
import Combine

/// The shortcut that opens the panel. Default Fn+V; changeable in Settings.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var command = false, option = false, control = false, shift = false, function = false

    static let defaultValue = Shortcut(keyCode: UInt16(kVK_ANSI_V), function: true)

    /// "fn V", "⌥V", "⌃⇧Space"
    var display: String {
        var s = ""
        if function { s += "fn " }
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        return s + Self.keyName(keyCode)
    }

    var hasModifier: Bool { command || option || control || shift || function }

    /// Safe to use system-wide: needs ⌘, ⌃, ⌥ or fn (⇧ alone would steal a character from every
    /// app), and never takes the standard edit and app shortcuts.
    var isAllowed: Bool {
        guard command || option || control || function else { return false }
        if function && Self.isFunctionRowKey(keyCode) { return false }
        let reserved: Set<Int> = [kVK_ANSI_V, kVK_ANSI_C, kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_A, kVK_ANSI_Q, kVK_ANSI_W, kVK_Tab, kVK_Space]
        let plainCommand = command && !option && !control && !function
        return !(plainCommand && reserved.contains(Int(keyCode)))
    }

    init(keyCode: UInt16, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false, function: Bool = false) {
        self.keyCode = keyCode; self.command = command; self.option = option; self.control = control; self.shift = shift; self.function = function
    }

    init(event e: NSEvent) {
        let m = e.modifierFlags
        self.init(keyCode: e.keyCode, command: m.contains(.command), option: m.contains(.option),
                  control: m.contains(.control), shift: m.contains(.shift), function: m.contains(.function) && !Self.isFunctionRowKey(e.keyCode))
    }

    func matches(keyCode k: UInt16, flags f: CGEventFlags) -> Bool {
        k == keyCode && f.contains(.maskCommand) == command && f.contains(.maskAlternate) == option
            && f.contains(.maskControl) == control && f.contains(.maskShift) == shift && f.contains(.maskSecondaryFn) == function
    }

    /// Arrow, F-keys and similar carry the fn flag by themselves; it is not a held Fn there.
    static func isFunctionRowKey(_ k: UInt16) -> Bool {
        [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
         kVK_ForwardDelete, kVK_Help, kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9,
         kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20].contains(Int(k))
    }

    static func keyName(_ k: UInt16) -> String {
        let special: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
                                      kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
                                      kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
                                      kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
                                      kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"]
        if let s = special[Int(k)] { return s }
        // Letter/number on the user's own keyboard layout.
        guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var len = 0
        data.withUnsafeBytes { raw in
            _ = UCKeyTranslate(raw.bindMemory(to: UCKeyboardLayout.self).baseAddress, k, UInt16(kUCKeyActionDisplay), 0,
                               UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &len, &chars)
        }
        return String(utf16CodeUnits: chars, count: len).uppercased()
    }

    // MARK: Stored

    /// The clipboard shortcut (fn V by default).
    static var current: Shortcut { stored(.clipboard) }

    static func stored(_ slot: ShortcutSlot) -> Shortcut {
        guard let d = UserDefaults.standard.data(forKey: slot.storageKey),
              let s = try? JSONDecoder().decode(Shortcut.self, from: d), s.isAllowed else { return slot.defaultValue }
        return s
    }

    static func store(_ s: Shortcut, for slot: ShortcutSlot) {
        UserDefaults.standard.set(try? JSONEncoder().encode(s), forKey: slot.storageKey)
    }
}

/// The two shortcuts: one opens the clipboard, one opens straight on Emoji.
enum ShortcutSlot: UInt32, CaseIterable {
    case clipboard = 1, emoji = 2

    var storageKey: String { self == .clipboard ? "shortcut" : "emojiShortcut" }
    /// fn V for the clipboard; fn E (the Mac's own emoji key, 🌐 E) for emoji.
    var defaultValue: Shortcut {
        self == .clipboard ? .defaultValue : Shortcut(keyCode: UInt16(kVK_ANSI_E), function: true)
    }
}

/// Listens for the shortcut system-wide.
/// - Without Fn: Carbon hot key (needs no permission).
/// - With Fn: macOS gives Fn to apps only through an event tap, which needs Accessibility
///   (the same permission as paste). Until it is allowed, the menu bar icon opens the panel.
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    var onPressed: ((ShortcutSlot) -> Void)?
    /// What the UI shows for the clipboard shortcut ("fn V") and the emoji one ("fn E").
    @Published private(set) var display = Shortcut.stored(.clipboard).display
    @Published private(set) var emojiDisplay = Shortcut.stored(.emoji).display
    /// True while an Fn shortcut is waiting for the Accessibility permission.
    @Published private(set) var waitingForPermission = false
    static let changed = Notification.Name("gsShortcutChanged")

    private var hotKeyRefs: [ShortcutSlot: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var retry: Timer?
    private var shortcuts: [ShortcutSlot: Shortcut] = Dictionary(uniqueKeysWithValues: ShortcutSlot.allCases.map { ($0, Shortcut.stored($0)) })
    /// Set while Settings records a new shortcut, so the old one doesn't fire.
    var paused = false

    func display(for slot: ShortcutSlot) -> String { slot == .clipboard ? display : emojiDisplay }
    func shortcut(for slot: ShortcutSlot) -> Shortcut { shortcuts[slot] ?? slot.defaultValue }

    func start() {
        installCarbonHandler()
        reinstall()
    }

    /// Sets one shortcut. Refused (returns false) if the other one already uses the same keys.
    @discardableResult
    func apply(_ s: Shortcut, to slot: ShortcutSlot = .clipboard) -> Bool {
        if ShortcutSlot.allCases.contains(where: { $0 != slot && shortcut(for: $0) == s }) { return false }
        shortcuts[slot] = s
        Shortcut.store(s, for: slot)
        reinstall()
        return true
    }

    private func reinstall() {
        unregisterCarbon()
        removeTap()
        retry?.invalidate(); retry = nil
        waitingForPermission = false
        for slot in ShortcutSlot.allCases where !shortcut(for: slot).function { registerCarbon(shortcut(for: slot), slot: slot) }
        if shortcuts.values.contains(where: \.function), !installTap() {
            waitingForPermission = true
            // Pick it up as soon as Accessibility is switched on.
            retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                guard let self, self.installTap() else { return }
                self.waitingForPermission = false
                Diag.log("fn shortcuts active (Accessibility allowed)")
                t.invalidate()
                NotificationCenter.default.post(name: Self.changed, object: nil)
            }
        }
        display = shortcut(for: .clipboard).display
        emojiDisplay = shortcut(for: .emoji).display
        Diag.log("shortcuts \(display) / emoji \(emojiDisplay) \(waitingForPermission ? "(waiting for Accessibility)" : "active")")
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    // MARK: Carbon

    private func installCarbonHandler() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData else { return noErr }
            let m = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let slot = ShortcutSlot(rawValue: id.id) ?? .clipboard
            DispatchQueue.main.async { if !m.paused { m.onPressed?(slot) } }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    private func registerCarbon(_ s: Shortcut, slot: ShortcutSlot) {
        var mods: UInt32 = 0
        if s.command { mods |= UInt32(cmdKey) }
        if s.option { mods |= UInt32(optionKey) }
        if s.control { mods |= UInt32(controlKey) }
        if s.shift { mods |= UInt32(shiftKey) }
        let id = EventHotKeyID(signature: OSType(0x434C4950), id: slot.rawValue) // 'CLIP'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(s.keyCode), mods, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { Diag.log("hotkey \(s.display) failed (status \(status)); another app may own it") }
        hotKeyRefs[slot] = ref
    }

    private func unregisterCarbon() {
        for ref in hotKeyRefs.values { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
    }

    // MARK: Event tap (Fn shortcuts)

    private func installTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let m = Unmanaged<HotKeyManager>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout {
                if let tap = m.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            guard !m.paused, let slot = ShortcutSlot.allCases.first(where: { m.shortcut(for: $0).function && m.shortcut(for: $0).matches(keyCode: code, flags: event.flags) })
            else { return Unmanaged.passUnretained(event) }
            // Holding the shortcut: swallow the repeats too, but open only once.
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { DispatchQueue.main.async { m.onPressed?(slot) } }
            return nil // swallow it, so the key doesn't also type into the app
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        tapSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil; tapSource = nil
    }

    deinit {
        unregisterCarbon()
        removeTap()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
