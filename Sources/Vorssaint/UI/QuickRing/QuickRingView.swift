// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import AppKit
import SwiftUI

/// The Quick Ring: one ring-shaped band of native Liquid Glass with white
/// symbols on it, nothing else. The middle stays clear round the pointer.
struct QuickRingView: View {
    @ObservedObject private var service = QuickRingService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let accent = Color(red: 0.18, green: 0.48, blue: 1)
    private static let recordRed = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        let strings = FeatureStrings.quickRing(l10n.language)
        ZStack {
            // Invisible, but solid to the window server: a click in the
            // middle closes the ring instead of falling through to the app.
            Circle()
                .fill(Color.black.opacity(0.004))
                .frame(width: QuickRingLayout.innerRadius * 2, height: QuickRingLayout.innerRadius * 2)
                .accessibilityHidden(true)
            content(strings)
        }
        .frame(width: QuickRingLayout.panelSize, height: QuickRingLayout.panelSize)
        // The grow and shrink are the panel's (QuickRingMotion), run by the
        // render server, so SwiftUI never re-lays the glass frame by frame.
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.title)
    }

    private func content(_ strings: QuickRingStrings) -> some View {
        let outer = QuickRingLayout.outerRadius
        return ZStack {
            glass(QuickRingAnnulus(inner: QuickRingLayout.innerRadius))
                .frame(width: outer * 2, height: outer * 2)
            ForEach(Array(service.entries.enumerated()), id: \.offset) { index, entry in
                item(entry, title: entry.item.title(strings), highlighted: service.highlightedIndex == index)
                    .offset(offset(index))
            }
        }
    }

    private func offset(_ index: Int) -> CGSize {
        let unit = RadialMenuGeometry.unitPosition(index: index, itemCount: service.entries.count)
        // SwiftUI's y grows downward.
        return CGSize(width: unit.dx * QuickRingLayout.itemRadius, height: -unit.dyUp * QuickRingLayout.itemRadius)
    }

    // MARK: - Items

    /// A white symbol over a 10 pt word, carried on the band.
    private func item(_ entry: QuickRingEntry, title: String, highlighted: Bool) -> some View {
        let isStop = entry.item == .stopRecording
        let lit = entry.isCurrent && !isStop
        let size = QuickRingLayout.itemDiameter
        let label = VStack(spacing: 2) {
            Image(systemName: entry.item.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isStop ? Self.recordRed : .white)
                .frame(height: 18)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 3)
        }
        // The only extra: a soft shadow under white type, so it holds 4.5:1
        // where the glass shows a white page.
        .shadow(color: .black.opacity(0.5), radius: 1.5)
        .frame(width: size, height: size)
        // A recording in progress and the pointed action get a glass lens of their
        // own. The glass is the item's own effect, so the system draws the
        // symbol and word on top of it.
        return lens(label, enabled: lit || highlighted, lit: lit)
        .scaleEffect(highlighted && !reduceMotion ? 1.08 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.8), value: highlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(lit ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func lens(_ label: some View, enabled: Bool, lit: Bool) -> some View {
        let tint = lit ? Self.accent.opacity(0.7) : Color.white.opacity(0.18)
        if !enabled {
            label
        } else if reduceTransparency {
            label.background(Circle().fill(lit ? Self.accent : Color(white: 0.28)))
        } else {
#if compiler(>=6.2)
            if #available(macOS 26, *) {
                label.glassEffect(.regular.tint(tint), in: Circle())
            } else {
                label.background(fallback(Circle(), tint: tint))
            }
#else
            label.background(fallback(Circle(), tint: tint))
#endif
        }
    }

    // MARK: - Glass

    /// Native Liquid Glass in `shape`; a system material before macOS 26 and
    /// a solid dark fill with Reduce Transparency.
    @ViewBuilder
    private func glass(_ shape: some Shape) -> some View {
        if reduceTransparency {
            shape.fill(Color(white: 0.13))
        } else {
#if compiler(>=6.2)
            if #available(macOS 26, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                fallback(shape, tint: nil)
            }
#else
            fallback(shape, tint: nil)
#endif
        }
    }

    private func fallback(_ shape: some Shape, tint: Color?) -> some View {
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(tint ?? .clear))
    }
}

/// A ring: the outer circle with the inner one cut out (drawn the other way
/// round, so both a fill and the glass leave the hole clear).
struct QuickRingAnnulus: Shape {
    let inner: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        path.closeSubpath()
        path.move(to: CGPoint(x: center.x + inner, y: center.y))
        path.addArc(center: center, radius: inner, startAngle: .zero, endAngle: .degrees(-360), clockwise: true)
        path.closeSubpath()
        return path
    }
}
