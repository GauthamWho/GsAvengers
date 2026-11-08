// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The Quick Ring: a round glass ring of quick actions (capture, record,
/// clipboard, windows), opened right around the pointer by a double-tap of
/// ⌃ Control.
///
/// At rest it holds one listen-only, keyboard-only event tap on the input
/// thread; the monitors of an open ring go with it.
final class QuickRingService: ObservableObject {
    static let shared = QuickRingService()

    @Published private(set) var entries: [QuickRingEntry] = []
    @Published private(set) var highlightedIndex: Int?
    /// True from an opening until its closing starts. The entries stay put
    /// after a closing, so the next opening with the same actions costs
    /// SwiftUI nothing: the views are already built and laid out.
    private var shown = false

    private var panel: NSPanel?
    private var center: CGPoint = .zero
    private var eventMonitors: [Any] = []
    private var activationObserver: NSObjectProtocol?
    private let dismissal = PanelDismissal()

    private var keyTap: CFMachPort?
    private var keyTapSource: CFRunLoopSource?
    /// Touched only on the input thread that serves the tap.
    private var doubleTap = QuickRingDoubleTap()
    private var pressesAtControlDown: UInt32 = 0
    /// Where the ring's actions come from; G’s Mac's own by default.
    var actions: QuickRingActionProvider = GsMacQuickRingActions()

    private init() {
        // A tap owned by a switched-away login session stalls the session on
        // screen (issue #1075); hand it back on resign, rebuild on return.
        SessionActivity.shared.onChange { [weak self] active in
            if !active { self?.close() }
            self?.syncTaps()
        }
    }

