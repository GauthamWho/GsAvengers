// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit

/// Bridges the feature catalog to the live services. Every binding is a
/// closure, so merely mentioning a feature never instantiates its service:
/// a service only comes to life when its binding runs, and syncAtLaunch skips
/// features that are off, so nothing loads for them. Main thread only.
final class FeatureRuntime: ObservableObject {
    static let shared = FeatureRuntime()

    /// Bumped on every switch change; views observing the runtime redraw.
    @Published private(set) var revision = 0

    private init() {}

    /// The one write path for a Home switch: preferences first, then the
    /// feature's service is told, then everyone watching redraws.
    func set(_ feature: AppFeature, _ on: Bool) {
        feature.write(on, in: .standard)
        Self.bindings[feature]?()
        revision += 1
        if on, feature.permissions.contains(.accessibility), !Permissions.shared.accessibility {
            Permissions.shared.requestAccessibility()
        }
    }

    func isAvailable(_ feature: AppFeature) -> Bool { feature.isOn }

    /// Launch path: only features that are on get their binding run.
    func syncAtLaunch() {
        for feature in AppFeature.allCases where feature.isOn {
            Self.bindings[feature]?()
        }
    }

    /// Re-syncs features after a permission change. Features that are off are
    /// skipped so their services never come to life.
    func sync(_ features: [AppFeature]) {
        for feature in features where feature.isOn || Self.isLoaded(feature) {
            Self.bindings[feature]?()
        }
    }

    /// Sharing and the clipboard keep their own engines; a sync turns those
    /// off again when the feature was switched off.
    private static func isLoaded(_ feature: AppFeature) -> Bool {
        switch feature {
        case .sharing: return SharingEngine.shared.isRunning
        case .clipboardHistory: return MainActor.assumeIsolated { ClipboardEngine.shared.isRunning }
        default: return false
        }
    }

    private static let bindings: [AppFeature: () -> Void] = [
        .switcher: {
            WindowUseTracker.shared.syncWithFeatures()
            AppSwitcher.shared.syncWithPreferences()
        },
        .dockPreview: { DockPreviewService.shared.syncWithPreferences() },
        .windowLayout: {
            WindowUseTracker.shared.syncWithFeatures()
            WindowLayoutService.shared.syncWithPreferences()
        },
        .autoQuit: { AutoQuitService.shared.syncWithPreferences() },
        .finderCutPaste: { FinderCutPaste.shared.syncWithPreferences() },
        .sharing: { SharingEngine.shared.syncWithPreferences() },
        .clipboardHistory: { MainActor.assumeIsolated { ClipboardEngine.shared.syncWithPreferences() } },
        .urlCleaner: { URLCleanerService.shared.syncWithPreferences() },
        .keepAwake: {
            KeepAwakeManager.shared.syncWithFeatures()
            HotkeyManager.shared.syncWithPreferences()
        },
        .screenOCR: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenTextService.shared.syncWithPreferences()
        },
        .screenshot: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenshotService.shared.syncWithPreferences()
            RecentCaptureService.shared.syncWithPreferences()
        },
        .screenRecorder: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenRecorderService.shared.syncWithPreferences()
            RecentCaptureService.shared.syncWithPreferences()
        },
        .quickRing: { QuickRingService.shared.syncWithPreferences() },
    ]
}
