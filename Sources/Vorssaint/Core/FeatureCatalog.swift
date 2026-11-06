// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

/// The thirteen features of G’s Avengers. The raw value is the stable
/// identity persisted inside the availability key, so cases are never renamed.
///
/// Each feature has ONE on/off switch on the Home page. The switch is the
/// feature's availability key together with its own enable keys, so the
/// Home page, the feature's own page and the running service always read the
/// same preferences. A feature that is off never starts its service.
enum AppFeature: String, CaseIterable {
    case switcher, autoQuit, windowLayout, dockPreview, finderCutPaste
    case sharing, clipboardHistory, urlCleaner
    case screenshot, screenRecorder, screenOCR, quickRing
    case keepAwake
}

/// Home page sections, in display order.
enum FeatureGroup: String, CaseIterable {
    case windowsHabits, sharingClipboard, capture, power
}

/// System permissions the features use.
enum AppPermission: String, CaseIterable {
    case accessibility, screenRecording, automationFinder, audioCapture, microphone
}

extension AppFeature {
    var group: FeatureGroup {
        switch self {
        case .switcher, .autoQuit, .windowLayout, .dockPreview, .finderCutPaste: return .windowsHabits
        case .sharing, .clipboardHistory, .urlCleaner: return .sharingClipboard
        case .screenshot, .screenRecorder, .screenOCR, .quickRing: return .capture
        case .keepAwake: return .power
        }
    }

    var symbolName: String {
        switch self {
        case .switcher: return "rectangle.on.rectangle"
        case .autoQuit: return "xmark.app"
        case .windowLayout: return "rectangle.split.2x1"
        case .dockPreview: return "dock.rectangle"
        case .finderCutPaste: return "scissors"
        case .sharing: return "pc"
        case .clipboardHistory: return "doc.on.clipboard"
        case .urlCleaner: return "link"
        case .screenshot: return "camera.viewfinder"
        case .screenRecorder: return "record.circle"
        case .screenOCR: return "text.viewfinder"
        case .quickRing: return "circle.circle"
        case .keepAwake: return "moon.zzz"
        }
    }

    var availabilityKey: String { DefaultsKey.featureAvailable(rawValue) }

    /// The feature's own enable keys. On means available AND (no keys, or
    /// any key on). Switching on sets every key; off clears every key.
    var enabledKeys: [String] {
        switch self {
        case .switcher: return [DefaultsKey.switcherEnabled]
        case .autoQuit: return [DefaultsKey.autoQuitEnabled]
        case .windowLayout: return [DefaultsKey.windowEdgeSnapEnabled, DefaultsKey.windowLayoutShortcutsEnabled]
        case .dockPreview: return [DefaultsKey.dockPreviewEnabled]
        case .finderCutPaste: return [DefaultsKey.finderCutPasteEnabled]
        case .sharing: return [DefaultsKey.sharingEnabled]
        case .clipboardHistory: return [DefaultsKey.gsavClipboardHelperEnabled]
        case .urlCleaner: return [DefaultsKey.urlCleanerEnabled]
        case .quickRing: return [DefaultsKey.quickRingControlDoubleTap]
        case .screenshot, .screenRecorder, .screenOCR, .keepAwake: return []
        }
    }

    var isAvailable: Bool { isAvailable(in: .standard) }

    func isAvailable(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: availabilityKey)
    }

    /// The Home switch's value, read from the very preferences the feature runs on.
    func isOn(in defaults: UserDefaults) -> Bool {
        guard isAvailable(in: defaults) else { return false }
        let keys = enabledKeys
        return keys.isEmpty || keys.contains(where: defaults.bool(forKey:))
    }

    var isOn: Bool { isOn(in: .standard) }

    /// Writes the Home switch: availability plus every enable key.
    func write(_ on: Bool, in defaults: UserDefaults) {
        defaults.set(on, forKey: availabilityKey)
        for key in enabledKeys { defaults.set(on, forKey: key) }
    }

    /// Which permissions the feature can use.
    var permissions: [AppPermission] {
        switch self {
        case .switcher, .dockPreview: return [.accessibility, .screenRecording]
        case .autoQuit, .windowLayout, .quickRing, .sharing, .clipboardHistory, .keepAwake: return [.accessibility]
        case .finderCutPaste: return [.accessibility, .automationFinder]
        case .screenshot, .screenOCR: return [.screenRecording]
        case .screenRecorder: return [.screenRecording, .accessibility, .audioCapture, .microphone]
        case .urlCleaner: return []
        }
    }

    static func features(in group: FeatureGroup) -> [AppFeature] {
        allCases.filter { $0.group == group }
    }

    /// Everything is on for a new install: the thirteen are the whole app.
    static var availabilityDefaults: [String: Any] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.availabilityKey, true) })
    }

    /// Features that are on and using `permission` right now.
    static func activeFeatures(using permission: AppPermission,
                               defaults: UserDefaults = .standard) -> [AppFeature] {
        allCases.filter { feature in
            guard feature.permissions.contains(permission), feature.isOn(in: defaults) else { return false }
            switch (feature, permission) {
            case (.switcher, .screenRecording):
                return !defaults.bool(forKey: DefaultsKey.switcherSimpleMode)
            case (.screenRecorder, .audioCapture):
                return defaults.bool(forKey: DefaultsKey.recorderSystemAudio)
            case (.screenRecorder, .microphone):
                return defaults.bool(forKey: DefaultsKey.recorderMicrophone)
            default:
                return true
            }
        }
    }
}

extension AppPermission {
    var symbolName: String {
        switch self {
        case .accessibility: return "accessibility"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .automationFinder: return "gearshape.2"
        case .audioCapture: return "waveform"
        case .microphone: return "mic"
        }
    }
}
