// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import Combine
import SwiftUI

/// The window's one source of truth. Every switch reads the very
/// preferences its feature runs on and writes through FeatureRuntime, which
/// then tells the service. Sharing and the clipboard run in this process,
/// so their settings are read and written directly, with no messages.
/// Only alive while the window is open (it is released on close).
final class AvengersModel: ObservableObject {
    private var watchers: [AnyCancellable] = []
    private var redrawQueued = false

    init() {
        watchers.append(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in self?.queueRedraw() })
        watchers.append(FeatureRuntime.shared.objectWillChange.sink { [weak self] _ in self?.queueRedraw() })
        watchers.append(KeepAwakeManager.shared.objectWillChange.sink { [weak self] _ in self?.queueRedraw() })
        watchers.append(SharingEngine.shared.state.objectWillChange.sink { [weak self] _ in self?.queueRedraw() })
        watchers.append(ClipboardHotKeys.shared.objectWillChange.sink { [weak self] _ in self?.queueRedraw() })
    }

    private func queueRedraw() {
        guard !redrawQueued else { return }
        redrawQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.redrawQueued = false
            self?.objectWillChange.send()
        }
    }

    // MARK: - Feature switches

    func isOn(_ feature: AppFeature) -> Bool {
        // Keep awake's switch is the session itself: on means the Mac is held awake now.
        if feature == .keepAwake { return KeepAwakeManager.shared.isActive }
        return feature.isOn
    }

    func set(_ feature: AppFeature, _ on: Bool) {
        if feature == .keepAwake {
            if on != KeepAwakeManager.shared.isActive { KeepAwakeManager.shared.toggle() }
        } else {
            FeatureRuntime.shared.set(feature, on)
        }
        objectWillChange.send()
    }

    func binding(_ feature: AppFeature) -> Binding<Bool> {
        Binding(get: { self.isOn(feature) }, set: { self.set(feature, $0) })
    }

    // MARK: - Keep awake options

    var lidClosed: Binding<Bool> {
        Binding(get: { KeepAwakeManager.shared.clamshellPreferred },
                set: { on in
                    let keepAwake = KeepAwakeManager.shared
                    keepAwake.clamshellPreferred = on
                    UserDefaults.standard.set(on, forKey: DefaultsKey.keepAwakeAutoStart)
                    if on { keepAwake.activateOnLaunchIfNeeded() }
                    self.objectWillChange.send()
                })
    }

    var dimOnLidClose: Binding<Bool> {
        Binding(get: { KeepAwakeManager.shared.dimScreenOnLidClose },
                set: { KeepAwakeManager.shared.dimScreenOnLidClose = $0; self.objectWillChange.send() })
    }

    // MARK: - Sharing (in process)

    var sharing: SharingSnapshot { SharingEngine.shared.snapshot }

    func rule(_ id: String) -> Binding<Bool> {
        Binding(get: { self.sharing.rules.first { $0.id == id }?.on ?? false },
                set: { SharingEngine.shared.setRule(id, $0); self.objectWillChange.send() })
    }

    // MARK: - Clipboard (in process)

    var pasteAfterPick: Binding<Bool> {
        Binding(get: { MainActor.assumeIsolated { Paster.enabled } },
                set: { on in MainActor.assumeIsolated { Paster.enabled = on }; self.objectWillChange.send() })
    }

    var smartCleanup: Binding<Bool> {
        Binding(get: { MainActor.assumeIsolated { ClipStore.smartCleanup } },
                set: { on in MainActor.assumeIsolated { ClipStore.smartCleanup = on }; self.objectWillChange.send() })
    }

    var maxItems: Int { UserDefaults.standard.integer(forKey: "maxItems") }

    func setMaxItems(_ count: Int) {
        if let model = MainActor.assumeIsolated({ ClipboardEngine.shared.model }) {
            MainActor.assumeIsolated { model.store.maxItems = count }
        } else {
            UserDefaults.standard.set(count, forKey: "maxItems")
        }
        objectWillChange.send()
    }

    // MARK: - Global shortcuts (switcher, capture, keep awake)

    func shortcut(_ key: String, fallback: GlobalShortcut) -> GlobalShortcut {
        GlobalShortcut.saved(for: key, fallback: fallback)
    }

    func setShortcut(_ shortcut: GlobalShortcut, for key: String) {
        UserDefaults.standard.set(shortcut.storageValue, forKey: key)
        FeatureRuntime.shared.sync([.switcher, .screenshot, .screenRecorder, .screenOCR, .keepAwake])
        objectWillChange.send()
    }
}
