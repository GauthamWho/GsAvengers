// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import SwiftUI

/// One page of the window. Every switch is bound to the real preference
/// through AvengersModel; sharing and the clipboard run in this process.
struct AvengersPageView: View {
    let page: AvengersPage
    @ObservedObject var router: AvengersRouter
    @ObservedObject var model: AvengersModel
    @ObservedObject private var l10n = L10n.shared
    @State private var launchAtLogin = false

    private var text: AvengersStrings { FeatureStrings.avengers(l10n.language) }
    private var setup: GsMacSetupStrings { FeatureStrings.gsMacSetup(l10n.language) }
    private var home: HomeStrings { FeatureStrings.home(l10n.language) }
    private var ring: QuickRingStrings { FeatureStrings.quickRing(l10n.language) }
    private var share: SharingSnapshot { model.sharing }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch page {
            case .home: homePage
            case .sharing: sharingPage
            case .keyboard: keyboardPage
            case .clipboard: clipboardPage
            case .capture: capturePage
            case .keepAwake: keepAwakePage
            }
        }
    }

    // MARK: - Shared pieces

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(Frost.title(22)).foregroundColor(Frost.text)
            Text(subtitle).font(.system(size: 12.5)).foregroundColor(Frost.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    private var greeting: String {
        // Offscreen snapshots (README pictures) never show the real user's name.
        let first = AvengersDemo.names ? "Alex"
            : NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
        let hour = Calendar.current.component(.hour, from: Date())
        let format = hour < 12 ? text.morning : (hour < 18 ? text.afternoon : text.evening)
        return String(format: format, first)
    }

    /// The name each feature has on the Home page.
    func title(_ feature: AppFeature) -> String {
        switch feature {
        case .switcher: return setup.switcher
        case .autoQuit: return setup.closeQuits
        case .windowLayout: return setup.snapping
        case .dockPreview: return home.dockPreview
        case .finderCutPaste: return setup.cutPaste
        case .sharing: return home.sharing
        case .clipboardHistory: return setup.clipboard
        case .urlCleaner: return home.urlCleaner
        case .screenshot: return setup.screenshot
        case .screenRecorder: return setup.recorder
        case .screenOCR: return home.screenOCR
        case .quickRing: return "\(setup.quickRing) (⌃⌃)"
        case .keepAwake: return home.keepAwake
        }
    }

    private func groupTitle(_ group: FeatureGroup) -> String {
        switch group {
        case .windowsHabits: return home.groupWindows
        case .sharingClipboard: return home.groupSharing
        case .capture: return home.groupCapture
        case .power: return home.groupPower
        }
    }

    private func groupIcon(_ group: FeatureGroup) -> String {
        switch group {
        case .windowsHabits: return "macwindow.on.rectangle"
        case .sharingClipboard: return "pc"
        case .capture: return "camera.viewfinder"
        case .power: return "bolt"
        }
    }

    /// The page with a feature's few settings, when it has any.
    private func optionsPage(_ feature: AppFeature) -> AvengersPage? {
        switch feature {
        case .sharing: return .sharing
        case .clipboardHistory: return .clipboard
        case .screenshot, .screenRecorder, .screenOCR, .switcher: return .capture
        case .keepAwake: return .keepAwake
        default: return nil
        }
    }

    private func featureRow(_ feature: AppFeature) -> some View {
        HStack(spacing: 6) {
            FrostToggleRow(title: title(feature), icon: feature.symbolName, isOn: model.binding(feature))
            if let page = optionsPage(feature) {
                Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { router.page = page } } label: {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Frost.muted)
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(home.options)
            } else {
                // Same width as the chevron, so every switch lines up.
                Color.clear.frame(width: 22, height: 22)
            }
        }
    }

    private func sideWord(_ side: Int) -> String {
        [text.sideLeft, text.sideRight, text.sideTop, text.sideBottom][min(max(side, 0), 3)]
    }

    private var laptopLine: String {
        if !share.peer.isEmpty { return "\(share.peer) · \(sideWord(share.side))" }
        if !share.lastSeen.isEmpty { return String(format: text.seenFormat, share.lastSeen) }
        return text.noLaptop
    }

    private var pill: FrostStatusPill {
        guard share.running else { return FrostStatusPill(text: text.pillOff, good: false, quiet: true) }
        if share.pairCode != nil { return FrostStatusPill(text: text.pillPairing, good: false) }
        if share.connected { return FrostStatusPill(text: share.active ? text.pillOnMac : text.pillConnected, good: true) }
        return FrostStatusPill(text: text.pillSearching, good: false)
    }

    private var laptopCard: some View {
        FrostCard(title: text.windowsLaptop) {
            HStack(spacing: 10) {
                Text(laptopLine).font(.system(size: 13)).foregroundColor(Frost.text).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                pill
            }
            .padding(.vertical, 3)
            FrostHairline()
            FrostToggleRow(title: text.shareKeyboardMouse, isOn: model.binding(.sharing))
        }
    }

    // MARK: - Home: all thirteen switches

    private var homePage: some View {
        Group {
            header(greeting, text.homeSubtitle)
            ForEach(FeatureGroup.allCases, id: \.self) { group in
                FrostCard(title: groupTitle(group), icon: groupIcon(group)) {
                    let features = AppFeature.features(in: group)
                    ForEach(features, id: \.self) { feature in
                        if feature != features.first { FrostHairline() }
                        featureRow(feature)
                    }
                }
            }
            appCard
        }
    }

    private var appCard: some View {
        FrostCard(title: text.appLabel, icon: "gearshape") {
            HStack {
                Text(l10n.s.languageLabel).font(.system(size: 13)).foregroundColor(Frost.text)
                Spacer(minLength: 8)
                Menu(l10n.language.displayName) {
                    ForEach(AppLanguage.allCases) { language in
                        Button(language.displayName) { l10n.language = language }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.vertical, 3)
            FrostHairline()
            FrostToggleRow(title: l10n.s.launchAtLogin, isOn: Binding(get: { launchAtLogin }, set: { on in
                launchAtLogin = on
                LaunchAtLogin.setEnabled(on) { registration, _ in launchAtLogin = registration == .enabled }
            }))
            FrostHairline()
            HStack(spacing: 8) {
                Button(l10n.s.menuAbout) { showAbout() }
                    .buttonStyle(FrostButtonStyle(prominent: false, compact: true))
                Spacer(minLength: 0)
                Button(l10n.s.menuQuit) { NSApp.terminate(nil) }
                    .buttonStyle(FrostButtonStyle(prominent: false, compact: true))
            }
            .padding(.top, 4)
        }
        .onAppear { LaunchAtLogin.refresh { launchAtLogin = $0 == .enabled } }
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(string: l10n.s.aboutDescription,
                                         attributes: [.font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    // MARK: - Windows sharing

    private var sharingPage: some View {
        Group {
            header(text.sharing, text.sharingSubtitle)
            if share.running, !share.trusted {
                FrostCard(title: home.sharing, icon: "hand.raised.fill") {
                    Text(text.accessNeeded).font(.system(size: 13)).foregroundColor(Frost.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(l10n.s.permissionRequest) { Permissions.shared.requestAccessibility() }
                        .buttonStyle(FrostButtonStyle(compact: true))
                }
            }
            laptopCard
            if share.running { pairingCard }
            FrostCard(title: text.layoutLabel, icon: "rectangle.on.rectangle") {
                Text(share.peerId.isEmpty ? text.layoutEmpty : text.layoutHint)
                    .font(.system(size: 12.5)).foregroundColor(Frost.muted)
                AvengersArrangeStage(text: text, model: model)
            }
            FrostCard(title: text.pointerLabel, icon: "cursorarrow.motionlines") {
                FrostSliderRow(title: text.pointerSpeed, value: Binding(
                    get: { share.mouseSpeed }, set: { SharingEngine.shared.setMouseSpeed($0) }), range: 0.4...2.5)
                FrostSliderRow(title: text.scrollSpeed, value: Binding(
                    get: { share.scrollSpeed }, set: { SharingEngine.shared.setScrollSpeed($0) }), range: 0.2...3)
                FrostHairline()
                FrostToggleRow(title: text.reverseScroll, isOn: Binding(
                    get: { share.reverseScroll }, set: { SharingEngine.shared.setReverseScroll($0) }))
                FrostHairline()
                FrostToggleRow(title: text.shareClipboard, isOn: Binding(
                    get: { share.shareClipboard }, set: { SharingEngine.shared.setShareClipboard($0) }))
            }
            Text(text.homeKeyHint).font(.system(size: 11)).foregroundColor(Frost.muted).padding(.horizontal, 4)
        }
    }

    private var pairingCard: some View {
        FrostCard(title: text.pairingLabel, icon: "link") {
            if let code = share.pairCode {
                Text(text.pairCheck).font(.system(size: 13)).foregroundColor(Frost.text)
                HStack(spacing: 7) {
                    ForEach(Array(code.enumerated()), id: \.offset) { index, digit in
                        FrostPairDigit(digit: digit).padding(.leading, index == 3 ? 8 : 0)
                    }
                }
                if share.pairConfirmed {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(text.pairWaiting).font(.system(size: 12)).foregroundColor(Frost.muted)
                    }
                } else {
                    Button(text.pairButton) { SharingEngine.shared.confirmPair() }
                        .buttonStyle(FrostButtonStyle(compact: true))
                }
            } else if share.paired, !share.peer.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(Frost.ok)
                    Text(String(format: text.pairedWithFormat, share.peer)).font(.system(size: 13)).foregroundColor(Frost.text)
                }
            } else {
                FrostStep(number: 1, text: text.notPaired, done: share.paired)
            }
        }
    }

    // MARK: - Keyboard rules (sharing)

    private var keyboardPage: some View {
        Group {
            header(text.keyboard, text.keyboardSubtitle)
            let rules = share.rules
            let groups = rules.reduce(into: [String]()) { if !$0.contains($1.group) { $0.append($1.group) } }
            FrostCard(title: text.keyboard, icon: "keyboard") {
                ForEach(groups, id: \.self) { group in
                    AvengersKeyGroup(group: group, rules: rules.filter { $0.group == group },
                                     startOpen: group == groups.first, countFormat: text.countFormat)
                }
            }
        }
    }

    // MARK: - Clipboard

    private var clipboardPage: some View {
        Group {
            header(setup.clipboard, text.clipboardSubtitle)
            FrostCard(title: setup.clipboard, icon: "doc.on.clipboard") {
                FrostToggleRow(title: setup.clipboard, isOn: model.binding(.clipboardHistory))
            }
            FrostCard(title: text.shortcutsLabel, icon: "command") {
                HStack {
                    Text(text.openClipboardRow).font(.system(size: 13)).foregroundColor(Frost.text)
                    Spacer(minLength: 8)
                    ShortcutRecorder(slot: .clipboard)
                }
                FrostHairline()
                HStack {
                    Text(text.openEmojiRow).font(.system(size: 13)).foregroundColor(Frost.text)
                    Spacer(minLength: 8)
                    ShortcutRecorder(slot: .emoji)
                }
            }
            FrostCard(title: text.historyLabel, icon: "clock.arrow.circlepath") {
                FrostToggleRow(title: text.pasteAfterPick, isOn: model.pasteAfterPick)
                FrostHairline()
                FrostToggleRow(title: text.smartCleanup, isOn: model.smartCleanup)
                FrostHairline()
                HStack(spacing: 6) {
                    Text(text.keepUpTo).font(.system(size: 13)).foregroundColor(Frost.text)
                    Spacer(minLength: 8)
                    ForEach([200, 500, 1000, 0], id: \.self) { count in
                        FrostChip(label: count == 0 ? text.noLimit : "\(count)", on: model.maxItems == count) {
                            model.setMaxItems(count)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: - Capture and switcher shortcuts

    private func shortcutRow(_ title: String, key: String, fallback: GlobalShortcut) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundColor(Frost.text)
            Spacer(minLength: 8)
            ShortcutRecorderButton(shortcut: model.shortcut(key, fallback: fallback), isEnabled: true,
                                   waitingTitle: home.pressKeys, invalidAction: {},
                                   captureAction: { model.setShortcut($0, for: key) })
                .frame(width: 150)
        }
        .padding(.vertical, 2)
    }

    private var capturePage: some View {
        Group {
            header(text.capture, text.captureSubtitle)
            FrostCard(title: text.capture, icon: "camera.viewfinder") {
                ForEach([AppFeature.screenshot, .screenRecorder, .screenOCR, .quickRing], id: \.self) { feature in
                    if feature != .screenshot { FrostHairline() }
                    FrostToggleRow(title: title(feature), icon: feature.symbolName, isOn: model.binding(feature))
                }
            }
            FrostCard(title: text.shortcutsLabel, icon: "command") {
                shortcutRow(setup.screenshot, key: DefaultsKey.screenshotShortcut, fallback: .screenshotDefault)
                FrostHairline()
                shortcutRow(setup.recorder, key: DefaultsKey.recorderShortcut, fallback: .screenRecorderDefault)
                FrostHairline()
                shortcutRow(home.screenOCR, key: DefaultsKey.screenOCRShortcut, fallback: .screenOCRDefault)
                FrostHairline()
                shortcutRow(setup.switcher, key: DefaultsKey.switcherShortcut,
                            fallback: GlobalShortcut(storageValue: "command:48")!)
            }
            if model.isOn(.quickRing) {
                Button(ring.tryIt) { QuickRingService.shared.open() }
                    .buttonStyle(FrostButtonStyle(prominent: false, compact: true))
            }
        }
    }

    // MARK: - Keep awake

    private var keepAwakePage: some View {
        Group {
            header(home.keepAwake, text.lidSubtitle)
            FrostCard(title: home.keepAwake, icon: "moon.zzz") {
                FrostToggleRow(title: home.keepAwakeNow, isOn: model.binding(.keepAwake))
                FrostHairline()
                FrostToggleRow(title: setup.lidClosed, detail: l10n.s.clamshellNeedsPassword, isOn: model.lidClosed)
                FrostHairline()
                FrostToggleRow(title: l10n.s.dimScreenOnLidCloseTitle, isOn: model.dimOnLidClose)
            }
            FrostCard(title: text.shortcutsLabel, icon: "command") {
                shortcutRow(home.keepAwake, key: DefaultsKey.keepAwakeShortcut,
                            fallback: GlobalShortcut(storageValue: "control+option+command:40")!)
            }
        }
    }
}

/// One group of Windows-habit switches; tap the title to open or close it.
struct AvengersKeyGroup: View {
    let group: String
    let rules: [SharingRule]
    let startOpen: Bool
    let countFormat: String
    @State private var open: Bool?

    var body: some View {
        let expanded = open ?? startOpen
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { open = !expanded }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(Frost.muted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text(group).font(.system(size: 13, weight: .semibold)).foregroundColor(Frost.text)
                    Spacer()
                    Text(String(format: countFormat, rules.filter(\.on).count, rules.count))
                        .font(.system(size: 11)).foregroundColor(Frost.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                ForEach(rules) { rule in
                    HStack(alignment: .center, spacing: 10) {
                        Text(rule.windows).font(.system(size: 12, weight: .semibold)).foregroundColor(Frost.text)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Frost.text.opacity(0.07)))
                            .fixedSize()
                        Image(systemName: "arrow.right").font(.system(size: 9.5, weight: .bold)).foregroundColor(Frost.muted)
                        Text(rule.mac).font(.system(size: 12)).foregroundColor(Frost.muted).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Toggle(isOn: Binding(get: { rule.on }, set: { SharingEngine.shared.setRule(rule.id, $0) })) { EmptyView() }
                            .toggleStyle(FrostToggleStyle()).fixedSize()
                    }
                    .opacity(rule.on ? 1 : 0.55)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Frost.text.opacity(0.035)))
    }
}

/// The sharing window's screen layout: drag the Windows screen around the
/// Mac; it follows with a little tilt and snaps to the nearest side, and the
/// side goes to the sharing helper.
struct AvengersArrangeStage: View {
    let text: AvengersStrings
    @ObservedObject var model: AvengersModel
    @State private var drag: CGSize = .zero
    @State private var dragging = false

    private let macSize = CGSize(width: 120, height: 78)
    private let winSize = CGSize(width: 132, height: 80)

    private var share: SharingSnapshot? { model.sharing }
    private var side: Int { share?.side ?? 1 }
    private var hasPeer: Bool { share?.peerId.isEmpty == false }

    private func offset(for side: Int) -> CGSize {
        let gap: CGFloat = 18
        switch side {
        case 0: return CGSize(width: -(macSize.width + winSize.width) / 2 - gap, height: 0)
        case 2: return CGSize(width: 0, height: -(macSize.height + winSize.height) / 2 - gap)
        case 3: return CGSize(width: 0, height: (macSize.height + winSize.height) / 2 + gap)
        default: return CGSize(width: (macSize.width + winSize.width) / 2 + gap, height: 0)
        }
    }

    private func nearest(_ point: CGSize) -> Int {
        (0...3).min { a, b in
            let oa = offset(for: a), ob = offset(for: b)
            return hypot(oa.width - point.width, oa.height - point.height) < hypot(ob.width - point.width, ob.height - point.height)
        } ?? 1
    }

    var body: some View {
        let base = offset(for: side)
        let current = CGSize(width: base.width + drag.width, height: base.height + drag.height)
        ZStack {
            if hasPeer {
                Path { path in path.move(to: .zero); path.addLine(to: CGPoint(x: current.width, y: current.height)) }
                    .stroke(share?.connected == true ? AnyShapeStyle(Frost.accentGradient) : AnyShapeStyle(Frost.muted.opacity(0.5)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
                    .frame(width: 0, height: 0)
            }
            if dragging {
                let near = nearest(current)
                ForEach((0...3).filter { $0 != side }, id: \.self) { zone in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Frost.accent.opacity(zone == near ? 0.8 : 0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Frost.accent.opacity(zone == near ? 0.10 : 0.03)))
                        .frame(width: winSize.width, height: winSize.height)
                        .offset(offset(for: zone))
                }
            }
            screen(title: text.thisMac, sub: share?.active == true ? text.pointerHere : (AvengersDemo.names ? "MacBook Air" : Host.current().localizedName ?? "Mac"),
                   size: macSize, accent: false, icon: share?.active == true ? "cursorarrow.motionlines" : "laptopcomputer")
            if hasPeer, let share {
                screen(title: share.peer.isEmpty ? "Windows" : share.peer,
                       sub: share.connected ? text.pillConnected : text.offline,
                       size: winSize, accent: true, icon: "pc")
                    .scaleEffect(dragging ? 1.06 : 1)
                    .rotationEffect(.degrees(dragging ? Double(max(-6, min(6, drag.width / 25))) : 0))
                    .offset(current)
                    .gesture(DragGesture()
                        .onChanged { value in
                            if !dragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { dragging = true } }
                            drag = value.translation
                        }
                        .onEnded { value in
                            let next = nearest(CGSize(width: base.width + value.translation.width,
                                                      height: base.height + value.translation.height))
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                                SharingEngine.shared.setSide(next)
                                drag = .zero
                                dragging = false
                            }
                        })
            }
        }
        .offset(hasPeer ? CGSize(width: -base.width / 2, height: -base.height / 2) : .zero)
        .animation(.spring(response: 0.42, dampingFraction: 0.75), value: side)
        .frame(maxWidth: .infinity).frame(height: 200)
        .background(ZStack { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Frost.stage); FrostStageDots() })
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func screen(title: String, sub: String, size: CGSize, accent: Bool, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent ? AnyShapeStyle(Frost.accentGradient) : AnyShapeStyle(Frost.muted))
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(Frost.text).lineLimit(1)
            Text(sub).font(.system(size: 10)).foregroundColor(Frost.muted).lineLimit(1)
        }
        .padding(8)
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.85))
                if accent { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Frost.accent.opacity(0.08)) }
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(accent ? AnyShapeStyle(Frost.accentGradient) : AnyShapeStyle(Frost.text.opacity(0.14)),
                                  lineWidth: accent ? 1.5 : 1)
            }
        )
        .shadow(color: Frost.shadow, radius: 12, y: 6)
    }
}

/// `--avengers-snapshot` draws sample names instead of this Mac's and its user's.
enum AvengersDemo {
    static let names = CommandLine.arguments.contains("--avengers-snapshot")
}
