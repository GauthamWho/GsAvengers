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

/// Watches for input from the Mac's OWN trackpad, mouse and keyboard while Windows has control, so
/// the Mac can take it back at once. Events we inject carry Injector.marker in kCGEventSourceUserData
/// and are ignored.
///
/// The tap exists ONLY between `start()` (Windows entered this Mac) and `stop()` (it left, or the Mac
/// took back): ordinary Mac use never passes through it. It is listen-only, appended at the tail,
/// and served on the pointer-input thread, never the main thread; the callback only compares one
/// integer and hands off.
final class LocalInputWatcher {
    var onLocal: (() -> Void)?
    private let lock = NSLock()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    static func isLocal(type: CGEventType, userData: Int64, autorepeat: Bool) -> Bool {
        if userData == Injector.marker { return false }
        if type == .keyDown && autorepeat { return false }
        return true
    }

    static let eventMask: CGEventMask = {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged,
                                    .rightMouseDragged, .scrollWheel, .keyDown, .flagsChanged]
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }()

    func start() {
        lock.lock(); defer { lock.unlock() }
        guard tap == nil, AXIsProcessTrusted() else { return }
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                              eventsOfInterest: Self.eventMask, callback: { _, type, event, info in
            guard let info = info else { return Unmanaged.passUnretained(event) }
            let w = Unmanaged<LocalInputWatcher>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                w.reenable()
            } else if LocalInputWatcher.isLocal(type: type, userData: event.getIntegerValueField(.eventSourceUserData),
                                                autorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0) {
                w.onLocal?()
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: me), let src = CFMachPortCreateRunLoopSource(nil, created, 0) else { return }
        tap = created; source = src
        PointerTapRunLoop.add(src)
        CGEvent.tapEnable(tap: created, enable: true)
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        guard let t = tap else { return }
        CGEvent.tapEnable(tap: t, enable: false)
        if let source { PointerTapRunLoop.remove(source, invalidating: t) }
        tap = nil; source = nil
    }

    private func reenable() {
        lock.lock(); let t = tap; lock.unlock()
        if let t { CGEvent.tapEnable(tap: t, enable: true) }
    }

    /// True while Windows has control and the tap is installed.
    var running: Bool { lock.lock(); defer { lock.unlock() }; return tap != nil }
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
