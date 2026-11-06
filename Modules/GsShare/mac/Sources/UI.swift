// G's Avengers — the settings window. Every colour/material comes from the active Look (Look.swift).
import ServiceManagement
import SwiftUI

// MARK: - Small building blocks

struct LogoMark: View {
    @Environment(\.look) var L
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: L.dark ? [Color(hex: 0x2E2F38), Color(hex: 0x15161B)] : [Color(hex: 0x2A2B33), Color(hex: 0x1A1B22)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Text("G").font(.system(size: size * 0.56, weight: .heavy, design: .rounded)).foregroundColor(Color(hex: 0xFFFDF8)).offset(x: -size * 0.03)
            Circle().fill(L.accentGradient).frame(width: size * 0.2, height: size * 0.2).offset(x: size * 0.24, y: -size * 0.24)
                .shadow(color: L.accent.opacity(0.9 * max(L.glow, 0.3)), radius: size * 0.12)
        }
        .frame(width: size, height: size)
        .shadow(color: L.accent.opacity(0.35 * L.glow), radius: size * 0.35, y: size * 0.08)
        .shadow(color: L.shadow, radius: 8, y: 4)
    }
}

struct Card<Content: View>: View {
    @Environment(\.look) var L
    let title: String
    var icon: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(L.accentGradient) }
                Text(L.capsLabels ? title.uppercased() : title)
                    .font(.system(size: L.capsLabels ? 10.5 : 13, weight: .semibold))
                    .tracking(L.capsLabels ? 1.4 : 0).foregroundColor(L.capsLabels ? L.muted : L.text)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }
}

struct CardSurface: View {
    @Environment(\.look) var L
    var radius: CGFloat? = nil
    var body: some View {
        let r = radius ?? L.radius
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        ZStack {
            if L.cardGlass { shape.fill(.ultraThinMaterial).opacity(L.dark ? 0.55 : 0.9) }
            shape.fill(L.card)
            // soft top highlight instead of a hard edge
            shape.fill(LinearGradient(colors: [Color.white.opacity(L.dark ? 0.06 : 0.5), .clear], startPoint: .top, endPoint: .center))
            shape.strokeBorder(LinearGradient(colors: [L.cardStroke, L.cardStroke.opacity(0.35)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .shadow(color: L.shadow, radius: L.dark ? 18 : 22, y: L.dark ? 8 : 10)
    }
}

/// Reacts to hover (lifts + brightens) and press (springs down).
struct LivelyButton: ButtonStyle {
    @Environment(\.look) var L
    var prominent = true
    func makeBody(configuration: Configuration) -> some View { LivelyBody(configuration: configuration, prominent: prominent, L: L) }

    struct LivelyBody: View {
        let configuration: Configuration
        let prominent: Bool
        let L: Look
        @State private var hover = false
        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(prominent ? .white : L.text)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(
                    ZStack {
                        if prominent {
                            Capsule().fill(L.accentGradient)
                            Capsule().fill(LinearGradient(colors: [Color.white.opacity(hover ? 0.32 : 0.22), .clear], startPoint: .top, endPoint: .center))
                        } else {
                            Capsule().fill(L.text.opacity(hover ? 0.10 : 0.06))
                        }
                    }
                )
                .shadow(color: prominent ? L.accent.opacity((hover ? 0.55 : 0.35) * max(L.glow, 0.4)) : .clear, radius: hover ? 16 : 10, y: hover ? 6 : 4)
                .scaleEffect(configuration.isPressed ? 0.95 : (hover ? 1.03 : 1))
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hover)
                .onHover { hover = $0 }
        }
    }
}

/// Live status pill: breathing dot while searching, steady glow when connected.
struct StatusPill: View {
    @Environment(\.look) var L
    let connected: Bool
    let active: Bool
    @State private var pulse = false
    var body: some View {
        let c = connected ? L.ok : L.accent
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(c.opacity(0.35)).frame(width: 16, height: 16).scaleEffect(pulse ? 1.25 : 0.6).opacity(pulse ? 0 : 0.9)
                Circle().fill(c).frame(width: 8, height: 8).shadow(color: c.opacity(0.9), radius: 4)
            }.frame(width: 16, height: 16)
            Text(connected ? (active ? "On this Mac" : "Connected") : "Searching")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(L.text)
                .contentTransition(.opacity)
        }
        .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 6)
        .background(Capsule().fill(L.text.opacity(0.07)))
        .overlay(Capsule().strokeBorder(L.text.opacity(0.08), lineWidth: 1))
        .background(ConnectRipple(color: L.ok, trigger: connected))
        .onAppear { pulse = true }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: connected)
    }
}

