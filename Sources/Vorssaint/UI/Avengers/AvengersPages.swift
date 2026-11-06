// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import SwiftUI

/// One page of the window. Every switch here is bound to the real thing:
/// this app's features through AvengersModel, sharing and clipboard through
/// HelperBridge (the helpers' own state, confirmed by their reply).
struct AvengersPageView: View {
    let page: AvengersPage
    @ObservedObject var router: AvengersRouter
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var model = AvengersModel.shared
    @ObservedObject private var bridge = HelperBridge.shared
    @State private var launchAtLogin = false

    private var text: AvengersStrings { FeatureStrings.avengers(l10n.language) }
    private var setup: GsMacSetupStrings { FeatureStrings.gsMacSetup(l10n.language) }
    private var ring: QuickRingStrings { FeatureStrings.quickRing(l10n.language) }
    private var helper: HelperAppStrings { FeatureStrings.helperApps(l10n.language) }
    private var share: HelperWire.ShareState? { bridge.sharing }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch page {
            case .home: home
            case .sharing: sharing
            case .keyboard: keyboard
            case .clipboard: clipboard
            case .quickRing: quickRing
            case .windowsApps: windowsApps
            case .capture: capture
            case .lidClosed: lidClosed
            case .more: more
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

    private func row(_ title: String, _ item: AvengersSwitch, detail: String? = nil, icon: String? = nil) -> some View {
        FrostToggleRow(title: title, detail: detail, icon: icon, isOn: model.binding(item))
    }

    private var greeting: String {
        // Offscreen snapshots (README pictures) never show the real user's name.
        let first = AvengersDemo.names ? "Alex"
            : NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
        let hour = Calendar.current.component(.hour, from: Date())
        let format = hour < 12 ? text.morning : (hour < 18 ? text.afternoon : text.evening)
        return String(format: format, first)
    }

    private func sideWord(_ side: Int) -> String {
        [text.sideLeft, text.sideRight, text.sideTop, text.sideBottom][min(max(side, 0), 3)]
    }

    private var laptopLine: String {
        guard let share else { return text.noLaptop }
        if !share.peer.isEmpty { return "\(share.peer) · \(sideWord(share.side))" }
        if !share.lastSeen.isEmpty { return String(format: text.seenFormat, share.lastSeen) }
        return text.noLaptop
    }

    private var pill: FrostStatusPill {
        guard bridge.sharingRunning, let share else { return FrostStatusPill(text: text.pillOff, good: false, quiet: true) }
        if share.paused { return FrostStatusPill(text: text.pillPaused, good: false, quiet: true) }
        if share.pairCode != nil { return FrostStatusPill(text: text.pillPairing, good: false) }
        if share.connected { return FrostStatusPill(text: share.active ? text.pillOnMac : text.pillConnected, good: true) }
        return FrostStatusPill(text: text.pillSearching, good: false)
    }

    private var shareOn: Binding<Bool> {
        Binding(get: { !(bridge.sharing?.paused ?? true) }, set: { bridge.setSharingPaused(!$0) })
    }

    private func rule(_ id: String) -> Binding<Bool> {
        Binding(get: { bridge.sharing?.rules.first { $0.id == id }?.on ?? false },
                set: { bridge.setRule(id, $0) })
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
            FrostToggleRow(title: text.shareKeyboardMouse, isOn: shareOn).disabled(share == nil)
        }
    }

    // MARK: - Home

    private var home: some View {
        Group {
            header(greeting, text.homeSubtitle)
            laptopCard
            HStack(alignment: .top, spacing: 12) {
                FrostCard(title: text.quickSwitches) {
                    row("\(ring.title) (⌃⌃)", .quickRing)
                    FrostHairline()
                    row("\(helper.clipboardTitle) (\(bridge.clipboard?.shortcut ?? "fn V"))", .clipboardHelper)
                    FrostHairline()
                    row(setup.lidClosed, .lidClosed)
                }
                FrostCard(title: text.windowsHabits) {
                    FrostToggleRow(title: text.ctrlIsCommand, isOn: rule("ctrl.cmd")).disabled(share == nil)
                    FrostHairline()
                    FrostToggleRow(title: text.winIsFn, isOn: rule("win.fn")).disabled(share == nil)
                    FrostHairline()
                    row(text.xCloses, .closeQuits)
                }
            }
        }
    }

    // MARK: - Windows sharing

