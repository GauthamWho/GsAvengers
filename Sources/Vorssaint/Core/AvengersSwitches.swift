// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

/// Every on/off switch in the G’s Avengers window that belongs to this app
/// (the helpers' switches go over HelperWire instead). Each one reads and
/// writes the very preferences its feature runs on: the hub's availability
/// key plus the feature's own enable keys, so the window, the old Settings,
/// the menu panel and the running service always agree.
enum AvengersSwitch: String, CaseIterable {
    case quickRing, ringDoubleTap, ringControlClick, ringMiddleClick
    case switcher, closeQuits, snapping, cutPaste
    case screenshot, recorder
    case lidClosed, dimOnLidClose
    case clipboardHelper

    /// The hub feature this switch lives in; nil for the clipboard helper,
    /// which is its own app.
    var feature: AppFeature? {
        switch self {
        case .quickRing, .ringDoubleTap, .ringControlClick, .ringMiddleClick: return .quickRing
        case .switcher: return .switcher
        case .closeQuits: return .autoQuit
        case .snapping: return .windowLayout
        case .cutPaste: return .finderCutPaste
        case .screenshot: return .screenshot
        case .recorder: return .screenRecorder
        case .lidClosed, .dimOnLidClose: return .keepAwake
        case .clipboardHelper: return nil
        }
    }

    /// Keys whose value is the switch: on while any of them is on (and the
    /// feature is installed). Empty means installing the feature is the switch.
    var keys: [String] {
        switch self {
        case .quickRing: return AppFeature.quickRing.enabledKeys
        case .ringDoubleTap: return [DefaultsKey.quickRingControlDoubleTap]
        case .ringControlClick: return [DefaultsKey.quickRingControlClick]
        case .ringMiddleClick: return [DefaultsKey.quickRingMiddleClick]
        case .switcher: return [DefaultsKey.switcherEnabled]
        case .closeQuits: return [DefaultsKey.autoQuitEnabled]
        case .snapping: return [DefaultsKey.windowEdgeSnapEnabled, DefaultsKey.windowLayoutShortcutsEnabled]
        case .cutPaste: return [DefaultsKey.finderCutPasteEnabled]
        case .screenshot, .recorder: return []
        case .lidClosed: return [DefaultsKey.clamshellPreferred]
        case .dimOnLidClose: return [DefaultsKey.dimScreenOnLidClose]
        case .clipboardHelper: return [DefaultsKey.gsavClipboardHelperEnabled]
        }
    }

    /// What switching on sets (switching off clears every key above).
    private var onKeys: [String] {
        switch self {
        case .quickRing: return [DefaultsKey.quickRingControlDoubleTap]
        case .lidClosed: return [DefaultsKey.clamshellPreferred, DefaultsKey.keepAwakeAutoStart]
        default: return keys
        }
    }

    private var offKeys: [String] {
        self == .lidClosed ? onKeys : keys
    }

    /// Lid closed needs every one of its keys; the others need any one.
    func isOn(in defaults: UserDefaults) -> Bool {
        if let feature, !feature.isAvailable(in: defaults) { return false }
        if self == .lidClosed { return onKeys.allSatisfy(defaults.bool(forKey:)) }
        return keys.isEmpty || keys.contains(where: defaults.bool(forKey:))
    }

    /// Writes the switch's own preferences. Installing (and, for a feature
    /// with no enable key of its own, uninstalling) goes through
    /// FeatureRuntime.setAvailable like the Features hub, and the caller
    /// syncs the live service.
    func write(_ on: Bool, in defaults: UserDefaults) {
        for key in on ? onKeys : offKeys {
            defaults.set(on, forKey: key)
        }
    }
}