    var isOpen: Bool { shown && !dismissal.isActive }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        guard AppFeature.quickRing.isOn else {
            suspend()
            return
        }
        syncTaps()
    }

    func suspend() {
        tearDownTap()
        forget()
        panel = nil
    }

    private var wantsKeyTap: Bool { AppFeature.quickRing.isOn }

    private func tapShouldRun(_ wanted: Bool) -> Bool {
        SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                            accessibilityGranted: AXIsProcessTrusted(),
                                            sessionIsActive: SessionActivity.shared.isActive)
    }

    /// One listen-only tap for the double-tap of ⌃ Control. It asks only for
    /// modifier changes and key presses (to know one came in between), never
    /// for pointer events, and runs on the input thread, not the main thread.
    private func syncTaps() {
        if tapShouldRun(wantsKeyTap) {
            if let keyTap, !CGEvent.tapIsEnabled(tap: keyTap) { tearDownTap() }
            if keyTap == nil { installTap() }
        } else {
            tearDownTap()
        }
    }

    private static let tapMask: CGEventMask =
        (CGEventMask(1) << CGEventType.flagsChanged.rawValue) | (CGEventMask(1) << CGEventType.keyDown.rawValue)

    private func installTap() {
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.tapMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<QuickRingService>.fromOpaque(userInfo).takeUnretainedValue()
                service.handleTap(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else { return }
        PointerTapRunLoop.add(source)
        CGEvent.tapEnable(tap: created, enable: true)
        keyTap = created
        keyTapSource = source
    }

    private func tearDownTap() {
        if let keyTap { CGEvent.tapEnable(tap: keyTap, enable: false) }
        if let keyTapSource { PointerTapRunLoop.remove(keyTapSource, invalidating: keyTap) }
        keyTap = nil
        keyTapSource = nil
    }

    // MARK: - Trigger (runs on the input thread; only toggling hops to main)

    private func handleTap(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            DispatchQueue.main.async { [weak self] in
                guard let self, let tap = self.keyTap, self.tapShouldRun(self.wantsKeyTap) else { return }
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .flagsChanged:
            handleFlags(event)
        case .keyDown:
            // This app's own posted keys are not the user typing between two taps.
            if !OwnKeyEvent.isPosted(event) { doubleTap.interrupt() }
        default:
            break
        }
    }

    private func handleFlags(_ event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == kVK_Control || keyCode == kVK_RightControl else {
            // Another modifier pressed or let go: not a clean Control tap.
            doubleTap.interrupt()
            return
        }
        let flags = event.flags
        let others = !flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]).isEmpty
        let isDown = flags.contains(.maskControl)
        // Clicks and system shortcuts between the taps move the window
        // server's press counters, so a ⌃-chord or ⌃-click never passes for a tap.
        let presses = Self.pressCount()
        var interrupted = false
        if isDown { pressesAtControlDown = presses } else { interrupted = presses != pressesAtControlDown }
        let seconds = TimeInterval(event.timestamp) / 1_000_000_000
        guard doubleTap.controlChanged(isDown: isDown, otherModifiers: others, interrupted: interrupted,
                                       at: seconds) else { return }
        // Secure input (a password field) keeps the keyboard to itself.
        guard !IsSecureEventInputEnabled() else { return }
        DispatchQueue.main.async { [weak self] in self?.toggle() }
    }

    /// Keys and clicks seen by the window server so far (counts only).
    private static func pressCount() -> UInt32 {
        [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(UInt32(0)) {
            $0 &+ CGEventSource.counterForEventType(.combinedSessionState, eventType: $1)
        }
    }

    // MARK: - Session

    func toggle() {
        if isOpen { close() } else { open() }
    }

    /// Opens at the pointer. Also the Settings page's try-it button.
    func open() {
        guard AppFeature.quickRing.isOn else { return }
        dismissal.cancel { forget() }
        let next = QuickRingSupport.entries(for: actions.currentContext())
        guard !next.isEmpty else { return }
        // Unchanged actions publish nothing, so nothing is rebuilt.
        if entries != next { entries = next }
        if highlightedIndex != nil { highlightedIndex = nil }
        shown = true

        let pointer = NSEvent.mouseLocation
        let frame = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }?.visibleFrame
            ?? NSScreen.pointerVisibleFrame
        center = QuickRingPlacement.center(pointer: pointer, visibleFrame: frame)
        let panel = ensurePanel()
        let half = QuickRingLayout.panelSize / 2
        panel.setFrame(NSRect(x: center.x - half, y: center.y - half,
                              width: QuickRingLayout.panelSize, height: QuickRingLayout.panelSize),
                       display: false)
        Self.present(panel)
        installMonitors(for: panel)
    }

    func close() {
        if dismissal.isActive { return }
        removeMonitors()
        guard let panel, panel.isVisible, shown else {
            forget()
            return
        }
        shown = false
        QuickRingMotion.shrink(panel)
        dismissal.begin(panel) { [weak self] in self?.forget() }
    }

    private func forget() {
        // Never leave the pointer hidden behind a closed ring (a list's
        // keyboard hide elsewhere waits for a mouse move that may not come).
        NSCursor.setHiddenUntilMouseMoves(false)
        shown = false
        panel?.orderOut(nil)
        if highlightedIndex != nil { highlightedIndex = nil }
        // A try-it opening can outlive an uninstall; nothing stays resident.
        if !AppFeature.quickRing.isOn {
            panel = nil
            entries = []
        }
    }

    // MARK: - Picking

    /// A click on the panel: a button runs, the hole or past the ring closes.
    func activatePointer() {
        guard isOpen else { return }
        if let index = QuickRingPlacement.highlightedIndex(pointer: NSEvent.mouseLocation, center: center,
                                                           itemCount: entries.count) {
            select(index)
        } else {
            close()
        }
    }

    func select(_ index: Int) {
        guard isOpen, entries.indices.contains(index) else { return }
        let item = entries[index].item
        close()
        // The ring is gone before anything captures or presents (its fade is
        // 0.13 s); the rest only waits one beat for the keyboard to return.
        let delay = item.waitsForRingToLeave ? 0.2 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [actions] in actions.run(item) }
    }

    private func pointerMoved() {
        guard isOpen else { return }
        let pointer = NSEvent.mouseLocation
        let dx = pointer.x - center.x
        let dy = pointer.y - center.y
        if (dx * dx + dy * dy).squareRoot() > QuickRingLayout.dismissDistance {
            close()
            return
        }
        let index = QuickRingPlacement.highlightedIndex(pointer: pointer, center: center,
                                                        itemCount: entries.count)
        if index != highlightedIndex { highlightedIndex = index }
    }

    private func moveHighlight(by delta: Int) {
        let count = entries.count
        guard count > 0 else { return }
        let current = highlightedIndex ?? (delta > 0 ? -1 : 0)
        highlightedIndex = ((current + delta) % count + count) % count
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            close()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let index = highlightedIndex { select(index) }
        case kVK_LeftArrow, kVK_UpArrow:
            moveHighlight(by: -1)
        case kVK_RightArrow, kVK_DownArrow, kVK_Tab:
            moveHighlight(by: 1)
        default:
            guard let digit = event.charactersIgnoringModifiers?.first?.wholeNumberValue,
                  (1...QuickRingSupport.maxItems).contains(digit) else { return false }
            if entries.indices.contains(digit - 1) { select(digit - 1) }
        }
        return true
    }

    // MARK: - Monitors (only while the ring is open)

    private func installMonitors(for panel: NSPanel) {
        removeMonitors()
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self, weak panel] event in
            guard let self, let panel, event.window === panel else { return event }
            return self.handleKeyDown(event) ? nil : event
        }) { eventMonitors.append(monitor) }

        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .otherMouseDragged]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            self?.pointerMoved()
            return event
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            self?.pointerMoved()
        }) { eventMonitors.append(monitor) }

        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self, weak panel] event in
            guard let self, let panel, panel.isVisible else { return event }
            guard event.window === panel else {
                self.close()
                return event
            }
            // A press on the ring picks by where it lands, before any view
            // weighs whether a first click into an inactive app counts.
            if event.type == .leftMouseDown { self.activatePointer() }
            return nil
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self, weak panel] event in
            guard let self, let panel, panel.isVisible, event.windowNumber != panel.windowNumber else { return }
            self.close()
        }) { eventMonitors.append(monitor) }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.close()
        }
    }

    private func removeMonitors() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors = []
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    // MARK: - Panel

    /// Key status (never app activation) so Esc, arrows and 1–4 reach the
    /// ring; it is handed back on the closing's first frame.
    private final class KeyableRingPanel: OverlayPanel {
        override var canBecomeKey: Bool { true }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let size = QuickRingLayout.panelSize
        let panel = KeyableRingPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                                     styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
        panel.title = "G’s Mac"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        // A plain hosting view of fixed size: it never measures itself to
        // resize the window, so ordering in and taking key lay nothing out.
        let host = NSHostingView(rootView: QuickRingView())
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: size, height: size)
        host.wantsLayer = true
        // Never let the hosting layer paint a plate of its own: the ring is
        // the only thing this window should ever show.
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.isOpaque = false
        panel.contentView = host
        self.panel = panel
        return panel
    }

    /// Ordered in and grown by the render server alone: a short fade of the
    /// window and a spring on the content's layer, so the main thread draws
    /// no frame of it and SwiftUI lays nothing out. Reduce Motion shows it
    /// at once.
    private static func present(_ panel: NSPanel) {
        panel.ignoresMouseEvents = false
        // Re-asserted at every showing: a system shadow behind a clear panel
        // reads as a grey box around the ring.
        panel.hasShadow = false
        panel.invalidateShadow()
        let animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = animates ? 0 : 1
        panel.orderFrontRegardless()
        panel.makeKey()
        guard animates else { return }
        QuickRingMotion.grow(panel)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = QuickRingMotion.fadeIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    // MARK: - Diagnostics (developer builds)

}

