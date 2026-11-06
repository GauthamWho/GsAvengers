// G's Avengers — the Mac's own trackpad/keyboard always wins, and the cursor is never left hidden.
import AppKit
import CoreGraphics

/// Every cursor hide must be matched by a show. We keep the count so `restore()` can always undo them
/// (on leave, take-back and disconnect), and re-attach the mouse to the cursor.
final class CursorGuard {
    private(set) var hidden = 0
    private let doHide: () -> Void, doShow: () -> Void, associate: () -> Void
    init(hide: @escaping () -> Void = { CGDisplayHideCursor(CGMainDisplayID()) },
         show: @escaping () -> Void = { CGDisplayShowCursor(CGMainDisplayID()) },
         associate: @escaping () -> Void = { CGAssociateMouseAndMouseCursorPosition(1) }) {
        doHide = hide; doShow = show; self.associate = associate
    }
    func hide() { hidden += 1; doHide() }
    func show() { guard hidden > 0 else { return }; hidden -= 1; doShow() }
    /// Cursor visible and following the trackpad again, whatever happened before.
    func restore() {
        while hidden > 0 { show() }
        associate()
    }
}

/// Watches for input from the Mac's OWN trackpad, mouse and keyboard. Events we inject carry
/// Injector.marker in kCGEventSourceUserData and are ignored.
final class LocalInputWatcher {
    var onLocal: (() -> Void)?
    private var tap: CFMachPort?

    static func isLocal(type: CGEventType, userData: Int64, autorepeat: Bool) -> Bool {
        if userData == Injector.marker { return false }
        if type == .keyDown && autorepeat { return false }
        return true
    }

    func start() {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged,
                                    .rightMouseDragged, .scrollWheel, .keyDown, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        let me = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask,
                                callback: { _, type, event, info in
            guard let info = info else { return Unmanaged.passUnretained(event) }
            let w = Unmanaged<LocalInputWatcher>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = w.tap { CGEvent.tapEnable(tap: t, enable: true) }
            } else if LocalInputWatcher.isLocal(type: type, userData: event.getIntegerValueField(.eventSourceUserData),
                                                autorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0) {
                w.onLocal?()
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: me)
        guard let tap = tap, let src = CFMachPortCreateRunLoopSource(nil, tap, 0) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Retry after Accessibility is granted (the tap can't be made before that).
    var running: Bool { tap != nil }
}

/// The front app and whether a text field has focus, for the key rules. Cheap: the app comes from a
/// notification; the Accessibility lookup only runs when Finder is in front.
final class FrontApp {
    private let lock = NSLock()
    private var bundle: String? = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    private var obs: NSObjectProtocol?

    init() {
        obs = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil) { [weak self] n in
            let b = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            self?.lock.lock(); self?.bundle = b; self?.lock.unlock()
        }
    }

    func context() -> KeyContext {
        lock.lock(); let b = bundle; lock.unlock()
        var c = KeyContext(app: b)
        if b == KeyContext.finder { c.editingText = FrontApp.textFieldFocused() }
        return c
    }

    static func textFieldFocused() -> Bool {
        let sys = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(sys, 0.05)
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &v) == .success, let el = v else { return false }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(el as! AXUIElement, kAXRoleAttribute as CFString, &role)
        let r = role as? String ?? ""
        return r == "AXTextField" || r == "AXTextArea" || r == "AXComboBox"
    }
}
