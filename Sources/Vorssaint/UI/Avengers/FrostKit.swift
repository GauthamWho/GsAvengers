// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import SwiftUI

/// The "Frost" look of the sharing app (Modules/GsShare/mac/Sources/Look.swift,
/// UI.swift, Polish.swift), carried over value for value so the main window
/// matches the sharing window: bright frosted glass, peach and sky light,
/// white glassy cards, an orange accent, rounded bold titles, caps labels.
enum Frost {
    static let text = Color(frost: 0x10131F)
    static let muted = Color(frost: 0x666B7C)
    static let accent = Color(frost: 0xE4572E)
    static let accent2 = Color(frost: 0xFF9466)
    static let ok = Color(frost: 0x1FA463)
    static let card = Color.white.opacity(0.55)
    static let cardStroke = Color.white.opacity(0.85)
    static let shadow = Color(frost: 0x3A4A7A, 0.16)
    static let stage = Color.white.opacity(0.35)
    static let glow = 0.35
    static let radius: CGFloat = 16
    static let background = [Color.white.opacity(0.45), Color(frost: 0xEEF2F8, 0.55)]
    static let aurora = [Color(frost: 0xFFC4AE, 0.55), Color(frost: 0xBFD3FF, 0.55)]
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent2, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

extension Color {
    init(frost hex: UInt32, _ alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// True while the window is drawn offscreen for a PNG: nothing behind the
/// window to blur and no time passing, so glass and drifting light are
/// painted as their still, opaque equivalents.
private struct FrostSnapshotKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var frostSnapshot: Bool {
        get { self[FrostSnapshotKey.self] }
        set { self[FrostSnapshotKey.self] = newValue }
    }
}

/// Real window glass: blurs whatever is behind the window.
struct FrostGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Glass, the Frost tint and two slow drifting lights, behind everything.
struct FrostBackdrop: View {
    @Environment(\.frostSnapshot) private var snapshot
    var body: some View {
        ZStack {
            if snapshot {
                LinearGradient(colors: [Color(frost: 0xE4E9F2), Color(frost: 0xF2ECE8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                FrostGlass()
            }
            LinearGradient(colors: Frost.background, startPoint: .top, endPoint: .bottom)
            if snapshot { lights(0) } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { lights($0.date.timeIntervalSinceReferenceDate) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func lights(_ seconds: Double) -> some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(Frost.aurora.enumerated()), id: \.offset) { index, color in
                    let phase = Double(index) * 2.1
                    Circle().fill(color)
                        .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                        .position(x: geometry.size.width * (0.5 + 0.38 * sin(seconds * 0.11 + phase)),
                                  y: geometry.size.height * (0.28 + 0.30 * cos(seconds * 0.08 + phase * 1.3)))
                        .blur(radius: 90)
                }
            }
        }
        .opacity(0.8)
    }
}

struct FrostCardSurface: View {
    @Environment(\.frostSnapshot) private var snapshot
    var radius: CGFloat = Frost.radius
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if snapshot { shape.fill(Color.white.opacity(0.5)) } else { shape.fill(.ultraThinMaterial).opacity(0.9) }
            shape.fill(Frost.card)
            // soft top highlight instead of a hard edge
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center))
            shape.strokeBorder(LinearGradient(colors: [Frost.cardStroke, Frost.cardStroke.opacity(0.35)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .shadow(color: Frost.shadow, radius: 22, y: 10)
    }
}

/// A white glassy card with a small caps label on top.
struct FrostCard<Content: View>: View {
    let title: String
    var icon: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Frost.accentGradient)
                }
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold)).tracking(1.4).foregroundColor(Frost.muted)
                    .lineLimit(1)
            }
            content
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrostCardSurface())
    }
}

/// The hairline between two rows of a card.
struct FrostHairline: View {
    var body: some View { Rectangle().fill(Frost.text.opacity(0.06)).frame(height: 1) }
}

/// Springy glass switch; the label sits left, the switch right.
struct FrostToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View { FrostToggleBody(configuration: configuration) }
}

private struct FrostToggleBody: View {
    @Environment(\.isEnabled) private var enabled
    let configuration: ToggleStyleConfiguration
    @State private var hover = false
    @State private var pressing = false
    var body: some View {
        let on = configuration.isOn
        HStack(spacing: 12) {
            configuration.label.foregroundColor(Frost.text)
            Spacer(minLength: 8)
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(Frost.text.opacity(0.10))
                Capsule().fill(Frost.accentGradient).opacity(on ? 1 : 0)
                Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                    .opacity(on ? 1 : 0.4)
                Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 0.8)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(frost: 0xF3F4F8)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1.5)
                    .frame(width: pressing ? 26 : 22, height: 22)
                    .padding(2)
            }
            .frame(width: 46, height: 26)
            .shadow(color: Frost.accent.opacity(on ? 0.35 * 0.5 : 0), radius: hover ? 9 : 6, y: 2)
            .scaleEffect(hover ? 1.04 : 1)
            .opacity(enabled ? 1 : 0.45)
            .onHover { hover = $0 && enabled }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard enabled, !pressing else { return }
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { pressing = true }
                }
                .onEnded { _ in
                    guard enabled else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                        pressing = false
                        configuration.isOn.toggle()
                    }
                })
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.34, dampingFraction: 0.62), value: on)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
    }
}

/// One row of a card: a name (and an optional line under it) and a switch.
struct FrostToggleRow: View {
    let title: String
    var detail: String?
    var icon: String?
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .medium)).foregroundColor(Frost.muted)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13)).foregroundColor(Frost.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail).font(.system(size: 11)).foregroundColor(Frost.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .toggleStyle(FrostToggleStyle())
        .padding(.vertical, 3)
    }
}

