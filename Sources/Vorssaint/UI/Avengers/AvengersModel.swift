// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import Combine
import SwiftUI

/// The G’s Avengers window's one source of truth for this app's switches.
/// Reads straight from the preferences the features run on (AvengersSwitch)
/// and writes through the same path as the Features hub and the old Settings:
/// availability via FeatureRuntime, the enable keys, then the feature's sync.
/// Any preference change made elsewhere redraws the window.
final class AvengersModel: ObservableObject {
    static let shared = AvengersModel()

    private var watchers: [AnyCancellable] = []
    private var redrawQueued = false

    private init() {
        watchers.append(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in self?.queueRedraw() })
        watchers.append(FeatureRuntime.shared.objectWillChange.sink { [weak self] _ in self?.queueRedraw() })
        watchers.append(KeepAwakeManager.shared.objectWillChange.sink { [weak self] _ in self?.queueRedraw() })
    }

    private func queueRedraw() {
        guard !redrawQueued else { return }
        redrawQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.redrawQueued = false
            self?.objectWillChange.send()
        }
    }

    func isOn(_ item: AvengersSwitch) -> Bool {
        let saved = item.isOn(in: .standard)
        // Closed-lid mode is only real while a keep-awake session holds it.
        if item == .lidClosed { return saved && KeepAwakeManager.shared.isActive }
        return saved
    }

    func binding(_ item: AvengersSwitch) -> Binding<Bool> {
        Binding(get: { self.isOn(item) }, set: { self.set(item, $0) })
    }

    func set(_ item: AvengersSwitch, _ on: Bool) {
        if item == .clipboardHelper {
            HelperBridge.shared.setClipboardEnabled(on)
            objectWillChange.send()
            return
        }
        guard let feature = item.feature else { return }
        let runtime = FeatureRuntime.shared
        if on, !feature.isAvailable { runtime.setAvailable([feature], true) }
        if !on, item.keys.isEmpty { runtime.setAvailable([feature], false) }
        item.write(on, in: .standard)
        let keepAwake = KeepAwakeManager.shared
        switch item {
        case .lidClosed:
            keepAwake.clamshellPreferred = on
            if on {
                keepAwake.activateOnLaunchIfNeeded()
            } else if keepAwake.isActive {
                keepAwake.deactivate(reason: .manual)
            }
        case .dimOnLidClose:
            keepAwake.dimScreenOnLidClose = on
        default:
            break
        }
        runtime.sync([feature])
        if on, feature.permissions.contains(.accessibility), !Permissions.shared.accessibility {
            Permissions.shared.requestAccessibility()
        }
        objectWillChange.send()
    }

    /// The More page: every other feature, switched on and off exactly like
    /// the Features hub (install and uninstall, settings kept).
    static let pageFeatures: Set<AppFeature> = Set(AvengersSwitch.allCases.compactMap(\.feature))

    var moreFeatures: [AppFeature] {
        AppFeature.allCases.filter { !Self.pageFeatures.contains($0) && ($0.isHardwareSupported || $0.isAvailable) }
    }

    func featureBinding(_ feature: AppFeature) -> Binding<Bool> {
        Binding(get: { feature.isAvailable }, set: { on in
            FeatureRuntime.shared.setAvailable([feature], on)
            self.objectWillChange.send()
        })
    }
}