    private var sharing: some View {
        Group {
            header(text.sharing, text.sharingSubtitle)
            if let share, !share.trusted {
                FrostCard(title: helper.sharingTitle, icon: "hand.raised.fill") {
                    Text(text.accessNeeded).font(.system(size: 13)).foregroundColor(Frost.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(helper.openSharingWindow) { bridge.openSharingWindow() }
                        .buttonStyle(FrostButtonStyle(compact: true))
                }
            }
            laptopCard
            pairingCard
            FrostCard(title: text.layoutLabel, icon: "rectangle.on.rectangle") {
                Text(share?.peerId.isEmpty == false ? text.layoutHint : text.layoutEmpty)
                    .font(.system(size: 12.5)).foregroundColor(Frost.muted)
                AvengersArrangeStage(text: text)
            }
            FrostCard(title: text.pointerLabel, icon: "cursorarrow.motionlines") {
                FrostSliderRow(title: text.pointerSpeed, value: Binding(
                    get: { share?.mouseSpeed ?? 1 },
                    set: { bridge.setShare(\.mouseSpeed, $0, .mouseSpeed($0), coalesce: true) }), range: 0.4...2.5)
                FrostSliderRow(title: text.scrollSpeed, value: Binding(
                    get: { share?.scrollSpeed ?? 1 },
                    set: { bridge.setShare(\.scrollSpeed, $0, .scrollSpeed($0), coalesce: true) }), range: 0.2...3)
                FrostHairline()
                FrostToggleRow(title: text.reverseScroll, isOn: Binding(
                    get: { share?.reverseScroll ?? false },
                    set: { bridge.setShare(\.reverseScroll, $0, .reverseScroll($0)) }))
                FrostHairline()
                FrostToggleRow(title: text.shareClipboard, isOn: Binding(
                    get: { share?.shareClipboard ?? false },
                    set: { bridge.setShare(\.shareClipboard, $0, .shareClipboard($0)) }))
            }
            .disabled(share == nil)
            Text(text.homeKeyHint).font(.system(size: 11)).foregroundColor(Frost.muted).padding(.horizontal, 4)
        }
    }

    @ViewBuilder private var pairingCard: some View {
        if let share {
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
                        Button(text.pairButton) { bridge.send(.confirmPair) }
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
    }

    // MARK: - Keyboard

    private var keyboard: some View {
        Group {
            header(text.keyboard, text.keyboardSubtitle)
            let rules = share?.rules ?? []
            let groups = rules.reduce(into: [String]()) { if !$0.contains($1.group) { $0.append($1.group) } }
            FrostCard(title: helper.keyboardRules.replacingOccurrences(of: "…", with: ""), icon: "keyboard") {
                if rules.isEmpty {
                    Text(text.pillOff).font(.system(size: 13)).foregroundColor(Frost.muted)
                }
                ForEach(groups, id: \.self) { group in
                    AvengersKeyGroup(group: group, rules: rules.filter { $0.group == group },
                                     startOpen: group == groups.first, countFormat: text.countFormat)
                }
            }
            HStack(spacing: 10) {
                Text(text.ownSwaps).font(.system(size: 12)).foregroundColor(Frost.muted)
                Spacer(minLength: 8)
                Button(helper.openSharingWindow) { bridge.openSharingWindow() }
                    .buttonStyle(FrostButtonStyle(prominent: false, compact: true))
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Clipboard

    private var clipboard: some View {
        let clip = bridge.clipboard
        let on = model.isOn(.clipboardHelper)
        return Group {
            header(helper.clipboardTitle, text.clipboardSubtitle)
            FrostCard(title: helper.clipboardTitle, icon: "doc.on.clipboard") {
                row(setup.clipboard, .clipboardHelper)
                if on {
                    HStack(spacing: 8) {
                        Button(helper.openClipboard) { bridge.openClipboard() }.buttonStyle(FrostButtonStyle(compact: true))
                        Button(helper.openEmoji) { bridge.openEmoji() }.buttonStyle(FrostButtonStyle(prominent: false, compact: true))
                    }
                }
            }
            FrostCard(title: text.shortcutsLabel, icon: "command") {
                shortcutRow(text.openClipboardRow, clip?.shortcut ?? "fn V")
                FrostHairline()
                shortcutRow(text.openEmojiRow, clip?.emojiShortcut ?? "fn E")
                Button(text.change) { bridge.openClipboardSettings() }
                    .buttonStyle(FrostButtonStyle(prominent: false, compact: true))
            }
            .disabled(clip == nil)
            FrostCard(title: text.historyLabel, icon: "clock.arrow.circlepath") {
                FrostToggleRow(title: text.pasteAfterPick, isOn: Binding(
                    get: { clip?.pasteAfterPick ?? false },
                    set: { bridge.setClipboard(\.pasteAfterPick, $0, .pasteAfterPick($0)) }))
                FrostHairline()
                FrostToggleRow(title: text.smartCleanup, isOn: Binding(
                    get: { clip?.smartCleanup ?? false },
                    set: { bridge.setClipboard(\.smartCleanup, $0, .smartCleanup($0)) }))
                FrostHairline()
                HStack(spacing: 6) {
                    Text(text.keepUpTo).font(.system(size: 13)).foregroundColor(Frost.text)
                    Spacer(minLength: 8)
                    ForEach([200, 500, 1000, 0], id: \.self) { count in
                        FrostChip(label: count == 0 ? text.noLimit : "\(count)", on: clip?.maxItems == count) {
                            bridge.setClipboard(\.maxItems, count, .maxItems(count))
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            .disabled(clip == nil)
            if !on {
                Text(text.clipboardOffHint).font(.system(size: 11)).foregroundColor(Frost.muted).padding(.horizontal, 4)
            }
        }
    }

    private func shortcutRow(_ title: String, _ keys: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundColor(Frost.text)
            Spacer(minLength: 8)
            Text(keys).font(.system(size: 12, weight: .semibold)).foregroundColor(Frost.text)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Frost.text.opacity(0.07)))
        }
        .padding(.vertical, 3)
    }

    // MARK: - Quick Ring

    private var quickRing: some View {
        Group {
            header(ring.title, ring.hubDescription)
            FrostCard(title: ring.title, icon: "circle.circle") {
                row(ring.title, .quickRing)
            }
            FrostCard(title: text.howItOpens, icon: "hand.tap") {
                row(ring.controlDoubleTap, .ringDoubleTap)
                FrostHairline()
                row(ring.controlClick, .ringControlClick, detail: ring.controlClickCaption)
                FrostHairline()
                row(ring.middleClick, .ringMiddleClick, detail: ring.middleClickCaption)
            }
            FrostCard(title: text.whatsInIt, icon: "square.grid.2x2") {
                HStack(spacing: 10) {
                    ForEach([QuickRingItem.capture, .record, .clipboard, .windows], id: \.self) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.symbolName).font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Frost.accentGradient).frame(height: 22)
                            Text(item.title(ring)).font(.system(size: 11.5, weight: .medium)).foregroundColor(Frost.text)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Frost.text.opacity(0.035)))
                    }
                }
                if model.isOn(.quickRing) {
                    Button(ring.tryIt) { QuickRingService.shared.open() }
                        .buttonStyle(FrostButtonStyle(prominent: false, compact: true))
                }
            }
        }
    }

    // MARK: - Windows & apps, capture, lid

    private var windowsApps: some View {
        Group {
            header(text.windowsApps, text.windowsAppsSubtitle)
            FrostCard(title: text.windowsApps, icon: "macwindow.on.rectangle") {
                row(setup.switcher, .switcher, icon: GsMacEssential.switcher.symbolName)
                FrostHairline()
                row(setup.closeQuits, .closeQuits, icon: GsMacEssential.closeQuits.symbolName)
                FrostHairline()
                row(setup.snapping, .snapping, icon: GsMacEssential.snapping.symbolName)
                FrostHairline()
                row(setup.cutPaste, .cutPaste, icon: GsMacEssential.cutPaste.symbolName)
            }
        }
    }

    private var capture: some View {
        Group {
            header(text.capture, text.captureSubtitle)
            FrostCard(title: text.capture, icon: "camera.viewfinder") {
                row(setup.screenshot, .screenshot, icon: GsMacEssential.screenshot.symbolName)
                FrostHairline()
                row(setup.recorder, .recorder, icon: GsMacEssential.recorder.symbolName)
            }
        }
    }

    private var lidClosed: some View {
        Group {
            header(text.lidClosed, text.lidSubtitle)
            FrostCard(title: text.lidClosed, icon: "moon.zzz") {
                row(setup.lidClosed, .lidClosed, detail: l10n.s.clamshellNeedsPassword)
                FrostHairline()
                row(l10n.s.dimScreenOnLidCloseTitle, .dimOnLidClose)
            }
        }
    }

    // MARK: - More

    private var more: some View {
        Group {
            header(text.more, text.moreSubtitle)
            FrostCard(title: text.toolsLabel, icon: "square.grid.2x2") {
                let features = model.moreFeatures
                let hub = FeatureStrings.hub(l10n.language)
                ForEach(features, id: \.self) { feature in
                    if feature != features.first { FrostHairline() }
                    FrostToggleRow(title: feature.hubTitle(l10n.s, hub: hub), icon: feature.symbolName,
                                   isOn: model.featureBinding(feature))
                }
            }
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
                    Button(text.advanced) { (NSApp.delegate as? AppDelegate)?.openSettingsWindow() }
                        .buttonStyle(FrostButtonStyle(compact: true))
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
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(string: l10n.s.aboutDescription,
                                         attributes: [.font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

/// One group of Windows-habit switches; tap the title to open or close it.
struct AvengersKeyGroup: View {
    let group: String
    let rules: [HelperWire.ShareRule]
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
                        Toggle(isOn: Binding(get: { rule.on }, set: { HelperBridge.shared.setRule(rule.id, $0) })) { EmptyView() }
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
    @ObservedObject private var bridge = HelperBridge.shared
    @State private var drag: CGSize = .zero
    @State private var dragging = false

    private let macSize = CGSize(width: 120, height: 78)
    private let winSize = CGSize(width: 132, height: 80)

    private var share: HelperWire.ShareState? { bridge.sharing }
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
                                bridge.setShare(\.side, next, .side(next))
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