/// Glass slider: gradient fill, knob that swells while you drag it.
struct FrostSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var dragging = false
    @State private var hover = false
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width, knob: CGFloat = 20
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let x = min(max(fraction, 0), 1) * (width - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(Frost.text.opacity(0.09)).frame(height: 6)
                Capsule().fill(Frost.accentGradient).frame(width: x + knob / 2, height: 6)
                    .shadow(color: Frost.accent.opacity(0.4 * 0.5), radius: 4)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(frost: 0xF1F2F6)], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.2), radius: dragging ? 6 : 3, y: dragging ? 3 : 1.5)
                    .frame(width: knob, height: knob)
                    .scaleEffect(dragging ? 1.22 : (hover ? 1.08 : 1))
                    .offset(x: x)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    if !dragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { dragging = true } }
                    let next = min(max((drag.location.x - knob / 2) / (width - knob), 0), 1)
                    value = range.lowerBound + Double(next) * (range.upperBound - range.lowerBound)
                }
                .onEnded { _ in withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { dragging = false } })
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
        }
        .frame(height: 26)
    }
}

struct FrostSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 13)).foregroundColor(Frost.text).frame(width: 120, alignment: .leading)
            FrostSlider(value: $value, range: range)
            Text(String(format: "%.1f×", locale: Locale.current, value)).monospacedDigit().font(.system(size: 12, weight: .medium))
                .frame(width: 44, height: 24).background(Capsule().fill(Frost.text.opacity(0.07))).foregroundColor(Frost.muted)
        }
    }
}

/// Reacts to hover (lifts and brightens) and press (springs down).
struct FrostButtonStyle: ButtonStyle {
    var prominent = true
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        FrostButtonBody(configuration: configuration, prominent: prominent, compact: compact)
    }
}

private struct FrostButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    let compact: Bool
    @State private var hover = false
    var body: some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .foregroundColor(prominent ? .white : Frost.text)
            .padding(.horizontal, compact ? 12 : 18).padding(.vertical, compact ? 6 : 10)
            .background(
                ZStack {
                    if prominent {
                        Capsule().fill(Frost.accentGradient)
                        Capsule().fill(LinearGradient(colors: [Color.white.opacity(hover ? 0.32 : 0.22), .clear],
                                                      startPoint: .top, endPoint: .center))
                    } else {
                        Capsule().fill(Frost.text.opacity(hover ? 0.10 : 0.06))
                    }
                }
            )
            .shadow(color: prominent ? Frost.accent.opacity((hover ? 0.55 : 0.35) * 0.4) : .clear,
                    radius: hover ? 16 : 10, y: hover ? 6 : 4)
            .scaleEffect(configuration.isPressed ? 0.95 : (hover ? 1.03 : 1))
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hover)
            .onHover { hover = $0 }
    }
}

/// Live status pill: breathing dot while searching, steady glow when connected.
struct FrostStatusPill: View {
    @Environment(\.frostSnapshot) private var snapshot
    let text: String
    let good: Bool
    var quiet = false
    @State private var pulse = false
    var body: some View {
        let color = quiet ? Frost.muted : (good ? Frost.ok : Frost.accent)
        HStack(spacing: 7) {
            ZStack {
                if !quiet && !snapshot {
                    Circle().fill(color.opacity(0.35)).frame(width: 16, height: 16)
                        .scaleEffect(pulse ? 1.25 : 0.6).opacity(pulse ? 0 : 0.9)
                }
                Circle().fill(color).frame(width: 8, height: 8).shadow(color: color.opacity(0.9), radius: 4)
            }
            .frame(width: 16, height: 16)
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(Frost.text).lineLimit(1)
        }
        .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 5)
        .background(Capsule().fill(Frost.text.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Frost.text.opacity(0.08), lineWidth: 1))
        .fixedSize()
        .onAppear {
            guard !snapshot else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// One pairing digit on its own small card.
struct FrostPairDigit: View {
    let digit: Character
    var body: some View {
        Text(String(digit))
            .font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit().foregroundColor(Frost.text)
            .frame(width: 40, height: 50)
            .background(FrostCardSurface(radius: 12))
    }
}

/// A numbered step, ticked once done.
struct FrostStep: View {
    let number: Int
    let text: String
    let done: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(done ? AnyShapeStyle(Frost.ok) : AnyShapeStyle(Frost.accentGradient)).frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                } else {
                    Text("\(number)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                }
            }
            Text(text).font(.system(size: 12)).foregroundColor(Frost.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A small pick-one capsule, the accent fill marking the current choice.
struct FrostChip: View {
    let label: String
    let on: Bool
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 11.5, weight: .semibold)).lineLimit(1).fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .foregroundColor(on ? .white : Frost.muted)
                .background(
                    ZStack {
                        Capsule().fill(Frost.text.opacity(hover ? 0.10 : 0.06))
                        if on {
                            Capsule().fill(Frost.accentGradient)
                                .shadow(color: Frost.accent.opacity(0.45 * 0.4), radius: 6, y: 2)
                        }
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

/// The GsA monogram tile: SF Pro semibold, tight tracking, white on black.
struct FrostLogo: View {
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(frost: 0x2A2B33), Color(frost: 0x15161B)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Text("GsA").font(.system(size: size * 0.4, weight: .semibold)).tracking(-0.3).foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Frost.shadow, radius: 6, y: 3)
    }
}

/// faint dot grid on the layout stage
struct FrostStageDots: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 18
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(Frost.text.opacity(0.10)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}
