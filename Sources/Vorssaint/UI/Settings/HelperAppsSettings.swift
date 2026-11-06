// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import SwiftUI

/// Settings page for the embedded clipboard helper (fn V / fn E). Its own
/// settings window stays the place to change shortcuts and history options.
struct HelperClipboardSettings: View {
    @ObservedObject private var l10n = L10n.shared
    private var text: HelperAppStrings { FeatureStrings.helperApps(l10n.language) }

    var body: some View {
        Form {
            Section(text.clipboardTitle) {
                Text(text.clipboardCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(text.clipboardSettings) { HelperBridge.shared.openClipboardSettings() }
                        .buttonStyle(.borderedProminent)
                    Button(text.openClipboard) { HelperBridge.shared.openClipboard() }
                    Button(text.openEmoji) { HelperBridge.shared.openEmoji() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Settings page for the embedded Windows sharing helper: live status and
/// pause here; pairing, layout side and keyboard rules in its own window.
struct WindowsSharingSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var bridge = HelperBridge.shared
    private var text: HelperAppStrings { FeatureStrings.helperApps(l10n.language) }

    var body: some View {
        Form {
            Section(text.sharingTitle) {
                Label(bridge.sharingStatusText(text),
                      systemImage: bridge.sharing?.connected == true ? "checkmark.circle.fill" : "display.2")
                Toggle(text.pauseSharing, isOn: Binding(
                    get: { bridge.sharing?.paused ?? false },
                    set: { bridge.setSharingPaused($0) }))
                    .disabled(bridge.sharing == nil)
                Text(text.sharingCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(text.openSharingWindow) { bridge.openSharingWindow() }
                        .buttonStyle(.borderedProminent)
                    Button(text.pairShowCode) { bridge.openSharingWindow() }
                    Button(text.keyboardRules) { bridge.openSharingWindow() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { bridge.refresh() }
    }
}