// MARK: - Main window

struct MainView: View {
    @ObservedObject var state: AppState
    let server: Server?
    @State private var loginItem = SMAppService.mainApp.status == .enabled

    var L: Look { Look.all[min(max(state.config.look, 0), Look.all.count - 1)] }
    func changed() { state.save(); server?.configChanged() }

    var body: some View {
        ZStack {
            Group {
                if let m = L.material { GlassView(material: m) }
                LinearGradient(colors: L.bg, startPoint: .top, endPoint: .bottom)
                if !L.aurora.isEmpty { AuroraView(colors: L.aurora).opacity(L.dark ? 0.9 : 0.8) }
            }.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header.id("top").padding(.top, 26).entrance(0)
                        if !state.trusted { accessCard.transition(.move(edge: .top).combined(with: .opacity)) }
                        if let code = state.pairCode { pairCard(code).transition(.scale(scale: 0.92).combined(with: .opacity)) }
                        if state.config.pairings.isEmpty && state.pairCode == nil { setupCard.transition(.opacity) }
                        ArrangeCard(state: state, server: server).entrance(1)
                        keysCard.entrance(2)
                        optionsCard.entrance(3)
                        Text("Move back across the edge to return. Ctrl+Alt+Esc on the Windows keyboard always brings the mouse home.")
                            .font(.system(size: 11)).foregroundColor(L.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 22)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.pairCode)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.trusted)
                }
                .onChange(of: state.pairCode) { c in if c != nil { withAnimation { proxy.scrollTo("top", anchor: .top) } } }
            }
        }
        .frame(width: 520, height: 780)
        .environment(\.look, L)
        .preferredColorScheme(L.dark ? .dark : .light)
        .tint(L.accent)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in if server != nil { state.trusted = AXIsProcessTrusted() } }
    }

    var header: some View {
        HStack(spacing: 14) {
            LogoMark(size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text("G's Avengers").font(L.title(23)).foregroundColor(L.text)
                Text("One keyboard and mouse, two computers").font(.system(size: 12.5)).lineLimit(1).foregroundColor(L.muted)
            }
            Spacer(minLength: 8)
            StatusPill(connected: state.connected, active: state.active)
        }
    }

    var accessCard: some View {
        Card(title: "One-time permission", icon: "hand.raised.fill") {
            Text("macOS needs your OK before G's Avengers can move the pointer and type on this Mac.")
                .font(.system(size: 13)).foregroundColor(L.text)
            Button("Open Accessibility settings") {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(opts)
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }.buttonStyle(LivelyButton())
        }
    }

    var setupCard: some View {
        Card(title: "Getting started", icon: "sparkles") {
            SetupStep(n: 1, title: "Install it on the Windows laptop",
                      text: "On the laptop, download GsAvengers-windows from github.com/GauthamWho/GsAvengers/releases, unzip it and double-click INSTALL.cmd.",
                      done: !state.lastPeerSeen.isEmpty || state.connected)
            SetupStep(n: 2, title: "Check the number, press Pair",
                      text: "Both screens show the same 6-digit number. Press “Numbers match — Pair” on both. You only do this once.",
                      done: state.connected)
            SetupStep(n: 3, title: "Push the pointer across",
                      text: "Move the Windows mouse off the laptop's edge towards this Mac. Your Windows keys work here the Windows way: Ctrl+C copies, ⊞ is fn.",
                      done: false)
            if !state.lastPeerSeen.isEmpty && !state.connected {
                Text("Found on your Wi-Fi: \(state.lastPeerSeen)").font(.system(size: 11.5, weight: .medium)).foregroundColor(L.ok)
            }
        }
    }

    func pairCard(_ code: String) -> some View {
        Card(title: "Pair with \(state.peerName)", icon: "link") {
            Text("Check the same number shows on the Windows laptop.").font(.system(size: 13)).foregroundColor(L.text)
            HStack(spacing: 8) {
                ForEach(Array(code.enumerated()), id: \.offset) { i, ch in
                    PairDigit(ch: ch, index: i).padding(.leading, i == 3 ? 10 : 0)
                }
            }
            if state.iConfirmed {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Waiting for you to press Pair on Windows…").font(.system(size: 12)).foregroundColor(L.muted) }
            } else {
                Button("Numbers match — Pair") { server?.confirmPair() }.buttonStyle(LivelyButton())
            }
        }
    }

    var keysCard: some View {
        Card(title: "Windows keys on this Mac", icon: "keyboard") {
            Text("The Windows keyboard does what it does on Windows. Each habit can be switched off.")
                .font(.system(size: 12.5)).foregroundColor(L.muted)
            ForEach(KeyGroupList.groups, id: \.self) { g in
                KeyGroupView(group: g, startOpen: g == KeyGroupList.groups.first,
                             isOn: { id in state.config.keyRules[id] ?? (KeyRules.toggle(id)?.defaultOn ?? false) },
                             set: { id, on in
                                 let d = KeyRules.toggle(id)?.defaultOn ?? false
                                 state.config.keyRules[id] = (on == d) ? nil : on
                                 changed()
                             })
            }
            Rectangle().fill(L.text.opacity(0.07)).frame(height: 1)
            Text("Your own extra swaps").font(.system(size: 13, weight: .semibold)).foregroundColor(L.text)
            ForEach($state.config.remaps) { $r in
                RemapRow(remap: $r, onChange: changed,
                         onDelete: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { state.config.remaps.removeAll { $0.id == r.id } }; changed() })
                    .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
            }
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    state.config.remaps.append(Remap(fromMods: ["ctrl"], fromKey: 0x41, toMods: ["command"], toKey: 0x00))
                }
                changed()
            } label: { Label("Add a key swap", systemImage: "plus") }
            .buttonStyle(LivelyButton(prominent: false))
        }
    }

    var optionsCard: some View {
        Card(title: "Options", icon: "slider.horizontal.3") {
            Toggle("Share the clipboard (text and pictures)", isOn: Binding(
                get: { state.config.shareClipboard }, set: { state.config.shareClipboard = $0; changed() }))
            SliderRow(title: "Pointer speed", value: Binding(get: { state.config.mouseSpeed }, set: { state.config.mouseSpeed = $0; changed() }), range: 0.4...2.5)
            SliderRow(title: "Scroll speed", value: Binding(get: { state.config.scrollSpeed }, set: { state.config.scrollSpeed = $0; changed() }), range: 0.2...3)
            Toggle("Reverse scrolling", isOn: Binding(get: { state.config.reverseScroll }, set: { state.config.reverseScroll = $0; changed() }))
            Toggle("Open at login", isOn: Binding(get: { loginItem }, set: { on in
                do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                loginItem = SMAppService.mainApp.status == .enabled
            }))
        }
        .toggleStyle(GlassToggle()).font(.system(size: 13))
    }
}

