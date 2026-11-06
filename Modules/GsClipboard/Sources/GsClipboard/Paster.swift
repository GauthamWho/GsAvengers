// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import AppKit
import ApplicationServices

/// Types the pick into the app you were using, like every Mac clipboard manager:
/// put it on the clipboard, hand focus back, then press ⌘V for you.
///
/// Pressing keys in another app needs the Accessibility permission. The app never turns
/// it on itself; it only opens the right Settings page so you can.
@MainActor
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// User setting, on by default.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "pasteAfterPick") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pasteAfterPick") }
    }

    /// Whether a pick will really be pasted (setting on and permission given).
    static var willPaste: Bool { enabled && isTrusted }

    static func openAccessibilitySettings() {
        // Registers the app in the Accessibility list (switched off) so it is there to tick.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// The text field you were typing in, read when the panel opens (before it takes focus),
    /// so it can be focused again before pasting.
    static func focusedElement() -> AXUIElement? {
        guard isTrusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.15)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let f = focused, CFGetTypeID(f) == AXUIElementGetTypeID() else { return nil }
        return (f as! AXUIElement)
    }

    /// Brings `app` back to the front and puts focus back in `element`, then runs `done(true)`.
    /// Asks macOS again every 0.25 s in case the first hand-back was refused or another app jumped
    /// in front. Gives up after ~1.5 s with `done(false)`, so a key is never pressed in some other app.
    static func whenFront(_ app: NSRunningApplication?, element: AXUIElement?, _ done: @escaping (Bool) -> Void) {
        var tries = 0
        func attempt() {
            let front = NSWorkspace.shared.frontmostApplication
            let ready = app == nil || front?.processIdentifier == app?.processIdentifier
            if ready {
                refocus(element, in: app)
                // A short beat so the window has really made the text field active again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { done(true) }
                return
            }
            if tries >= 30 {
                Diag.log("paste skipped: \(app?.localizedName ?? "?") did not come back (front is \(front?.localizedName ?? "?"))")
                done(false); return
            }
            if tries % 5 == 4, let app, !app.isTerminated { app.activate(options: []) }
            tries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { attempt() }
        }
        attempt()
    }

    /// If focus moved off the field you were typing in (clicking the panel can do that in some
    /// apps), focus that field again.
    private static func refocus(_ element: AXUIElement?, in app: NSRunningApplication?) {
        guard let element, let app else { return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid == app.processIdentifier else { return }
        if let now = focusedElement(), CFEqual(now, element) { return }
        let r = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        Diag.log("refocused field in \(app.localizedName ?? "?"): \(r == .success ? "ok" : "error \(r.rawValue)")")
    }

    /// Sends ⌘V once `app` (and your field) are back in front. Returns whether it was sent.
    static func paste(into app: NSRunningApplication?, element: AXUIElement? = nil, then: ((Bool) -> Void)? = nil) {
        guard isTrusted else { Diag.log("paste skipped: Accessibility not allowed"); then?(false); return }
        whenFront(app, element: element) { ok in
            if ok {
                sendCommandV()
                Diag.log("pasted into \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
            }
            then?(ok)
        }
    }

    private static func sendCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}

/// A full copy of what is on the clipboard (every item, every format), so it can be put back
/// after a pick is pasted.
struct PasteboardSnapshot {
    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    @MainActor init(_ pb: NSPasteboard = .general) {
        items = (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }
    }

    @MainActor func restore(to pb: NSPasteboard = .general) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        pb.writeObjects(items.map { pairs in
            let item = NSPasteboardItem()
            for (t, d) in pairs { item.setData(d, forType: t) }
            return item
        })
    }
}
