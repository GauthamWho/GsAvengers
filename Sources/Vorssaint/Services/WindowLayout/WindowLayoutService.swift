// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import CoreGraphics
import QuartzCore

enum WindowLayoutError: Equatable {
    case missingAccessibility
    case noWindow
    case noRestore
    case failed
}

enum WindowLayoutResult: Equatable {
    case success(restored: Bool)
    case failure(WindowLayoutError)
}

/// Window placement through explicit panel actions, global shortcuts and an
/// optional pointer gesture. The active taps only perform Accessibility work
/// after a deliberate gesture. Edge snapping changes an event only after the
/// same window has visibly followed the pointer to the top of a screen.
final class WindowLayoutService: ObservableObject {
    static let shared = WindowLayoutService()

    @Published private(set) var lastResult: WindowLayoutResult?
    /// Bumped on every published result, so a late settle failure can tell
    /// whether it still owns the feedback slot.
    private var resultGeneration = 0
    @Published private(set) var failedShortcutActions: Set<WindowLayoutAction> = []

    private var frameHistory = WindowLayoutHistory()
    private var lastActions: [WindowLayoutWindowKey: WindowLayoutAction] = [:]
    // Where each window's last placement left it, as requested and as read
    // back, minimum sizes included: the side size cycle only advances from there.
    private var settledFrames: [WindowLayoutWindowKey: WindowLayoutSettledFrame] = [:]
    private var hotKeyRefs: [WindowLayoutAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var registeredShortcuts: [WindowLayoutAction: GlobalShortcut] = [:]
    private var edgeSnapTap: CFMachPort?
    private var edgeSnapRunLoopSource: CFRunLoopSource?
    private var edgeSnapPressOrigin: CGPoint?
    private var edgeSnapPressCandidate: WindowServerWindowCandidate?
    private var edgeSnapSequenceSuppressed = false
    private var edgeSnapResolveAttempts = 0
    private var edgeSnapLastResolveAt: TimeInterval = 0
    private var edgeSnapDrag: WindowEdgeSnapDrag? {
        didSet { publishEdgeSnapProtection() }
    }
    private var edgeSnapSequenceGeneration = 0
    private var edgeSnapResolving = false
    private var edgeSnapLastPointer: CGPoint?
    private var edgeSnapTrail = WindowEdgeSnapPointerTrail()
    /// The pending look once the pointer stops, since a stop sends no event.
    /// Only one waits at a time, and a reset moves the generation on, which
    /// drops it.
    private var edgeSnapStillCheckGeneration = 0
    private var edgeSnapStillCheckPending = false
    private let edgeSnapResolveQueue = DispatchQueue(label: "com.vorssaint.edge-snap-resolve",
                                                     qos: .userInitiated)
    private var edgeSnapPreviewPanel: NSPanel?
    private var edgeSnapPreviewGeneration = 0
    private var assistiveModeSuspensions: [CGWindowID: EnhancedUserInterfaceSuspension] = [:]
    private var settleTimers: [CGWindowID: Timer] = [:]
    private var ignoredAppsActivationObserver: NSObjectProtocol?
    /// Stamped on the press this service gives back to the system so none of
    /// our own taps mistake it for a fresh one.
    private static let syntheticEventMarker: Int64 = 0x564F5253
    /// Read on every pointer event, so it is resolved once instead of per
    /// click.
    private static let ownProcessID = Int64(getpid())
    private let frameTolerance = WindowLayoutGeometry.frameTolerance
    private let anchorTolerance: CGFloat = 36
    // AX frame mutations are not atomic. Complex windows can visibly render
    // the intermediate size and position when they receive resize writes at
    // pointer-reporting speed, so resize is deliberately coalesced to 60 Hz.
    private let edgeSnapSampleInterval: TimeInterval = 1.0 / 30.0
    private let edgeSnapResolveAttemptLimit = 4

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        WindowLayoutIgnoredApps.shared.reload()
        let available = AppFeature.windowLayout.isOn
        let trusted = SessionActivitySupport.tapShouldRun(
            featureWanted: available,
            accessibilityGranted: AXIsProcessTrusted(),
            sessionIsActive: SessionActivity.shared.isActive)
        let shortcutsEnabled = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled)
            && trusted
        let edgeSnapEnabled = edgeSnapCanTrack && trusted
        syncIgnoredAppsActivationObserver(inputsEnabled: shortcutsEnabled || edgeSnapEnabled)
        let frontmost = NSWorkspace.shared.frontmostApplication
        let inputAllowed = !WindowLayoutIgnoredApps.shared.contains(
            bundleID: frontmost?.bundleIdentifier,
            executablePath: frontmost?.executableURL?.path)
        let wantsShortcuts = shortcutsEnabled && inputAllowed && !ShortcutCapture.isCapturing
        wantsShortcuts ? registerHotkeys() : unregisterHotkeys()

