// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import ApplicationServices
import AVFoundation
import Combine
import CoreGraphics

/// The permissions the thirteen features use. Nothing polls: Accessibility
/// is re-read when the system announces a change to its trust list (and when
/// the app becomes active), Screen Recording and the microphone when the app
/// becomes active or a feature asks.
final class Permissions: ObservableObject {
    static let shared = Permissions()

    @Published private(set) var accessibility = false
    @Published private(set) var screenRecording = false
    @Published private(set) var microphone: MicrophonePermissionState = .unknown

    enum MicrophonePermissionState {
        case granted, denied, undetermined, unknown
    }

    private var observers: [NSObjectProtocol] = []

    private init() {
        refresh()
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        // Posted by the system whenever an app is added to or removed from
        // the Accessibility list. The trust value lands a moment later.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.refresh() }
        })
    }

    func refresh() {
        let ax = AXIsProcessTrusted()
        let sr = CGPreflightScreenCaptureAccess()
        if accessibility != ax { accessibility = ax }
        if screenRecording != sr { screenRecording = sr }
        let mic: MicrophonePermissionState
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: mic = .granted
        case .denied, .restricted: mic = .denied
        case .notDetermined: mic = .undetermined
        @unknown default: mic = .unknown
        }
        if microphone != mic { microphone = mic }
    }

    /// Shows the system Accessibility prompt (once per TCC reset).
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    /// Shows the system Screen Recording prompt (once per TCC reset).
    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        refresh()
    }

    func requestMicrophone(completion: ((Bool) -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphone = granted ? .granted : .denied
                completion?(granted)
            }
        }
    }

    func openAccessibilitySettings() { open(pane: "Privacy_Accessibility") }
    func openScreenRecordingSettings() { open(pane: "Privacy_ScreenCapture") }
    func openMicrophoneSettings() { open(pane: "Privacy_Microphone") }
    func openAutomationSettings() { open(pane: "Privacy_Automation") }
    func openAudioCaptureSettings() { open(pane: "Privacy_AudioCapture") }

    private func open(pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Automation (Apple Events)

    enum AutomationTarget: String, CaseIterable {
        case finder = "com.apple.finder"
    }

    enum AutomationStatus {
        case granted, denied, undetermined, notDeterminable
    }

    /// Never prompts (askUserIfNeeded false). A target that is not running
    /// cannot be checked and reads as notDeterminable. Call off the main
    /// thread; the check can block briefly.
    static func automationStatus(for target: AutomationTarget) -> AutomationStatus {
        var descriptor = AEAddressDesc()
        let bundleID = target.rawValue
        let created = bundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, bundleID.utf8.count, &descriptor)
        }
        guard created == noErr else { return .notDeterminable }
        defer { AEDisposeDesc(&descriptor) }
        switch AEDeterminePermissionToAutomateTarget(&descriptor, typeWildCard, typeWildCard, false) {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .undetermined
        default: return .notDeterminable
        }
    }
}
