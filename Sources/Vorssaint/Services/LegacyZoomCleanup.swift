// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Smart Area Zoom was removed. It drove the system Zoom with the user's own
/// ⌥⌘ shortcuts and left a restore marker while the screen was zoomed by it.
/// If an older version ended with that marker still saved, this puts the
/// system Zoom back once at launch: back down to the ⌥⌘8 level saved in the
/// marker (so macOS keeps it) and then off. Nothing is ever written to the
/// Accessibility preferences; the marker is deleted either way.
enum LegacyZoomCleanup {
    static let markerKey = "smartZoomRestoreState"

    /// Keys only the removed feature used: its `smartZoom…` settings and its
    /// install switch. Cleared once by the launch migration (the marker is
    /// left to `runIfNeeded`); never backed up.
    static func isRemovedSetting(_ key: String) -> Bool {
        (key.hasPrefix("smartZoom") && key != markerKey) || key == "featureAvailable.smartZoom"
    }

    private static let domain = "com.apple.universalaccess" as CFString
    private static let stepRatio = 1.1
    private static let queue = DispatchQueue(label: "com.gauthamwho.gsmac.zoom-cleanup", qos: .userInitiated)

    /// Runs only when the marker exists.
    static func runIfNeeded(defaults: UserDefaults = .standard) {
        guard let marker = defaults.dictionary(forKey: markerKey) else { return }
        let wasZoomed = marker["wasZoomed"] as? Bool ?? false
        let desired = marker["desired"] as? Double
        queue.async {
            // The user had zoomed in themselves before the feature did:
            // their zoom stays as it is.
            if !wasZoomed, UAZoomEnabled(), canPress, !IsSecureEventInputEnabled() {
                if let desired, desired > 1.05 {
                    for _ in 0..<40 where UAZoomEnabled() && currentFactor() > desired * 1.05 {
                        press(kVK_ANSI_Minus)
                        usleep(120_000)
                    }
                }
                press(kVK_ANSI_8)
                wait(timeout: 1.0) { !UAZoomEnabled() }
            }
            DispatchQueue.main.async { defaults.removeObject(forKey: markerKey) }
        }
    }

    private static var canPress: Bool {
        guard AXIsProcessTrusted() else { return false }
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue("closeViewHotkeysEnabled" as CFString, domain) as? NSNumber)?
            .boolValue ?? false
    }

    private static func currentFactor() -> Double {
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue("closeViewZoomFactor" as CFString, domain) as? NSNumber)?
            .doubleValue ?? 1
    }

    private static func press(_ key: Int) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down)
            else { continue }
            event.flags = [.maskAlternate, .maskCommand]
            event.post(tap: .cghidEventTap)
        }
    }

    private static func wait(timeout: TimeInterval, _ condition: () -> Bool) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline, !condition() { usleep(30_000) }
    }
}
