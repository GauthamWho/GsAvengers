// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The Quick Ring: a round glass ring of quick actions (capture, record,
/// clipboard, windows), opened right around the pointer by a double-tap of
/// ⌃ Control, ⌃-click or the middle mouse button.
///
/// It runs on the radial menu's engine pieces (slice maths, the fading
/// `PanelDismissal`, the keyable overlay panel and the session-aware tap
/// rules) without its profiles, submenus and hold phases. At rest it holds
/// only the event taps its switched-on triggers need: a listen-only tap for
/// ⌃ (it never changes or holds a key, and reads no characters) and a
/// filtering tap for the mouse triggers, which swallows only the click that
/// opens the ring. Every monitor of an open ring goes with it.
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
    private var mouseTap: CFMachPort?
    private var mouseTapSource: CFRunLoopSource?
    private var doubleTap = QuickRingDoubleTap()
    private var swallow = QuickRingClickSwallow()
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
        guard AppFeature.quickRing.isAvailable else {
            suspend()
            return
        }
        syncTaps()
        warmUp()
    }

    /// The first render of the hosting view and its glass costs real time
    /// (over 100 ms); pay it once now, drawn fully transparent and off the
    /// pointer's way, so the first real opening is as quick as every other.
    private func warmUp() {
        guard panel == nil else { return }
        let panel = ensurePanel()
        let next = QuickRingSupport.entries(for: actions.currentContext())
        if entries != next { entries = next }
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak panel] in
            guard let self, let panel, !self.shown, !self.dismissal.isActive else { return }
            panel.orderOut(nil)
        }
    }

    func suspend() {
        tearDown(&keyTap, &keyTapSource)
        tearDown(&mouseTap, &mouseTapSource)
        swallow.reset()
        forget()
        panel = nil
    }

    private static func triggerOn(_ trigger: QuickRingTrigger) -> Bool {
        AppFeature.quickRing.isAvailable && UserDefaults.standard.bool(forKey: trigger.defaultsKey)
    }

    private var wantsKeyTap: Bool { Self.triggerOn(.controlDoubleTap) }
    private var wantsMouseTap: Bool { Self.triggerOn(.controlClick) || Self.triggerOn(.middleClick) }

    private func tapShouldRun(_ wanted: Bool) -> Bool {
        SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                            accessibilityGranted: AXIsProcessTrusted(),
                                            sessionIsActive: SessionActivity.shared.isActive)
    }

    private func syncTaps() {
        if tapShouldRun(wantsKeyTap) {
            if let keyTap, !CGEvent.tapIsEnabled(tap: keyTap) { tearDown(&self.keyTap, &keyTapSource) }
            if keyTap == nil {
                // Control's own changes, and keys and clicks only to know one
                // came in between (a ⌃-click is not a tap): characters and
                // positions are never read.
                let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown,
                                            .otherMouseDown]
                let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
                install(&keyTap, &keyTapSource, mask: mask, options: .listenOnly)
            }
        } else {
            tearDown(&keyTap, &keyTapSource)
            doubleTap.interrupt()
        }
        if tapShouldRun(wantsMouseTap) {
            if let mouseTap, !CGEvent.tapIsEnabled(tap: mouseTap) { tearDown(&self.mouseTap, &mouseTapSource) }
            if mouseTap == nil {
                // Only the presses it may take and their releases.
                let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .otherMouseDown, .otherMouseUp]
                let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
                install(&mouseTap, &mouseTapSource, mask: mask, options: .defaultTap)
            }
        } else {
            tearDown(&mouseTap, &mouseTapSource)
            swallow.reset()
        }
    }

    private func install(_ tap: inout CFMachPort?, _ source: inout CFRunLoopSource?,
                         mask: CGEventMask, options: CGEventTapOptions) {
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: options == .listenOnly ? .tailAppendEventTap : .headInsertEventTap,
            options: options,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<QuickRingService>.fromOpaque(userInfo).takeUnretainedValue()
                return service.handleTap(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        source = runLoopSource
    }

    private func tearDown(_ tap: inout CFMachPort?, _ source: inout CFRunLoopSource?) {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    // MARK: - Triggers (the taps' callbacks run on the main run loop)

    private func handleTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Never invalidated from inside its own callback: fail open now,
            // then let the sync decide whether it comes back.
            // A release that went by while the tap was paused is not coming.
            swallow.reset()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for (tap, wanted) in [(self.keyTap, self.wantsKeyTap), (self.mouseTap, self.wantsMouseTap)] {
                    if let tap, self.tapShouldRun(wanted) { CGEvent.tapEnable(tap: tap, enable: true) }
                }
                self.syncTaps()
            }
            return pass
        }
        switch type {
        case .flagsChanged:
            handleFlags(event)
            return pass
        case .keyDown:
            // This app's own posted keys (snippets, quit protection) are not
            // the user typing between two taps.
            if !OwnKeyEvent.isPosted(event) { doubleTap.interrupt() }
            return pass
        case .rightMouseDown:
            doubleTap.interrupt()
            return pass
        default:
            if type == .leftMouseDown || type == .otherMouseDown { doubleTap.interrupt() }
            // The listen-only key tap also hears presses; it can take none.
            guard mouseTap != nil, wantsMouseTap else { return pass }
            return handleMouse(type: type, event: event) ? nil : pass
        }
    }

    private func handleFlags(_ event: CGEvent) {
        guard wantsKeyTap else { return }
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == kVK_Control || keyCode == kVK_RightControl else {
            // Another modifier pressed or let go: not a clean Control tap.
            doubleTap.interrupt()
            return
        }
        let flags = event.flags
        let others = !flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]).isEmpty
        let isDown = flags.contains(.maskControl)
        // System shortcuts (⌃→ between Spaces, ⌃↑ Mission Control) are taken
        // before any tap hears their key; the window server's own counts of
        // presses still move, so a ⌃-chord never passes for a tap.
        let presses = Self.pressCount()
        var interrupted = false
        if isDown { pressesAtControlDown = presses } else { interrupted = presses != pressesAtControlDown }
        let seconds = TimeInterval(event.timestamp) / 1_000_000_000
        guard doubleTap.controlChanged(isDown: isDown, otherModifiers: others, interrupted: interrupted,
                                       at: seconds) else { return }
        // Secure input (a password field) keeps the keyboard to itself.
        guard !IsSecureEventInputEnabled() else { return }
        #if VORSSAINT_DEVELOPMENT
        QuickRingFrameMeter.shared.triggered(eventTimestamp: event.timestamp)
        #endif
        toggle()
    }

    private var pressesAtControlDown: UInt32 = 0

    /// Keys and clicks seen by the window server so far (counts only).
    private static func pressCount() -> UInt32 {
        [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(UInt32(0)) {
            $0 &+ CGEventSource.counterForEventType(.combinedSessionState, eventType: $1)
        }
    }

    /// True when the event is the ring's and must not reach the app.
    private func handleMouse(type: CGEventType, event: CGEvent) -> Bool {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let isPress = type == .leftMouseDown || type == .otherMouseDown
        let isRelease = type == .leftMouseUp || type == .otherMouseUp
        // The release of a click whose press was the ring's.
        if swallow.takesRest(isPress: isPress, isRelease: isRelease, button: button) { return true }
        guard isPress else { return false }
        // A shortcut recorder listening for a button owns every press.
        if MouseButtonShortcutService.isCaptureActive { return false }
        let scope: MouseExceptionScope
        if type == .leftMouseDown {
            guard Self.triggerOn(.controlClick) else { return false }
            let flags = event.flags
            guard QuickRingTrigger.isControlClick(control: flags.contains(.maskControl),
                                                  command: flags.contains(.maskCommand),
                                                  option: flags.contains(.maskAlternate),
                                                  shift: flags.contains(.maskShift)) else { return false }
            scope = .buttonShortcuts
        } else {
            guard Self.triggerOn(.middleClick),
                  button == QuickRingTrigger.middleButtonNumber,
                  !middleButtonClaimedElsewhere() else { return false }
            scope = .middleClick
        }
        guard !IsSecureEventInputEnabled(),
              // Apps listed under the mouse exceptions keep their own clicks.
              !MouseAppExceptions.shared.excludesActionTarget(scope, at: event.location) else { return false }
        swallow.claim(button)
        #if VORSSAINT_DEVELOPMENT
        QuickRingFrameMeter.shared.triggered(eventTimestamp: event.timestamp)
        #endif
        toggle()
        return true
    }

    /// The middle button stays with whatever already owns it: a radial menu
    /// wheel, a mouse-button shortcut, or the trackpad's Middle Click.
    private func middleButtonClaimedElsewhere() -> Bool {
        let defaults = UserDefaults.standard
        let button = QuickRingTrigger.middleButtonNumber
        if AppFeature.middleClick.isAvailable, defaults.bool(forKey: DefaultsKey.middleClickEnabled) { return true }
        if MouseButtonShortcutSupport.claimsButton(button, defaults: defaults) { return true }
        guard AppFeature.radialMenu.isAvailable, defaults.bool(forKey: DefaultsKey.radialMenuEnabled) else {
            return false
        }
        return RadialMenuSupport.claimedMouseButtons(defaults.data(forKey: DefaultsKey.radialMenuProfiles),
                                                     defaults: defaults)
            .contains(button)
    }

    // MARK: - Session

    func toggle() {
        if isOpen { close() } else { open() }
    }

    /// Opens at the pointer. Also the Settings page's try-it button.
    func open() {
        guard AppFeature.quickRing.isAvailable else { return }
        #if VORSSAINT_DEVELOPMENT
        QuickRingFrameMeter.shared.opening()
        #endif
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
        #if VORSSAINT_DEVELOPMENT
        QuickRingFrameMeter.shared.ordered(panel)
        #endif
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
        #if VORSSAINT_DEVELOPMENT
        QuickRingFrameMeter.shared.closed()
        #endif
        shown = false
        panel?.orderOut(nil)
        if highlightedIndex != nil { highlightedIndex = nil }
        // A try-it opening can outlive an uninstall; nothing stays resident.
        if !AppFeature.quickRing.isAvailable {
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

    #if VORSSAINT_DEVELOPMENT
    var probeCenter: CGPoint? { isOpen ? center : nil }
    /// What the live check reads: whether the ring is up, where, and which
    /// actions it shows. No screen content.
    var probeState: [String: Any] {
        ["open": isOpen,
         "visible": panel?.isVisible ?? false,
         "alpha": Double(panel?.alphaValue ?? 0),
         "center": [Double(center.x), Double(center.y)],
         "frame": panel.map { [Double($0.frame.minX), Double($0.frame.minY),
                               Double($0.frame.width), Double($0.frame.height)] } ?? [],
         "isKey": panel?.isKeyWindow ?? false,
         "items": entries.map { $0.item.rawValue },
         "current": entries.filter(\.isCurrent).map { $0.item.rawValue },
         "keyTap": keyTap != nil,
         "mouseTap": mouseTap != nil]
    }
    #endif
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