enum KeyGroupList {
    static let groups: [String] = KeyRules.toggles.reduce(into: [String]()) { if !$0.contains($1.group) { $0.append($1.group) } }
}

/// One group of Windows-habit switches; tap the title to open or close it.
struct KeyGroupView: View {
    @Environment(\.look) var L
    let group: String
    let startOpen: Bool
    let isOn: (String) -> Bool
    let set: (String, Bool) -> Void
    @State private var open: Bool? = nil

    var body: some View {
        let items = KeyRules.toggles.filter { $0.group == group }
        let expanded = open ?? startOpen
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { open = !expanded }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(L.muted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text(group).font(.system(size: 13, weight: .semibold)).foregroundColor(L.text)
                    Spacer()
                    Text("\(items.filter { isOn($0.id) }.count) of \(items.count) on").font(.system(size: 11)).foregroundColor(L.muted)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded {
                ForEach(items) { t in
                    HStack(alignment: .center, spacing: 10) {
                        Text(t.windows).font(.system(size: 12, weight: .semibold)).foregroundColor(L.text)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(L.text.opacity(0.07)))
                            .fixedSize()
                        Image(systemName: "arrow.right").font(.system(size: 9.5, weight: .bold)).foregroundColor(L.muted)
                        Text(t.mac).font(.system(size: 12)).foregroundColor(L.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Toggle(isOn: Binding(get: { isOn(t.id) }, set: { set(t.id, $0) })) { EmptyView() }
                            .toggleStyle(GlassToggle()).fixedSize()
                    }
                    .opacity(isOn(t.id) ? 1 : 0.55)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: max(L.radius - 6, 8), style: .continuous).fill(L.text.opacity(0.035)))
    }
}

struct SetupStep: View {
    @Environment(\.look) var L
    let n: Int
    let title: String
    let text: String
    let done: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? AnyShapeStyle(L.ok) : AnyShapeStyle(L.accentGradient)).frame(width: 24, height: 24)
                if done { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white) }
                else { Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundColor(.white) }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(L.text)
                Text(text).font(.system(size: 12)).foregroundColor(L.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: done)
    }
}