        let wantsEdgeSnap = edgeSnapEnabled && inputAllowed
        wantsEdgeSnap ? startEdgeSnapTap() : stopEdgeSnapTap()
    }

    private func syncIgnoredAppsActivationObserver(inputsEnabled: Bool) {
        let shouldObserve = inputsEnabled && !WindowLayoutIgnoredApps.shared.apps.isEmpty
        if shouldObserve {
            guard ignoredAppsActivationObserver == nil else { return }
            ignoredAppsActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.syncWithPreferences()
            }
        } else if let ignoredAppsActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(ignoredAppsActivationObserver)
            self.ignoredAppsActivationObserver = nil
        }
    }

    /// Stops every Window Layout input hook before Accessibility is revoked or
    /// the process terminates. Idempotent so permission and feature changes can
    /// call it freely.
    func suspend() {
        unregisterHotkeys()
        stopEdgeSnapTap()
        if let ignoredAppsActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(ignoredAppsActivationObserver)
            self.ignoredAppsActivationObserver = nil
        }
        for timer in settleTimers.values { timer.invalidate() }
        settleTimers.removeAll()
        let suspensions = assistiveModeSuspensions.values
        assistiveModeSuspensions.removeAll()
        // With the grant already revoked there is no safe way to touch the
        // apps again; the flag comes back when the assistive client sets it.
        guard AXIsProcessTrusted() else { return }
        for suspension in suspensions { suspension.resume() }
    }

    func shortcutConflictTitle(_ shortcut: GlobalShortcut) -> String? {
        shortcutConflictTitle(shortcut, excluding: nil)
    }

    func shortcutConflictTitle(_ shortcut: GlobalShortcut, excluding excluded: WindowLayoutAction?) -> String? {
        guard AppFeature.windowLayout.isOn,
              UserDefaults.standard.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled) else { return nil }
        let conflict = WindowLayoutAction.allCases.first { action in
            action != excluded && action.savedShortcut == shortcut
        }
        return conflict?.title(FeatureStrings.windowLayout(L10n.shared.language))
    }

    @discardableResult
    func apply(_ action: WindowLayoutAction) -> WindowLayoutResult {
        guard AXIsProcessTrusted() else {
            return finish(.failure(.missingAccessibility))
        }
        guard let target = focusedTarget(for: action) else {
            return finish(.failure(.noWindow))
        }
        pruneWindowState(keeping: target.key)

        if action == .restore {
            guard let previous = frameHistory.popPrevious(for: target.key,
                                                          current: target.frame) else {
                return finish(.failure(.noRestore))
            }
            if setFrame(previous, on: target.window, windowKey: target.key) {
                lastActions.removeValue(forKey: target.key)
                return finish(.success(restored: true))
            }
            frameHistory.record(previous, for: target.key)
            return finish(.failure(.failed))
        }

        if action == .fullScreen {
            // A placement still settling must never write its old frame over
            // the native full-screen transition that replaces it.
            cancelSettle(for: target.windowID)
            assistiveModeSuspensions.removeValue(forKey: target.windowID)?.resume()
            // The native full screen the green button gives, toggled through
            // the same attribute the button writes. The system owns the frame
            // from here, so nothing is remembered for restore.
            var raw: CFTypeRef?
            AXUIElementCopyAttributeValue(target.window, "AXFullScreen" as CFString, &raw)
            let isFullScreen = (raw as? NSNumber)?.boolValue ?? false
            let flipped = (isFullScreen ? kCFBooleanFalse : kCFBooleanTrue) as CFTypeRef
            let applied = AXUIElementSetAttributeValue(target.window,
                                                       "AXFullScreen" as CFString,
                                                       flipped) == .success
            // Remembered like any other placement, or the "same half twice
            // means maximize" rule would still be looking at whatever the
            // window did before it went full screen.
            if applied {
                if isFullScreen {
                    lastActions.removeValue(forKey: target.key)
                } else {
                    lastActions[target.key] = .fullScreen
                }
            }
            return applied ? finish(.success(restored: false)) : finish(.failure(.failed))
        }
        let screens = NSScreen.screens
        guard let screen = bestScreen(for: target.frame, screens: screens) else {
            return finish(.failure(.failed))
        }
        let currentRect = appKitFrame(fromAX: target.frame)
        if action == .previousDisplay || action == .nextDisplay {
            guard let destination = adjacentScreen(to: screen,
                                                   screens: screens,
                                                   movingForward: action == .nextDisplay) else {
                return finish(.failure(.failed))
            }
            let rect = WindowLayoutGeometry.rectForDisplay(current: currentRect,
                                                           sourceVisibleFrame: screen.windowLayoutVisibleFrame,
                                                           destinationVisibleFrame: destination.windowLayoutVisibleFrame)
            frameHistory.record(target.frame, for: target.key)
            if setFrame(axFrame(fromAppKit: rect),
                        targetRect: rect,
                        screenVisibleFrame: destination.windowLayoutVisibleFrame,
                        action: action,
                        on: target.window,
                        windowKey: target.key) {
                lastActions[target.key] = action
                return finish(.success(restored: false))
            }
            frameHistory.discardLatest(for: target.key)
            return finish(.failure(.failed))
        }
        let sideRepeatCyclesThirds = WindowLayoutSideRepeat.cyclesThirds
        if let crossing = WindowLayoutGeometry.displayCrossing(for: action,
                                                               previousAction: lastActions[target.key],
                                                               sideRepeatCyclesThirds: sideRepeatCyclesThirds),
           accepted(actual: target.frame,
                    targetRect: placement(for: action,
                                          current: target.frame,
                                          visibleFrame: screen.windowLayoutVisibleFrame).rect,
                    action: action),
           let destination = neighbourScreen(to: screen,
                                             screens: screens,
                                             direction: crossing.direction) {
            // The window is already parked on that half, so the same shortcut
            // keeps pushing in the same direction. Without a display there,
            // the placement below keeps its normal repeated-action behavior.
            return applyPlacement(crossing.action,
                                  to: target,
                                  visibleFrame: destination.windowLayoutVisibleFrame,
                                  cyclesRepeatedAction: false)
        }
        return applyPlacement(action,
                              to: target,
                              visibleFrame: screen.windowLayoutVisibleFrame,
                              sideRepeatCyclesThirds: sideRepeatCyclesThirds)
    }

    /// Applies a pointer-selected snap target to one exact external window.
    /// Dock Preview resolves the target from the drop location; the frame still
    /// goes through the same settling and recovery path as every Window Layout
    /// placement instead of maintaining a second AX mutation algorithm.
    @discardableResult
    private func finish(_ result: WindowLayoutResult) -> WindowLayoutResult {
        resultGeneration += 1
        lastResult = result
        return result
    }

    private func applyPlacement(_ action: WindowLayoutAction,
                                to target: WindowLayoutTarget,
                                visibleFrame: NSRect,
                                historyFrame: WindowLayoutFrame? = nil,
                                cyclesRepeatedAction: Bool = true,
                                sideRepeatCyclesThirds: Bool = false) -> WindowLayoutResult {
        let currentRect = appKitFrame(fromAX: target.frame)
        let previousAction = cyclesRepeatedAction ? lastActions[target.key] : nil
        let cyclePress = WindowLayoutGeometry.sideCyclePress(for: action,
                                                             cyclesThirds: sideRepeatCyclesThirds)
        // The size cycle only advances when the previous placement came from
        // the same side key and the window still sits where that step left
        // it: another shortcut, or a window dragged or resized by hand in
        // between, starts over at the half.
        let cyclesSides = cyclePress != nil
            && previousAction != nil
            && WindowLayoutGeometry.sideCycleResumes(pressing: action,
                                                     settled: settledFrames[target.key])
            && WindowLayoutGeometry.sideCycleContinues(current: target.frame,
                                                       settled: settledFrames[target.key],
                                                       tolerance: frameTolerance)
        let effectiveAction = WindowLayoutGeometry.effectiveAction(for: action,
                                                                   current: currentRect,
                                                                   visibleFrame: visibleFrame,
                                                                   previousAction: previousAction,
                                                                   sideRepeatCyclesThirds: cyclesSides)
        let placement = placement(for: effectiveAction,
                                  current: target.frame,
                                  visibleFrame: visibleFrame)
        if placement.frame == target.frame {
            lastActions[target.key] = effectiveAction
            if let cyclePress {
                settledFrames[target.key] = WindowLayoutSettledFrame(requested: target.frame,
                                                                     actual: target.frame,
                                                                     pressedAction: cyclePress)
            } else {
                settledFrames.removeValue(forKey: target.key)
            }
            return finish(.success(restored: false))
        }
        frameHistory.record(historyFrame ?? target.frame, for: target.key)
        if setFrame(placement.frame,
                    targetRect: placement.rect,
                    screenVisibleFrame: visibleFrame,
                    action: effectiveAction,
                    on: target.window,
                    windowKey: target.key,
                    cyclePress: cyclePress) {
            lastActions[target.key] = effectiveAction
            return finish(.success(restored: false))
        }
        frameHistory.discardLatest(for: target.key)
        return finish(.failure(.failed))
    }

    private func focusedTarget(for action: WindowLayoutAction) -> WindowLayoutTarget? {
        let ownBundleID = Bundle.main.bundleIdentifier
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownKeyWindow = NSApp.keyWindow
        let hasFocusedResizableOwnWindow = NSApp.isActive
            && ownKeyWindow?.styleMask.contains(.resizable) == true
            && !(ownKeyWindow is NSPanel)
        let frontmost = hasFocusedResizableOwnWindow
            ? ownPID
            : NSWorkspace.shared.frontmostApplication?.processIdentifier
        let pids = ([frontmost].compactMap { $0 } + WindowUseTracker.shared.apps).reduce(into: [pid_t]()) { result, pid in
            if !result.contains(pid) { result.append(pid) }
        }

        guard let onScreenWindowIDs = onScreenWindowIDs() else { return nil }
        for pid in pids {
            let isFocusedOwnApp = pid == ownPID && hasFocusedResizableOwnWindow
            // One lookup by pid, not a fresh bridge of every running app on
            // each turn of a list that can hold dozens of them. The edge-snap
            // drag in this same file already resolves its app this way.
            // isTerminated is explicit because runningApplications drops a dead
            // pid on its own and NSRunningApplication(processIdentifier:) does
            // not: it answers with a terminated instance.
            guard let app = NSRunningApplication(processIdentifier: pid),
                  !app.isTerminated,
                  isFocusedOwnApp
                    || (app.activationPolicy == .regular && !app.isHidden
                        && app.bundleIdentifier != ownBundleID)
            else { continue }
            let axApp = AXUIElementCreateApplication(pid)
            // Bounded AX: a hung app in the MRU list must not stall the main
            // thread (and every event tap) for the default timeout.
            AXUIElementSetMessagingTimeout(axApp, 0.35)
            for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
                if let window = windowAttribute(axApp, attribute as String),
                   let target = target(from: window,
                                       app: app,
                                       onScreenWindowIDs: onScreenWindowIDs,
                                       capability: action.targetCapability) {
                    return target
                }
            }
            if let windows = windowsAttribute(axApp),
               let first = windows.compactMap({ target(from: $0,
                                                        app: app,
                                                        onScreenWindowIDs: onScreenWindowIDs,
                                                        capability: action.targetCapability) }).first {
                return first
            }
        }
        return nil
    }

    private func target(from window: AXUIElement,
                        app: NSRunningApplication,
                        onScreenWindowIDs: Set<CGWindowID>,
                        capability: WindowLayoutTargetCapability) -> WindowLayoutTarget? {
        guard role(of: window) == (kAXWindowRole as String),
              !boolAttribute(window, kAXMinimizedAttribute as String),
              stringAttribute(window, kAXSubroleAttribute as String) != "AXFloatingWindow",
              let windowID = AXWindowResolver.windowID(for: window),
              onScreenWindowIDs.contains(windowID),
              let frame = frame(of: window),
              frame.size.width > 80,
              frame.size.height > 80
        else { return nil }
        let isFullScreen = boolAttribute(window, "AXFullScreen")
        guard capability == .fullScreen || !isFullScreen else { return nil }
        let hasRequiredCapability: Bool
        switch capability {
        case .position:
            hasRequiredCapability = canSetPosition(on: window)
        case .frame:
            hasRequiredCapability = canSetFrame(on: window)
        case .fullScreen:
            hasRequiredCapability = canSetFullScreen(on: window)
        }
        guard hasRequiredCapability else { return nil }
        let key = WindowLayoutWindowKey(
            processID: app.processIdentifier,
            processLaunchTime: app.launchDate?.timeIntervalSinceReferenceDate ?? 0,
            windowID: windowID
        )
        return WindowLayoutTarget(window: window, key: key, frame: frame)
    }

    private func onScreenWindowIDs() -> Set<CGWindowID>? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        return Set(windows.compactMap {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        })
    }

    /// Removes histories whose process or window no longer exists. This runs
    /// only for an explicit layout action, never from a timer or input tap.
    private func pruneWindowState(keeping current: WindowLayoutWindowKey) {
        guard var activeWindows = activeWindowKeys() else { return }
        activeWindows.insert(current)
        frameHistory.removeStaleWindows(keeping: activeWindows)
        lastActions = lastActions.filter { activeWindows.contains($0.key) }
        settledFrames = settledFrames.filter { activeWindows.contains($0.key) }
    }

    private func activeWindowKeys() -> Set<WindowLayoutWindowKey>? {
        guard let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        var launchTimes: [pid_t: TimeInterval] = [:]
        var keys = Set<WindowLayoutWindowKey>()
        for window in windows {
            guard (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let windowID = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value
            else { continue }
            if launchTimes[pid] == nil {
                guard let app = NSRunningApplication(processIdentifier: pid),
                      app.activationPolicy == .regular else { continue }
                launchTimes[pid] = app.launchDate?.timeIntervalSinceReferenceDate ?? 0
            }
            guard let launchTime = launchTimes[pid] else { continue }
            keys.insert(WindowLayoutWindowKey(processID: pid,
                                              processLaunchTime: launchTime,
                                              windowID: windowID))
        }
        return keys.isEmpty ? nil : keys
    }

    private func placement(for action: WindowLayoutAction,
                           current: WindowLayoutFrame,
                           visibleFrame: NSRect) -> WindowLayoutPlacement {
        let rect = WindowLayoutGeometry.rect(for: action,
                                             current: appKitFrame(fromAX: current),
                                             visibleFrame: visibleFrame,
                                             windowGap: WindowLayoutGaps.windowGap,
                                             screenGap: WindowLayoutGaps.screenGap,
                                             marginPercent: WindowLayoutMargin.percent)
        let integral = rect.integral
        return WindowLayoutPlacement(frame: axFrame(fromAppKit: integral), rect: integral)
    }

    private func setFrame(_ frame: WindowLayoutFrame,
                          on window: AXUIElement,
                          windowKey: WindowLayoutWindowKey) -> Bool {
        setFrame(frame,
                 targetRect: appKitFrame(fromAX: frame),
                 screenVisibleFrame: bestScreen(for: frame)?.visibleFrame ?? appKitFrame(fromAX: frame),
                 action: .restore,
                 on: window,
                 windowKey: windowKey)
    }

    private func setFrame(_ frame: WindowLayoutFrame,
                          targetRect: NSRect,
                          screenVisibleFrame: NSRect,
                          action: WindowLayoutAction,
                          on window: AXUIElement,
                          windowKey: WindowLayoutWindowKey,
                          cyclePress: WindowLayoutAction? = nil) -> Bool {
        let windowID = windowKey.windowID
        cancelSettle(for: windowID)
        assistiveModeSuspensions.removeValue(forKey: windowID)?.resume()
        assistiveModeSuspensions[windowID] = EnhancedUserInterfaceSuspension.suspend(forAppOf: window)

        let original = self.frame(of: window)
        settledFrames.removeValue(forKey: windowKey)
        if attempt(frame, targetRect: targetRect, visibleFrame: screenVisibleFrame, action: action, on: window) {
            assistiveModeSuspensions.removeValue(forKey: windowID)?.resume()
            // Only the side size cycle uses the settled frame, so the read-back
            // and its later refresh run only for a press that may cycle.
            if let cyclePress {
                let actual = self.frame(of: window) ?? frame
                settledFrames[windowKey] = WindowLayoutSettledFrame(requested: frame,
                                                                    actual: actual,
                                                                    pressedAction: cyclePress)
                if !actual.isClose(to: frame, tolerance: frameTolerance) {
                    // The lenient acceptance may have read a frame the app has
                    // not committed yet (issue #334); look again once it has,
                    // so a late, clamped resize still counts as the settled frame.
                    scheduleSettledFrameRefresh(for: window,
                                                windowKey: windowKey,
                                                targetRect: targetRect,
                                                action: action)
                }
            }
            return true
        }

        // Some apps commit Accessibility size changes with a short delay, so
        // the reads above can still see the old frame. Judging failure now and
        // restoring the original is what used to leave windows moved but never
        // resized (issue #334): let the window settle before deciding.
        scheduleSettle(SettleContext(window: window,
                                     windowID: windowID,
                                     frame: frame,
                                     targetRect: targetRect,
                                     screenVisibleFrame: screenVisibleFrame,
                                     action: action,
                                     original: original,
                                     previousAction: lastActions[windowKey],
                                     cyclePress: cyclePress,
                                     windowKey: windowKey,
                                     resultGeneration: resultGeneration + 1),
                       attempt: 0)
        return true
    }

    /// Observation only: re-reads the frame once the app has had time to
    /// commit a late resize and records it as the settled frame. Nothing is
    /// re-applied or restored, unlike the settle path, and the next placement
    /// cancels it through cancelSettle like any settle timer.
    private func scheduleSettledFrameRefresh(for window: AXUIElement,
                                             windowKey: WindowLayoutWindowKey,
                                             targetRect: NSRect,
                                             action: WindowLayoutAction) {
        let windowID = windowKey.windowID
        let timer = Timer(timeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.settleTimers[windowID] = nil
            // The user may have resized or dragged the window by hand in
            // the meantime; the lenient acceptance alone would record that
            // as settled and let the next side action cycle from it. Only a
            // frame that moved toward the request counts as the late commit.
            guard let settled = self.settledFrames[windowKey],
                  let actual = self.frame(of: window),
                  WindowLayoutGeometry.settledFrameRefreshAccepts(actual: actual,
                                                                  settled: settled,
                                                                  tolerance: self.frameTolerance),
                  actual.isClose(to: settled.requested, tolerance: self.frameTolerance)
                    || self.accepted(actual: actual, targetRect: targetRect, action: action)
            else { return }
            self.settledFrames[windowKey] = WindowLayoutSettledFrame(requested: settled.requested,
                                                                     actual: actual,
                                                                     pressedAction: settled.pressedAction)
        }
        settleTimers[windowID] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func scheduleSettle(_ context: SettleContext, attempt: Int) {
        let timer = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.settleTimers[context.windowID] = nil
            self.continueSettle(context, attempt: attempt)
        }
        settleTimers[context.windowID] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func continueSettle(_ context: SettleContext, attempt: Int) {
        if verified(context) {
            concludeSettle(context, success: true)
            return
        }
        if self.attempt(context.frame,
                        targetRect: context.targetRect,
                        visibleFrame: context.screenVisibleFrame,
                        action: context.action,
                        on: context.window) {
            concludeSettle(context, success: true)
            return
        }
        if attempt == 0 {
            scheduleSettle(context, attempt: 1)
            return
        }
        if let original = context.original, shouldUseMaximizeFallback(for: context.action) {
            // An ungapped scratch frame that coaxes a stubborn window into
            // resizing; the gapped target is re-applied right after.
            let currentRect = appKitFrame(fromAX: original)
            let maxFrame = axFrame(fromAppKit: WindowLayoutGeometry.rect(for: .maximize,
                                                                         current: currentRect,
                                                                         visibleFrame: context.screenVisibleFrame))
            applyFrame(maxFrame, on: context.window)
            if self.attempt(context.frame,
                            targetRect: context.targetRect,
                            visibleFrame: context.screenVisibleFrame,
                            action: context.action,
                            on: context.window) {
                concludeSettle(context, success: true)
                return
            }
        }
        concludeSettle(context, success: false)
    }

    private func verified(_ context: SettleContext) -> Bool {
        guard let actual = frame(of: context.window) else { return false }
        return actual.isClose(to: context.frame, tolerance: frameTolerance)
            || accepted(actual: actual, targetRect: context.targetRect, action: context.action)
    }

    // The action already reported success while the window was settling, so a
    // refusal this late restores the window, undoes the bookkeeping and
    // republishes the result the panel feedback listens to.
    private func concludeSettle(_ context: SettleContext, success: Bool) {
        assistiveModeSuspensions.removeValue(forKey: context.windowID)?.resume()
        if success {
            if let cyclePress = context.cyclePress {
                settledFrames[context.windowKey] = WindowLayoutSettledFrame(requested: context.frame,
                                                                            actual: frame(of: context.window) ?? context.frame,
                                                                            pressedAction: cyclePress)
            }
            return
        }
        settledFrames.removeValue(forKey: context.windowKey)
        if let original = context.original {
            applyFrame(original, on: context.window)
        }
        if context.action == .restore {
            frameHistory.record(context.frame, for: context.windowKey)
        } else {
            frameHistory.discardLatest(for: context.windowKey)
        }
        if let previousAction = context.previousAction {
            lastActions[context.windowKey] = previousAction
        } else {
            lastActions.removeValue(forKey: context.windowKey)
        }
        // A second action already published a fresh result; this stale
        // failure must not overwrite the feedback the person is reading.
        if context.resultGeneration == resultGeneration {
            lastResult = .failure(.failed)
        }
    }

    private func cancelSettle(for windowID: CGWindowID) {
        settleTimers.removeValue(forKey: windowID)?.invalidate()
    }

    private func attempt(_ frame: WindowLayoutFrame,
                         targetRect: NSRect,
                         visibleFrame: NSRect,
                         action: WindowLayoutAction,
                         on window: AXUIElement) -> Bool {
        for _ in 0..<3 {
            applyFrame(frame,
                       targetRect: targetRect,
                       visibleFrame: visibleFrame,
                       action: action,
                       on: window)
            guard let actual = self.frame(of: window) else { continue }
            if actual.isClose(to: frame, tolerance: frameTolerance)
                || accepted(actual: actual, targetRect: targetRect, action: action) {
                return true
            }
        }
        return false
    }

    private func shouldUseMaximizeFallback(for action: WindowLayoutAction) -> Bool {
        switch action {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerHalf,
                .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .centerTwoThirds,
                .topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds,
                .topQuarter, .upperMiddleQuarter, .lowerMiddleQuarter, .bottomQuarter,
                .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter,
                .topLeftSixth, .topCenterSixth, .topRightSixth,
                .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth,
                .topLeft, .topRight, .bottomLeft, .bottomRight, .marginMaximize:
            return true
        default:
            return false
        }
    }

    private func applyFrame(_ frame: WindowLayoutFrame, on window: AXUIElement) {
        _ = setSize(frame.size, on: window)
        _ = setPosition(frame.origin, on: window)
        _ = setSize(frame.size, on: window)
        _ = setPosition(frame.origin, on: window)
    }

    private func applyFrame(_ frame: WindowLayoutFrame,
                            targetRect: NSRect,
                            visibleFrame: NSRect,
                            action: WindowLayoutAction,
                            on window: AXUIElement) {
        let requestedRect = WindowLayoutGeometry.anchoredRect(for: action,
                                                              targetRect: targetRect,
                                                              actualSize: frame.size,
                                                              visibleFrame: visibleFrame)
        let requestedFrame = axFrame(fromAppKit: requestedRect)
        _ = setPosition(requestedFrame.origin, on: window)
        _ = setSize(frame.size, on: window)
        let acceptedSize = self.frame(of: window)?.size ?? frame.size
        let anchoredRect = WindowLayoutGeometry.anchoredRect(for: action,
                                                            targetRect: targetRect,
                                                            actualSize: acceptedSize,
                                                            visibleFrame: visibleFrame)
        let anchoredFrame = axFrame(fromAppKit: anchoredRect)
        _ = setPosition(anchoredFrame.origin, on: window)
        _ = setSize(frame.size, on: window)
        let finalSize = self.frame(of: window)?.size ?? acceptedSize
        let finalRect = WindowLayoutGeometry.anchoredRect(for: action,
                                                         targetRect: targetRect,
                                                         actualSize: finalSize,
                                                         visibleFrame: visibleFrame)
        _ = setPosition(axFrame(fromAppKit: finalRect).origin, on: window)
    }

    private func accepted(actual: WindowLayoutFrame,
                          targetRect: NSRect,
                          action: WindowLayoutAction) -> Bool {
        let actualRect = appKitFrame(fromAX: actual)
        return WindowLayoutGeometry.accepts(actualRect: actualRect,
                                            targetRect: targetRect,
                                            action: action,
                                            anchorTolerance: anchorTolerance)
    }

    // MARK: - Shortcuts

    private func registerHotkeys() {
        // Cleared shortcuts are simply absent: their key combo stays free for
        // other apps, which is the whole point of clearing them (issue #169).
        let shortcuts = Dictionary(uniqueKeysWithValues: WindowLayoutAction.shortcutActions.compactMap { action in
            action.savedShortcut.map { (action, $0) }
        })
        if !hotKeyRefs.isEmpty, shortcuts == registeredShortcuts { return }
        unregisterHotkeys()

        ensureHotKeyEventHandler()

        var failures = Set<WindowLayoutAction>()
        for action in WindowLayoutAction.shortcutActions {
            guard let shortcut = shortcuts[action] else { continue }
            let id = EventHotKeyID(signature: 0x5655_574C, id: action.shortcutID) // 'VUWL'
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.carbonKeyCode,
                                             shortcut.carbonModifiers,
                                             id,
                                             GetEventDispatcherTarget(),
                                             0,
                                             &ref)
            if status == noErr, let ref {
                hotKeyRefs[action] = ref
                SystemShortcutTakeover.claim(action.shortcutKey, shortcut: shortcut)
            } else {
                failures.insert(action)
            }
        }
        registeredShortcuts = shortcuts
        failedShortcutActions = failures
    }

    private func ensureHotKeyEventHandler() {
        if eventHandler == nil {
            var specs = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
            ]
            InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                if let event {
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &id)
                }
                let service = Unmanaged<WindowLayoutService>.fromOpaque(userData).takeUnretainedValue()
                let kind = event.map(GetEventKind) ?? 0
                guard id.signature == 0x5655_574C,
                      kind == UInt32(kEventHotKeyPressed),
                      let action = WindowLayoutAction(shortcutID: id.id) else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async { service.apply(action) }
                return noErr
            }, specs.count, &specs, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        }
    }

    /// Lets go of the layout keys while a shortcut field is listening, so the
    /// user can record a combination the layout actions already use. The
    /// gesture tap is left alone: it watches the mouse, not the keyboard. The
    /// next `syncWithPreferences` takes the keys back.
    func suspendShortcuts() {
        unregisterHotkeys()
    }

    private func unregisterHotkeys() {
        for (action, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
            SystemShortcutTakeover.release(action.shortcutKey)
        }
        hotKeyRefs.removeAll()
        registeredShortcuts.removeAll()
        failedShortcutActions.removeAll()
    }

    // MARK: - Drag to screen edge

    // Two taps, both served on the pointer-input thread, never the main
    // thread. At rest only a listen-only tap for left presses and releases
    // exists. A press arms the active drag tap, which only lives until the
    // button is let go: drags of the pointer pass through this app only while
    // a button is held, never ordinary movement. The drag tap changes an event
    // only after the same window has visibly followed the pointer to the top
    // of a screen (the main thread publishes that in `edgeSnapProtection`).
    private var edgeSnapDragTap: CFMachPort?
    private var edgeSnapDragSource: CFRunLoopSource?
    /// Input-thread state for one press.
    private var tapSequenceSuppressed = false
    private var tapLastDragForward: UInt64 = 0
    /// What the drag tap may change while a confirmed window move is near the
    /// top edge; written on main, read on the input thread.
    private let edgeSnapProtectionLock = NSLock()
    private var edgeSnapProtection: (frames: [CGRect], zones: Set<WindowEdgeSnapZone>)?

    private func publishEdgeSnapProtection() {
        let value: (frames: [CGRect], zones: Set<WindowEdgeSnapZone>)?
        if let drag = edgeSnapDrag, drag.isMoving, drag.protectsSystemTopEdge {
            value = (drag.quartzScreenFrames, drag.enabledZones)
        } else {
            value = nil
        }
        edgeSnapProtectionLock.withLock { edgeSnapProtection = value }
    }

    private func startEdgeSnapTap() {
        guard edgeSnapTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<WindowLayoutService>.fromOpaque(userInfo).takeUnretainedValue()
                service.observeEdgeSnapPress(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        edgeSnapTap = tap
        edgeSnapRunLoopSource = source
        PointerTapRunLoop.add(source)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopEdgeSnapTap() {
        edgeSnapSequenceGeneration += 1
        // A resolve still in flight answers against the old generation and is
        // dropped, so the flag it holds has to be released here or the next
        // drag would never start one.
        edgeSnapResolving = false
        edgeSnapPressOrigin = nil
        edgeSnapPressCandidate = nil
        edgeSnapLastPointer = nil
        resetEdgeSnapTrail()
        edgeSnapSequenceSuppressed = false
        edgeSnapResolveAttempts = 0
        edgeSnapDrag = nil
        hideEdgeSnapPreview(immediately: true)
        if let edgeSnapTap { CGEvent.tapEnable(tap: edgeSnapTap, enable: false) }
        if let edgeSnapRunLoopSource { PointerTapRunLoop.remove(edgeSnapRunLoopSource, invalidating: edgeSnapTap) }
        edgeSnapTap = nil
        edgeSnapRunLoopSource = nil
        edgeSnapPreviewPanel = nil
        setDragTapInstalled(false)
    }

    /// Makes or removes the drag tap on the input thread that serves it.
    private func setDragTapInstalled(_ on: Bool) {
        let work = { [weak self] in
            guard let self else { return }
            if on {
                guard self.edgeSnapDragTap == nil else { return }
                guard let tap = CGEvent.tapCreate(
                    tap: .cgSessionEventTap,
                    place: .headInsertEventTap,
                    options: .defaultTap,
                    eventsOfInterest: CGEventMask(1 << CGEventType.leftMouseDragged.rawValue),
                    callback: { _, type, event, userInfo in
                        guard let userInfo else { return Unmanaged.passUnretained(event) }
                        let service = Unmanaged<WindowLayoutService>.fromOpaque(userInfo).takeUnretainedValue()
                        return service.observeEdgeSnapDrag(type: type, event: event)
                    },
                    userInfo: Unmanaged.passUnretained(self).toOpaque()
                ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                self.edgeSnapDragTap = tap
                self.edgeSnapDragSource = source
            } else {
                guard let tap = self.edgeSnapDragTap else { return }
                CGEvent.tapEnable(tap: tap, enable: false)
                if let source = self.edgeSnapDragSource {
                    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
                }
                CFMachPortInvalidate(tap)
                self.edgeSnapDragTap = nil
                self.edgeSnapDragSource = nil
            }
        }
        PointerTapRunLoop.perform(work)
    }

    /// Press and release, heard on the input thread.
    private func observeEdgeSnapPress(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tap = self.edgeSnapTap else { return }
                if SessionActivity.shared.isActive, AXIsProcessTrusted() {
                    CGEvent.tapEnable(tap: tap, enable: true)
                } else {
                    self.syncWithPreferences()
                }
                self.cancelEdgeSnapTracking()
            }
            return
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.syntheticEventMarker,
              event.getIntegerValueField(.eventSourceUnixProcessID) != Self.ownProcessID
        else { return }
        if type == .leftMouseDown {
            // macOS 15 tiles windows itself when its own setting is on.
            tapSequenceSuppressed = WindowEdgeSnapSupport.isSystemTilingEnabled
            guard !tapSequenceSuppressed else { return }
            setDragTapInstalled(true)
            let input = WindowEdgeSnapPointerInput.down(location: event.location, flags: event.flags)
            DispatchQueue.main.async { [weak self] in self?.handleEdgeSnapInput(input) }
        } else if type == .leftMouseUp {
            setDragTapInstalled(false)
            guard !tapSequenceSuppressed else { tapSequenceSuppressed = false; return }
            let input = WindowEdgeSnapPointerInput.up(location: event.location, time: Self.seconds(of: event))
            DispatchQueue.main.async { [weak self] in self?.handleEdgeSnapInput(input) }
        }
    }

    /// Drags while a button is held, on the input thread: one lock read, at
    /// most one hand-off to main per 1/60 s, and the top-edge adjustment.
    private func observeEdgeSnapDrag(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = edgeSnapDragTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .leftMouseDragged, !tapSequenceSuppressed else { return Unmanaged.passUnretained(event) }
        let originalLocation = event.location
        if let protection = edgeSnapProtectionLock.withLock({ edgeSnapProtection }) {
            event.location = WindowEdgeSnapSupport.locationAvoidingSystemTopDrag(
                originalLocation, screenFrames: protection.frames, enabledZones: protection.zones)
        }
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        guard now &- tapLastDragForward >= 16_000_000 else { return Unmanaged.passUnretained(event) }
        tapLastDragForward = now
        let input = WindowEdgeSnapPointerInput.dragged(location: originalLocation, time: Self.seconds(of: event))
        DispatchQueue.main.async { [weak self] in self?.handleEdgeSnapInput(input) }
        return Unmanaged.passUnretained(event)
    }

    /// Seconds of uptime, on the clock event timestamps use, so speed is read
    /// from when the pointer moved rather than when the main thread got to it.
    private static func seconds(of event: CGEvent) -> TimeInterval {
        // Some software posts events with no timestamp. Read as zero, every
        // event of a drag would land on one instant: the trail would never
        // age and every reading would be fast, so the clock stands in.
        guard event.timestamp != 0 else { return uptimeSeconds }
        return TimeInterval(EventTimestamp.nanoseconds(of: event)) / 1_000_000_000
    }

    private static var uptimeSeconds: TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000
    }

    private func handleEdgeSnapInput(_ input: WindowEdgeSnapPointerInput) {
        switch input {
        case .down(let location, let flags):
            cancelEdgeSnapTracking()
            edgeSnapSequenceSuppressed = false
            _ = flags
            guard edgeSnapCanTrack else {
                edgeSnapSequenceSuppressed = true
                return
            }
            guard let candidate = WindowServerWindowHitTest.candidate(at: location, pidIsEligible: {
                guard let app = NSRunningApplication(processIdentifier: $0) else { return false }
                return !app.isTerminated && app.activationPolicy == .regular
            }),
            !WindowEdgeSnapSupport.startsAtResizeHandle(location, frame: candidate.frame)
            else {
                edgeSnapSequenceSuppressed = true
                return
            }
            edgeSnapPressOrigin = location
            edgeSnapPressCandidate = candidate
            edgeSnapResolveAttempts = 0
            edgeSnapLastResolveAt = 0

        case .dragged(let location, let time):
            guard let pressOrigin = edgeSnapPressOrigin,
                  let pressCandidate = edgeSnapPressCandidate
            else {
                cancelEdgeSnapTracking()
                return
            }
            edgeSnapLastPointer = location
            edgeSnapTrail.append(location, at: time)
            if edgeSnapDrag == nil,
               WindowEdgeSnapSupport.exceedsDragSlop(from: pressOrigin, to: location) {
                let now = ProcessInfo.processInfo.systemUptime
                if !edgeSnapResolving, edgeSnapResolveAttempts < edgeSnapResolveAttemptLimit,
                   now - edgeSnapLastResolveAt >= 0.08 {
                    edgeSnapResolveAttempts += 1
                    edgeSnapLastResolveAt = now
                    beginEdgeSnapResolve(pointerStart: pressOrigin,
                                         pressCandidate: pressCandidate)
                }
            }
            updateEdgeSnapDrag(at: location, forceSample: false, now: time)
            scheduleEdgeSnapStillCheck()

        case .up(let location, let time):
            let pressOrigin = edgeSnapPressOrigin
            let pressCandidate = edgeSnapPressCandidate
            let followsMoveGesture = false
            let velocity = edgeSnapTrail.velocity(at: time)
            // Looking the window up here waits on its app from the run loop
            // that serves the taps. It happens only for a release over a snap
            // zone, once the window server shows the window followed the
            // pointer, so the release of a drag inside an app never asks that
            // app. A modifier move needs no such evidence: Vorssaint moved
            // that window itself. Its release only skips a lookup that has
            // already come back empty every time it was tried.
            let lookupsExhausted = edgeSnapResolveAttempts >= edgeSnapResolveAttemptLimit && !edgeSnapResolving
            let releasedOverZone = pressOrigin.map {
                WindowEdgeSnapSupport.exceedsDragSlop(from: $0, to: location)
                    && edgeSnapTarget(atQuartzPoint: location, velocity: velocity) != nil
            } ?? false
            var lookedUpAtRelease = false
            if edgeSnapDrag == nil, releasedOverZone,
               let pressOrigin, let pressCandidate,
               followsMoveGesture
                ? !lookupsExhausted
                : edgeSnapWindowFollowed(pressCandidate, from: pressOrigin, to: location) {
                lookedUpAtRelease = true
                edgeSnapDrag = makeEdgeSnapDrag(pointerStart: pressOrigin,
                                                pressCandidate: pressCandidate)
            }
            updateEdgeSnapDrag(at: location, forceSample: true, now: time)
            let completed = edgeSnapDrag
            edgeSnapPressOrigin = nil
            edgeSnapPressCandidate = nil
            edgeSnapLastPointer = nil
            resetEdgeSnapTrail()
            edgeSnapResolveAttempts = 0
            edgeSnapDrag = nil
            hideEdgeSnapPreview(immediately: false)
            let generation = edgeSnapSequenceGeneration
            guard let completed else {
                // A window whose lookup already came back empty at release is
                // not asked a second time, and a modifier move has nothing
                // left for the window server to show.
                guard releasedOverZone, !lookedUpAtRelease, !followsMoveGesture,
                      let pressOrigin, let pressCandidate
                else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                    guard let self, generation == self.edgeSnapSequenceGeneration,
                          self.edgeSnapWindowFollowed(pressCandidate, from: pressOrigin, to: location),
                          let delayed = self.makeEdgeSnapDrag(pointerStart: pressOrigin,
                                                              pressCandidate: pressCandidate)
                    else { return }
                    self.applyDelayedEdgeSnapIfMoved(delayed, releaseLocation: location, velocity: velocity)
                }
                return
            }
            if !completed.isMoving {
                guard let pressOrigin,
                      WindowEdgeSnapSupport.exceedsDragSlop(from: pressOrigin, to: location)
                else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                    guard let self, generation == self.edgeSnapSequenceGeneration else { return }
                    self.applyDelayedEdgeSnapIfMoved(completed, releaseLocation: location, velocity: velocity)
                }
                return
            }
            guard let target = completed.target else { return }
            // The callback has already forwarded this mouse-up. One
            // more main-loop turn lets the target app finish its own drag
            // before the placement writes the final frame.
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.edgeSnapSequenceGeneration else { return }
                self.applyEdgeSnap(completed, target: target)
            }
        }
    }

    /// The check 40 ms after a release that left the drag undecided, which
    /// covers nearly every drag inside an app. The frame comes from the window
    /// server like every sample before it, and only a window that moved goes on
    /// to the placement, the one step that has to ask its app.
    private func applyDelayedEdgeSnapIfMoved(_ drag: WindowEdgeSnapDrag,
                                             releaseLocation: CGPoint,
                                             velocity: CGVector) {
        guard let current = WindowServerSupport.frame(ofWindowID: drag.key.windowID),
              WindowEdgeSnapSupport.classify(
                initialFrame: drag.initialFrame,
                currentFrame: current,
                pointerStart: drag.pointerStart,
                pointerNow: releaseLocation
              ) == .moving,
              let target = edgeSnapTarget(atQuartzPoint: releaseLocation, velocity: velocity)
        else { return }
        applyEdgeSnap(drag, target: target)
    }

    /// Whether the pressed window followed the pointer, as the window server
    /// sees it right now. It decides whether the release may ask the window's
    /// app at all.
    private func edgeSnapWindowFollowed(_ candidate: WindowServerWindowCandidate,
                                        from pointerStart: CGPoint,
                                        to pointer: CGPoint) -> Bool {
        guard let current = WindowServerSupport.frame(ofWindowID: candidate.windowID) else { return false }
        return WindowEdgeSnapSupport.classify(initialFrame: candidate.frame,
                                              currentFrame: current,
                                              pointerStart: pointerStart,
                                              pointerNow: pointer) == .moving
    }

    /// Resolves the dragged window without the drag ever waiting for it.
    ///
    /// Finding the Accessibility element means asking the application for its
    /// window list and then asking each window for its identifier, and both are
    /// cross-process calls answered by that application's main thread. Measured
    /// on a real drag, that search was most of what the main thread still spent
    /// blocked, which showed up as a stall at every press.
    ///
    /// Nothing during a drag needs that element: the rectangle comes from the
    /// window server and the snap target is pure geometry. It is needed only to
    /// move the window once the drag ends, so it is resolved in the background
    /// and adopted when it arrives. A drag that ends before the answer still
    /// snaps, because the release path looks the window up itself. That lookup
    /// runs on the run loop the taps share, so it is kept for a window the
    /// window server saw follow the pointer.
    private func beginEdgeSnapResolve(pointerStart: CGPoint,
                                      pressCandidate: WindowServerWindowCandidate) {
        edgeSnapResolving = true
        let generation = edgeSnapSequenceGeneration
        // NSScreen is main-thread only, so the geometry is captured before leaving.
        let screenFrames = edgeSnapQuartzScreenFrames()
        let zones = enabledEdgeSnapZones
        let protectsTop = WindowEdgeSnapSupport.isSystemTopWindowOverviewDragEnabled
        let onScreen = onScreenWindowIDs()
        edgeSnapResolveQueue.async { [weak self] in
            let resolved = self?.resolveEdgeSnapWindow(pressCandidate: pressCandidate,
                                                       onScreenWindowIDs: onScreen)
            DispatchQueue.main.async {
                guard let self, self.edgeSnapSequenceGeneration == generation else { return }
                self.edgeSnapResolving = false
                guard let resolved, self.edgeSnapDrag == nil,
                      self.edgeSnapPressCandidate != nil else { return }
                // A modifier move is moving from the start: Vorssaint moves that
                // window, so the window server is never asked to confirm it.
                self.edgeSnapDrag = WindowEdgeSnapDrag(window: resolved.window,
                                                       key: resolved.key,
                                                       initialFrame: pressCandidate.frame,
                                                       pointerStart: pointerStart,
                                                       protectsSystemTopEdge: protectsTop,
                                                       quartzScreenFrames: screenFrames,
                                                       enabledZones: zones,
                                                       lastSampleAt: 0,
                                                       mismatchCount: 0,
                                                       isMoving: false,
                                                       target: nil)
                // The pointer may already rest at an edge, and no further drag
                // event would come to show the preview or to protect the top
                // edge until it moves again.
                if let pointer = self.edgeSnapLastPointer {
                    self.updateEdgeSnapDrag(at: pointer, forceSample: true, now: Self.uptimeSeconds)
                }
            }
        }
    }

    /// The Accessibility half, off the main thread. Touches no service state.
    private func resolveEdgeSnapWindow(pressCandidate: WindowServerWindowCandidate,
                                       onScreenWindowIDs: Set<CGWindowID>?)
        -> (window: AXUIElement, key: WindowLayoutWindowKey)? {
        guard let app = NSRunningApplication(processIdentifier: pressCandidate.pid),
              !app.isTerminated, app.activationPolicy == .regular else { return nil }
        let axApp = AXUIElementCreateApplication(pressCandidate.pid)
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        guard let window = windowsAttribute(axApp)?.first(where: {
                  AXWindowResolver.windowID(for: $0) == pressCandidate.windowID
              }) else { return nil }
        AXUIElementSetMessagingTimeout(window, 0.25)
        guard let onScreenWindowIDs,
              let target = target(from: window,
                                  app: app,
                                  onScreenWindowIDs: onScreenWindowIDs,
                                  capability: .frame) else { return nil }
        return (target.window, target.key)
    }

    /// The same lookup as the background path, run inline. Only the release
    /// path uses it, for a window the window server saw follow the pointer,
    /// since the taps wait on this run loop while it asks the window's app.
    private func makeEdgeSnapDrag(pointerStart: CGPoint,
                                  pressCandidate: WindowServerWindowCandidate) -> WindowEdgeSnapDrag? {
        guard let resolved = resolveEdgeSnapWindow(pressCandidate: pressCandidate,
                                                   onScreenWindowIDs: onScreenWindowIDs())
        else { return nil }
        return WindowEdgeSnapDrag(window: resolved.window,
                                  key: resolved.key,
                                  initialFrame: pressCandidate.frame,
                                  pointerStart: pointerStart,
                                  protectsSystemTopEdge: WindowEdgeSnapSupport.isSystemTopWindowOverviewDragEnabled,
                                  quartzScreenFrames: edgeSnapQuartzScreenFrames(),
                                  enabledZones: enabledEdgeSnapZones,
                                  lastSampleAt: 0,
                                  mismatchCount: 0,
                                  isMoving: false,
                                  target: nil)
    }

    /// `now` is the moment the reading is for: the event's own time, or the
    /// clock when no event brought it.
    private func updateEdgeSnapDrag(at location: CGPoint, forceSample: Bool, now: TimeInterval) {
        guard var drag = edgeSnapDrag else { return }
        if !drag.isMoving {
            let sampledAt = ProcessInfo.processInfo.systemUptime
            guard forceSample || sampledAt - drag.lastSampleAt >= edgeSnapSampleInterval else { return }
            drag.lastSampleAt = sampledAt
            // Sampled up to thirty times a second for the length of a drag, so
            // it must not wait on anybody. Accessibility would ask the dragged
            // application, whose main thread is the one redrawing that drag;
            // the window server already holds the rectangle and answers without
            // stalling. The press frame comes from the same source, so both
            // sides of the comparison stay in one coordinate space.
            guard let currentFrame = WindowServerSupport.frame(ofWindowID: drag.key.windowID) else {
                cancelEdgeSnapTracking()
                return
            }
            switch WindowEdgeSnapSupport.classify(initialFrame: drag.initialFrame,
                                                  currentFrame: currentFrame,
                                                  pointerStart: drag.pointerStart,
                                                  pointerNow: location) {
            case .waiting:
                edgeSnapDrag = drag
                return
            case .moving:
                drag.isMoving = true
                drag.mismatchCount = 0
            case .resizing:
                cancelEdgeSnapTracking()
                return
            case .unrelated:
                drag.mismatchCount += 1
                if drag.mismatchCount >= 3 {
                    cancelEdgeSnapTracking()
                } else {
                    edgeSnapDrag = drag
                }
                return
            }
        }

        let target = edgeSnapTarget(atQuartzPoint: location, velocity: edgeSnapTrail.velocity(at: now))
        if target != drag.target {
            drag.target = target
            if let target {
                showEdgeSnapPreview(frame: target.frame)
            } else {
                hideEdgeSnapPreview(immediately: false)
            }
        }
        edgeSnapDrag = drag
    }

    /// `velocity` is in Quartz points per second, like the point.
    private func edgeSnapTarget(atQuartzPoint point: CGPoint, velocity: CGVector) -> WindowEdgeSnapTarget? {
        let appKitPoint = CGPoint(x: point.x, y: menuBarScreenTopY - point.y)
        let screens = NSScreen.screens.map {
            WindowEdgeSnapScreen(frame: $0.frame, visibleFrame: $0.windowLayoutVisibleFrame)
        }
        return WindowEdgeSnapSupport.target(at: appKitPoint,
                                            screens: screens,
                                            velocity: CGVector(dx: velocity.dx, dy: -velocity.dy),
                                            enabledZones: enabledEdgeSnapZones,
                                            layout: edgeSnapLayout)
    }

    /// A pointer that stops at a seam after moving fast sends no further
    /// event, so the last reading would stay fast. One look after it has been
    /// still for long enough reads it as stopped. A mouse can report a
    /// thousand times a second through any drag, text selection included, so
    /// one look waits at a time and moves itself on while events keep coming.
    private func scheduleEdgeSnapStillCheck() {
        guard !edgeSnapStillCheckPending else { return }
        edgeSnapStillCheckPending = true
        armEdgeSnapStillCheck(after: WindowEdgeSnapPointerTrail.stillAfter)
    }

    private func armEdgeSnapStillCheck(after delay: TimeInterval) {
        let check = edgeSnapStillCheckGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            // Every cancel resets the trail, which moves this generation on too.
            guard let self, check == self.edgeSnapStillCheckGeneration else { return }
            let now = Self.uptimeSeconds
            let stillAfter = WindowEdgeSnapPointerTrail.stillAfter
            if let last = self.edgeSnapTrail.lastTime, now - last < stillAfter {
                // The pointer moved since this look was set, so it waits out
                // the rest of the pause from the last event, and never longer
                // than a whole pause for an event stamped ahead of the clock.
                self.armEdgeSnapStillCheck(after: min(stillAfter - (now - last), stillAfter))
                return
            }
            self.edgeSnapStillCheckPending = false
            guard let pointer = self.edgeSnapLastPointer else { return }
            self.updateEdgeSnapDrag(at: pointer, forceSample: true, now: now)
        }
    }

    private func resetEdgeSnapTrail() {
        edgeSnapTrail.reset()
        edgeSnapStillCheckGeneration += 1
        edgeSnapStillCheckPending = false
    }

    private func edgeSnapQuartzScreenFrames() -> [CGRect] {
        let top = menuBarScreenTopY
        return NSScreen.screens.map {
            CGRect(x: $0.frame.minX,
                   y: top - $0.frame.maxY,
                   width: $0.frame.width,
                   height: $0.frame.height)
        }
    }

    private func applyEdgeSnap(_ drag: WindowEdgeSnapDrag,
                               target: WindowEdgeSnapTarget) {
        guard AppFeature.windowLayout.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.windowEdgeSnapEnabled),
              enabledEdgeSnapZones.contains(target.zone),
              !WindowEdgeSnapSupport.isSystemTilingEnabled,
              AXIsProcessTrusted(),
              canSetFrame(on: drag.window),
              AXWindowResolver.windowID(for: drag.window) == drag.key.windowID,
              let currentFrame = frame(of: drag.window)
        else { return }
        var processID = pid_t(0)
        guard AXUIElementGetPid(drag.window, &processID) == .success,
              processID == drag.key.processID else { return }

        let layoutTarget = WindowLayoutTarget(window: drag.window,
                                              key: drag.key,
                                              frame: currentFrame)
        pruneWindowState(keeping: drag.key)
        let history = WindowLayoutFrame(origin: drag.initialFrame.origin,
                                        size: drag.initialFrame.size)
        _ = applyPlacement(target.action,
                           to: layoutTarget,
                           visibleFrame: target.visibleFrame,
                           historyFrame: history,
                           cyclesRepeatedAction: false)
    }

    private func cancelEdgeSnapTracking() {
        edgeSnapSequenceGeneration += 1
        // A resolve still in flight answers against the old generation and is
        // dropped, so the flag it holds has to be released here or the next
        // drag would never start one.
        edgeSnapResolving = false
        edgeSnapPressOrigin = nil
        edgeSnapPressCandidate = nil
        edgeSnapLastPointer = nil
        resetEdgeSnapTrail()
        edgeSnapSequenceSuppressed = true
        edgeSnapResolveAttempts = 0
        edgeSnapDrag = nil
        hideEdgeSnapPreview(immediately: false)
    }

    /// Whether a new drag may be tracked toward an edge, asked at every press
    /// whichever tap saw it.
    private var edgeSnapCanTrack: Bool {
        AppFeature.windowLayout.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.windowEdgeSnapEnabled)
            && !enabledEdgeSnapZones.isEmpty
            && !WindowEdgeSnapSupport.isSystemTilingEnabled
            && AXIsProcessTrusted()
    }

    private var enabledEdgeSnapZones: Set<WindowEdgeSnapZone> {
        WindowEdgeSnapZone.enabledZones(
            from: UserDefaults.standard.string(forKey: DefaultsKey.windowEdgeSnapDisabledZones)
        )
    }

    private var edgeSnapLayout: WindowEdgeSnapLayout {
        WindowEdgeSnapLayout(
            storageValue: UserDefaults.standard.string(forKey: DefaultsKey.windowEdgeSnapZoneActions)
        )
    }

    private func showEdgeSnapPreview(frame: CGRect) {
        edgeSnapPreviewGeneration += 1
        let panel: NSPanel
        if let existing = edgeSnapPreviewPanel {
            panel = existing
        } else {
            panel = makeEdgeSnapPreviewPanel()
            edgeSnapPreviewPanel = panel
        }
        panel.setFrame(frame, display: true)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.09
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func hideEdgeSnapPreview(immediately: Bool) {
        guard let panel = edgeSnapPreviewPanel, panel.isVisible else { return }
        edgeSnapPreviewGeneration += 1
        let generation = edgeSnapPreviewGeneration
        if immediately {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            guard let self, let panel,
                  generation == self.edgeSnapPreviewGeneration else { return }
            panel.orderOut(nil)
        }
    }

    private func makeEdgeSnapPreviewPanel() -> NSPanel {
        let panel = OverlayPanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .transient, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = WindowEdgeSnapPreviewView(frame: .zero)
        return panel
    }

    private func canSetFrame(on window: AXUIElement) -> Bool {
        canSetPosition(on: window) && canSetSize(on: window)
    }

    private func canSetPosition(on window: AXUIElement) -> Bool {
        var positionSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window,
                                              kAXPositionAttribute as CFString,
                                              &positionSettable) == .success
            && positionSettable.boolValue
    }

    private func canSetSize(on window: AXUIElement) -> Bool {
        var sizeSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window,
                                              kAXSizeAttribute as CFString,
                                              &sizeSettable) == .success
            && sizeSettable.boolValue
    }

    private func canSetFullScreen(on window: AXUIElement) -> Bool {
        var fullScreenSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window,
                                              "AXFullScreen" as CFString,
                                              &fullScreenSettable) == .success
            && fullScreenSettable.boolValue
    }

    private func setPosition(_ point: CGPoint, on element: AXUIElement) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }

    private func setSize(_ size: CGSize, on element: AXUIElement) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success
    }

    private func frame(of element: AXUIElement) -> WindowLayoutFrame? {
        guard let origin = pointAttribute(element, kAXPositionAttribute as String),
              let size = sizeAttribute(element, kAXSizeAttribute as String),
              size.width > 0,
              size.height > 0
        else { return nil }
        return WindowLayoutFrame(origin: origin, size: size)
    }

    private func bestScreen(for frame: WindowLayoutFrame,
                            screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        let appKitFrame = appKitFrame(fromAX: frame)
        return screens.max { lhs, rhs in
            lhs.frame.intersection(appKitFrame).area < rhs.frame.intersection(appKitFrame).area
        } ?? NSScreen.main ?? screens.first
    }

    private func adjacentScreen(to current: NSScreen,
                                screens: [NSScreen],
                                movingForward: Bool) -> NSScreen? {
        guard let currentIndex = screens.firstIndex(where: { $0 === current }),
              let destinationIndex = WindowLayoutGeometry.adjacentDisplayIndex(
                currentIndex: currentIndex,
                frames: screens.map(\.frame),
                movingForward: movingForward
              )
        else { return nil }
        return screens[destinationIndex]
    }

    private func neighbourScreen(to current: NSScreen,
                                 screens: [NSScreen],
                                 direction: WindowLayoutGeometry.DisplayDirection) -> NSScreen? {
        guard let currentIndex = screens.firstIndex(where: { $0 === current }),
              let destinationIndex = WindowLayoutGeometry.neighbourIndex(
                currentIndex: currentIndex,
                frames: screens.map(\.frame),
                direction: direction
              )
        else { return nil }
        return screens[destinationIndex]
    }

    private func axFrame(fromAppKit rect: NSRect) -> WindowLayoutFrame {
        WindowLayoutFrame(origin: CGPoint(x: rect.minX, y: menuBarScreenTopY - rect.maxY),
                          size: rect.size)
    }

    private func appKitFrame(fromAX frame: WindowLayoutFrame) -> NSRect {
        NSRect(x: frame.origin.x,
               y: menuBarScreenTopY - frame.origin.y - frame.size.height,
               width: frame.size.width,
               height: frame.size.height)
    }

    private var menuBarScreenTopY: CGFloat {
        let menuBarScreen = NSScreen.screens.first {
            abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5
        }
        return (menuBarScreen ?? NSScreen.main ?? NSScreen.screens.first)?.frame.maxY ?? 0
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value
        else { return false }
        return (value as? Bool) ?? false
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func windowAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func windowsAttribute(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let values = value as? [AXUIElement]
        else { return nil }
        return values
    }

    private func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }
}