/// The ring's opening and closing motion, run by the render server on the
/// content's layer: the main thread only hands the animation over, so a busy
/// app can never stutter it and SwiftUI never re-lays the glass per frame.
enum QuickRingMotion {
    /// The window's fade in; the spring carries the rest.
    static let fadeIn: TimeInterval = 0.07
    /// Where the ring grows from, and shrinks to, as a share of its size.
    static let startScale: CGFloat = 0.86
    static let shrinkScale: CGFloat = 0.92
    private static let key = "quickRing.motion"

    /// The spring's whole run. Stiffness 1600 and damping 72 (ω 40, ζ 0.9)
    /// leave under 0.2 % of the growth by then, well below a point, so ending
    /// it there shows no jump.
    static let springDuration: CFTimeInterval = 0.18

    static func spring() -> CASpringAnimation {
        let spring = CASpringAnimation(keyPath: "transform")
        spring.mass = 1
        spring.stiffness = 1600
        spring.damping = 72
        spring.initialVelocity = 0
        spring.duration = springDuration
        return spring
    }

    static func grow(_ panel: NSPanel) {
        guard let layer = contentLayer(panel) else { return }
        let animation = spring()
        animation.fromValue = NSValue(caTransform3D: scaled(startScale, layer))
        animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        animation.fillMode = .backwards
        layer.add(animation, forKey: key)
    }

    static func shrink(_ panel: NSPanel) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let layer = contentLayer(panel) else { return }
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: layer.presentation()?.transform ?? CATransform3DIdentity)
        animation.toValue = NSValue(caTransform3D: scaled(shrinkScale, layer))
        animation.duration = 0.13
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        // Held until the next opening replaces it; the panel is gone by then.
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: key)
    }

    private static func contentLayer(_ panel: NSPanel) -> CALayer? {
        guard let view = panel.contentView else { return nil }
        view.wantsLayer = true
        return view.layer
    }

    /// A scale about the layer's middle, whatever its anchor point.
    private static func scaled(_ scale: CGFloat, _ layer: CALayer) -> CATransform3D {
        let bounds = layer.bounds
        let dx = bounds.midX - (bounds.minX + layer.anchorPoint.x * bounds.width)
        let dy = bounds.midY - (bounds.minY + layer.anchorPoint.y * bounds.height)
        var transform = CATransform3DMakeTranslation(dx, dy, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        return CATransform3DTranslate(transform, -dx, -dy, 0)
    }
}