struct SliderRow: View {
    @Environment(\.look) var L
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var body: some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 104, alignment: .leading).foregroundColor(L.text)
            GlassSlider(value: $value, range: range)
            Text(String(format: "%.1f×", value)).monospacedDigit().font(.system(size: 12, weight: .medium))
                .frame(width: 44, height: 24).background(Capsule().fill(L.text.opacity(0.07))).foregroundColor(L.muted)
        }
    }
}

struct Chip: View {
    @Environment(\.look) var L
    let label: String
    let on: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 11.5, weight: .semibold)).lineLimit(1).fixedSize()
                .padding(.horizontal, 8).padding(.vertical, 5)
                .foregroundColor(on ? .white : L.muted)
                .background(
                    ZStack {
                        Capsule().fill(L.text.opacity(hover ? 0.10 : 0.06))
                        if on { Capsule().fill(L.accentGradient).shadow(color: L.accent.opacity(0.45 * max(L.glow, 0.4)), radius: 6, y: 2) }
                    }
                )
                .scaleEffect(hover ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: on)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
    }
}

struct RemapRow: View {
    @Environment(\.look) var L
    @Binding var remap: Remap
    var onChange: () -> Void
    var onDelete: () -> Void

    func chip(_ name: String, _ label: String, _ list: WritableKeyPath<Remap, [String]>) -> some View {
        let on = remap[keyPath: list].contains(name)
        return Chip(label: label, on: on) {
            if on { remap[keyPath: list].removeAll { $0 == name } } else { remap[keyPath: list].append(name) }
            onChange()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("Windows").font(.system(size: 11, weight: .medium)).foregroundColor(L.muted).frame(width: 54, alignment: .leading)
                ForEach([("ctrl", "Ctrl"), ("alt", "Alt"), ("shift", "Shift"), ("win", "Win")], id: \.0) { chip($0.0, $0.1, \.fromMods) }
                KeyMenu(options: KeyMap.hostKeyNames, selection: Binding(get: { remap.fromKey }, set: { remap.fromKey = $0; onChange() }))
                Toggle(isOn: Binding(get: { remap.enabled }, set: { remap.enabled = $0; onChange() })) { EmptyView() }.toggleStyle(GlassToggle()).fixedSize()
                Button(action: onDelete) { Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).frame(width: 20, height: 20).background(Circle().fill(L.text.opacity(0.06))) }
                    .buttonStyle(.plain).foregroundColor(L.muted)
            }
            HStack(spacing: 6) {
                Text("→ Mac").font(.system(size: 11, weight: .medium)).foregroundColor(L.muted).frame(width: 54, alignment: .leading)
                ForEach([("fn", "Fn"), ("control", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("command", "⌘")], id: \.0) { chip($0.0, $0.1, \.toMods) }
                KeyMenu(options: KeyMap.hostKeyNames.map { ($0.0, KeyMap.table[$0.1] ?? 0) }, selection: Binding(get: { remap.toKey }, set: { remap.toKey = $0; onChange() }))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: max(L.radius - 6, 8), style: .continuous).fill(L.text.opacity(0.035)))
        .opacity(remap.enabled ? 1 : 0.5)
        .animation(.easeOut(duration: 0.2), value: remap.enabled)
    }
}