private struct WindowLayoutTarget {
    let window: AXUIElement
    let key: WindowLayoutWindowKey
    let frame: WindowLayoutFrame

    var windowID: CGWindowID { key.windowID }
}

/// Everything the deferred settle verification needs to finish judging a
/// discrete layout action after the grace period.
private struct SettleContext {
    let window: AXUIElement
    let windowID: CGWindowID
    let frame: WindowLayoutFrame
    let targetRect: NSRect
    let screenVisibleFrame: NSRect
    let action: WindowLayoutAction
    let original: WindowLayoutFrame?
    let previousAction: WindowLayoutAction?
    /// The side key recorded for the size cycle, nil when the placement
    /// cannot cycle and so needs no read-back once it settles.
    let cyclePress: WindowLayoutAction?
    let windowKey: WindowLayoutWindowKey
    /// Which published result this settle belongs to; a late failure only
    /// speaks when no newer action has published since.
    let resultGeneration: Int
}

private struct WindowLayoutPlacement {
    let frame: WindowLayoutFrame
    let rect: NSRect
}

private enum WindowEdgeSnapPointerInput {
    case down(location: CGPoint, flags: CGEventFlags)
    /// `time` is the event's own timestamp, in seconds of uptime.
    case dragged(location: CGPoint, time: TimeInterval)
    case up(location: CGPoint, time: TimeInterval)
}

private struct WindowEdgeSnapDrag {
    let window: AXUIElement
    let key: WindowLayoutWindowKey
    let initialFrame: CGRect
    let pointerStart: CGPoint
    let protectsSystemTopEdge: Bool
    let quartzScreenFrames: [CGRect]
    let enabledZones: Set<WindowEdgeSnapZone>
    var lastSampleAt: TimeInterval
    var mismatchCount: Int
    var isMoving: Bool
    var target: WindowEdgeSnapTarget?
}

/// A press the tap is holding while it is still undecided. It keeps the
/// original event so the click can be handed back untouched, with its
/// modifiers and its click count intact.
private final class WindowEdgeSnapPreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateAppearance()
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        updateAppearance()
        setAccessibilityElement(false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        guard let layer else { return }
        let accent = NSColor.controlAccentColor
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.backgroundColor = accent.withAlphaComponent(0.16).cgColor
        layer.borderColor = accent.withAlphaComponent(0.88).cgColor
        layer.borderWidth = 2
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
