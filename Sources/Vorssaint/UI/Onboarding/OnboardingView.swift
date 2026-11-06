// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// First-run experience, also reachable later through Settings › About.
/// The person chooses what they want first; only then does the app explain and
/// request the permissions that choice actually needs.
enum OnboardingMode {
    case full

    func title(_ strings: Strings) -> String {
        strings.obStepWelcomeTitle
    }
}

struct OnboardingView: View {
    var mode: OnboardingMode = .full
    var onFinish: () -> Void

    @ObservedObject private var l10n = L10n.shared
    /// G’s Mac: one calm screen. The Windows essentials start on; anything
    /// switched off here simply stays off. Permissions are asked by each
    /// feature the first time it is used, never as a wall up front.
    @State private var chosen: Set<GsMacEssential>

    init(mode: OnboardingMode = .full, onFinish: @escaping () -> Void) {
        self.mode = mode
        self.onFinish = onFinish
        let defaults = UserDefaults.standard
        let rerun = defaults.bool(forKey: DefaultsKey.hasOnboarded)
        _chosen = State(initialValue: rerun
            ? Set(GsMacEssential.allCases.filter { $0.feature.isAvailable })
            : Set(GsMacEssential.allCases))
    }

    private var s: GsMacSetupStrings { FeatureStrings.gsMacSetup(l10n.language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 2) {
                ForEach(GsMacEssential.allCases) { row($0) }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            Divider()
            footer
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { PermissionGuideOverlay.suppressed = true }
        .onDisappear { PermissionGuideOverlay.suppressed = false }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.title)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(s.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Picker("", selection: $l10n.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityLabel(l10n.s.obLanguageLabel)
        }
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 12)
    }

    private func row(_ item: GsMacEssential) -> some View {
        let on = Binding(get: { chosen.contains(item) },
                         set: { if $0 { chosen.insert(item) } else { chosen.remove(item) } })
        return Toggle(isOn: on) {
            HStack(spacing: 12) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(item.title(s))
                    .font(.system(size: 13))
                Spacer(minLength: 8)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 8)
        .frame(height: 34)
    }

    private var footer: some View {
        HStack {
            Text(s.changeLater)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button(s.start) { finish() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func finish() {
        let defaults = UserDefaults.standard
        let rerun = defaults.bool(forKey: DefaultsKey.hasOnboarded)
        let rows = Set(GsMacEssential.allCases.map(\.feature))
        let picked = Set(chosen.map(\.feature))
        // A re-run changes only the rows on this screen; everything else
        // installed stays exactly as it was. A first run starts lean.
        let keep = rerun ? Set(AppFeature.allCases.filter(\.isAvailable)).subtracting(rows) : []
        let features = keep.union(picked).union(rerun ? [] : GsMacEssential.silentFeatures)
        let newlyOn = features.filter { !$0.isAvailable || !rerun }
        // A first run already lists these as installed, so install alone
        // would leave their switches off: engage each one, skipping any
        // setting the person has already saved.
        let saved = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        for feature in newlyOn { feature.enableOnFirstInstall(in: defaults, savedValues: saved) }
        FeatureRuntime.shared.replaceAvailable(with: features)
        // Closed-lid mode goes through its manager, so macOS asks for the
        // password once, right now, while this screen explains why.
        if chosen.contains(.lidClosed), !rerun || !GsMacEssential.lidClosed.feature.isAvailable {
            defaults.set(true, forKey: DefaultsKey.keepAwakeAutoStart)
            KeepAwakeManager.shared.clamshellPreferred = true
            KeepAwakeManager.shared.activateOnLaunchIfNeeded()
        }
        if picked.contains(where: { $0.permissions.contains(.accessibility) }),
           !Permissions.shared.accessibility {
            Permissions.shared.requestAccessibility()
        }
        onFinish()
    }
}