/// faint dot grid on the layout stage
struct StageDots: View {
    @Environment(\.look) var L
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 18
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(L.text.opacity(0.10)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

/// Drag the Windows screen around the Mac screen; it follows the finger with a little tilt and snaps with a spring.
struct ArrangeCard: View {
    @Environment(\.look) var L
    @ObservedObject var state: AppState
    let server: Server?
    @State private var drag: CGSize = .zero
    @State private var dragging = false
    @State private var flow: CGFloat = 0

    var side: Side { state.config.peerSide[state.peerId] ?? .right }
    let macSize = CGSize(width: 128, height: 84)
    let winSize = CGSize(width: 140, height: 86)

    func offset(for s: Side) -> CGSize {
        let gap: CGFloat = 18
        switch s {
        case .right: return CGSize(width: (macSize.width + winSize.width) / 2 + gap, height: 0)
        case .left: return CGSize(width: -(macSize.width + winSize.width) / 2 - gap, height: 0)
        case .top: return CGSize(width: 0, height: -(macSize.height + winSize.height) / 2 - gap)
        case .bottom: return CGSize(width: 0, height: (macSize.height + winSize.height) / 2 + gap)
        }
    }

    func nearest(_ p: CGSize) -> Side {
        Side.allCases.min { a, b in
            let oa = offset(for: a), ob = offset(for: b)
            return hypot(oa.width - p.width, oa.height - p.height) < hypot(ob.width - p.width, ob.height - p.height)
        }!
    }

    var body: some View {
        Card(title: "Screen layout", icon: "rectangle.on.rectangle") {
            Text(state.peerId.isEmpty ? "Your Windows laptop appears here once it connects." : "Drag the Windows screen to where it sits on your desk.")
                .font(.system(size: 13)).foregroundColor(L.text)
            ZStack {
                let base = offset(for: side)
                let cur = CGSize(width: base.width + drag.width, height: base.height + drag.height)
                if !state.peerId.isEmpty {
                    // the link between the two screens
                    Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: cur.width, y: cur.height)) }
                        .stroke(state.connected ? AnyShapeStyle(L.accentGradient) : AnyShapeStyle(L.muted.opacity(0.5)),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7], dashPhase: flow))
                        .offset(x: 0, y: 0)
                        .frame(width: 0, height: 0)
                        .shadow(color: L.accent.opacity(state.connected ? 0.6 * L.glow : 0), radius: 4)
                }
                if dragging {
                    let near = nearest(cur)
                    ForEach(Side.allCases.filter { $0 != side }, id: \.rawValue) { z in
                        let o = offset(for: z)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(L.accent.opacity(z == near ? 0.8 : 0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(L.accent.opacity(z == near ? 0.10 : 0.03)))
                            .frame(width: winSize.width, height: winSize.height)
                            .scaleEffect(z == near ? 1.04 : 0.97)
                            .offset(o)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: near)
                    }
                }
                screen(title: "This Mac", sub: state.active ? "pointer is here" : "MacBook Air", size: macSize, accent: false, icon: state.active ? "cursorarrow.motionlines" : "laptopcomputer")
                    .shadow(color: L.ok.opacity(state.active ? 0.55 : 0), radius: 16)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(L.ok.opacity(state.active ? 0.9 : 0), lineWidth: 1.5).frame(width: macSize.width, height: macSize.height))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.active)
                if !state.peerId.isEmpty {
                    screen(title: state.peerName.isEmpty ? "Windows" : state.peerName, sub: state.connected ? "connected" : "offline",
                           size: winSize, accent: true, icon: "pc")
                        .scaleEffect(dragging ? 1.06 : 1)
                        .rotationEffect(.degrees(dragging ? Double(max(-6, min(6, drag.width / 25))) : 0))
                        .shadow(color: L.accent.opacity(dragging ? 0.45 * max(L.glow, 0.4) : 0), radius: 20, y: 10)
                        .offset(cur)
                        .gesture(DragGesture()
                            .onChanged { v in
                                if !dragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { dragging = true } }
                                drag = v.translation
                            }
                            .onEnded { v in
                                let s = nearest(CGSize(width: base.width + v.translation.width, height: base.height + v.translation.height))
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                                    state.config.peerSide[state.peerId] = s
                                    drag = .zero; dragging = false
                                }
                                state.save(); server?.configChanged(); server?.setLayout(peerSide: s)
                            })
                        .onHover { h in if h { NSCursor.openHand.push() } else { NSCursor.pop() } }
                }
            }
            .offset(state.peerId.isEmpty ? .zero : CGSize(width: -offset(for: side).width / 2, height: -offset(for: side).height / 2))
            .animation(.spring(response: 0.42, dampingFraction: 0.75), value: side)
            .frame(maxWidth: .infinity).frame(height: 280)
            .background(ZStack { RoundedRectangle(cornerRadius: max(L.radius - 6, 8), style: .continuous).fill(L.stage); StageDots() })
            .clipShape(RoundedRectangle(cornerRadius: max(L.radius - 6, 8), style: .continuous))
            .onAppear { flow = -18 }
            if !state.lastPeerSeen.isEmpty && !state.connected {
                Text("Seen on the network: \(state.lastPeerSeen)").font(.system(size: 11)).foregroundColor(L.muted)
            }
        }
    }

    func screen(title: String, sub: String, size: CGSize, accent: Bool, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(accent ? AnyShapeStyle(L.accentGradient) : AnyShapeStyle(L.muted))
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(L.text).lineLimit(1)
            Text(sub).font(.system(size: 10)).foregroundColor(L.muted)
        }
        .padding(8)
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(L.dark ? Color.white.opacity(0.06) : Color.white.opacity(0.85))
                if accent { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(L.accent.opacity(L.dark ? 0.16 : 0.08)) }
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(accent ? AnyShapeStyle(L.accentGradient) : AnyShapeStyle(L.text.opacity(0.14)), lineWidth: accent ? 1.5 : 1)
            }
        )
        .shadow(color: L.shadow, radius: 12, y: 6)
    }
}
