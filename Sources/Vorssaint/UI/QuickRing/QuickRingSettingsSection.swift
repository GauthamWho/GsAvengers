// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import SwiftUI

/// The Quick Ring's section on the Quick tools page: one switch per way of
/// opening it, so each can be tried and the rest switched off.
struct QuickRingSettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.quickRingControlDoubleTap) private var controlDoubleTap = true
    @AppStorage(DefaultsKey.quickRingControlClick) private var controlClick = false
    @AppStorage(DefaultsKey.quickRingMiddleClick) private var middleClick = false

    private var strings: QuickRingStrings { FeatureStrings.quickRing(l10n.language) }

    var body: some View {
        Section {
            Text(strings.hubDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle(strings.controlDoubleTap, isOn: $controlDoubleTap)
                .onChange(of: controlDoubleTap) { _, _ in sync() }
            Toggle(strings.controlClick, isOn: $controlClick)
                .onChange(of: controlClick) { _, _ in sync() }
            Text(strings.controlClickCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle(strings.middleClick, isOn: $middleClick)
                .onChange(of: middleClick) { _, _ in sync() }
            Text(strings.middleClickCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(strings.triggersCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !permissions.accessibility {
                HStack {
                    Text(l10n.s.permissionMissing)
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button(l10n.s.permissionOpenSettings) { Permissions.shared.requestAccessibility() }
                        .controlSize(.small)
                }
            }
            Button {
                QuickRingService.shared.open()
            } label: {
                Label(strings.tryIt, systemImage: "circle.circle")
            }
        } header: {
            Text(strings.title)
        }
    }

    private func sync() {
        QuickRingService.shared.syncWithPreferences()
    }
}
