// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import AppKit
import SwiftUI

/// The Quick Ring: a segmented ring of quick actions — Liquid Glass on
/// macOS 26, solid charcoal otherwise. Each action is its own wedge that
/// carries its icon and its name together; the wedge under the pointer lights
/// up. Selection is by direction, so the picture and the pick are one shape —
/// point at a tile and you already know what it is and that it is chosen.
struct QuickRingView: View {
    @ObservedObject private var service = QuickRingService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// The same rule as the clipboard panel: glass where the system offers it
    /// and the user hasn't asked for less transparency.
    private var usesGlass: Bool { useGlass && !reduceTransparency }
    private var hairlineColor: Color { usesGlass ? .white.opacity(0.16) : Self.hairline }

    private static let accent = Color(red: 0.20, green: 0.50, blue: 1.0)
    private static let recordRed = Color(red: 1.0, green: 0.30, blue: 0.26)
    /// Idle tile: a calm charcoal that reads on any wallpaper.
    private static let tile = Color(white: 0.16)
    /// The ring body showing through the gaps as thin separator lines.
    private static let grout = Color(white: 0.07)
    private static let hairline = Color.white.opacity(0.10)

    var body: some View {
        let strings = FeatureStrings.quickRing(l10n.language)
        ZStack {
            // Invisible, but solid to the window server: a click in the middle
            // closes the ring instead of falling through to the app beneath.
            Circle()
                .fill(Color.black.opacity(0.004))
                .frame(width: QuickRingLayout.innerRadius * 2, height: QuickRingLayout.innerRadius * 2)
                .accessibilityHidden(true)
            content(strings)
        }
        .frame(width: QuickRingLayout.panelSize, height: QuickRingLayout.panelSize)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.title)
    }

    private func content(_ strings: QuickRingStrings) -> some View {
        let outer = QuickRingLayout.outerRadius
        let inner = QuickRingLayout.innerRadius
        let count = service.entries.count
        return ZStack {
            // Depth as a blurred circle, never a .shadow on the framed annulus:
            // that shadow rasterizes from the frame's rectangle and paints a
            // grey plate around the ring. A circle can only ever be round.
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: outer * 2 - 16, height: outer * 2 - 16)
                .blur(radius: 12)
                .offset(y: 5)
                .accessibilityHidden(true)

            // One dark annulus as the body; the gaps between the wedges show
            // through it as clean separator lines.
            ringBody(outer: outer, inner: inner)

            // A wedge per action, inset a hair so the body reads as grout.
            ForEach(Array(service.entries.enumerated()), id: \.offset) { index, entry in
                wedge(index: index, count: count, inner: inner, outer: outer)
                    .fill(fill(for: entry, highlighted: service.highlightedIndex == index))
                    .frame(width: outer * 2, height: outer * 2)
                    .overlay {
                        wedge(index: index, count: count, inner: inner, outer: outer)
                            .stroke(hairlineColor, lineWidth: 1)
                            .frame(width: outer * 2, height: outer * 2)
                    }
            }

            // Icon and name together, upright, at each wedge's centre.
            ForEach(Array(service.entries.enumerated()), id: \.offset) { index, entry in
                label(entry, strings: strings, highlighted: service.highlightedIndex == index)
                    .offset(offset(index, count: count))
            }
        }
    }

    /// The ring's body: Liquid Glass with a dark veil so the white icons hold
    /// their contrast on any wallpaper, or the solid charcoal when glass is
    /// off. No .shadow anywhere near it — depth comes from the blurred circle.
    @ViewBuilder
    private func ringBody(outer: CGFloat, inner: CGFloat) -> some View {
        let annulus = QuickRingAnnulus(inner: inner)
        let side = outer * 2
        if #available(macOS 26.0, *), usesGlass {
            annulus.fill(Color.clear)
                .frame(width: side, height: side)
                .glassEffect(.regular, in: annulus)
                .overlay(annulus.fill(Color.black.opacity(0.42)).frame(width: side, height: side))
                .overlay(annulus.stroke(hairlineColor, lineWidth: 1).frame(width: side, height: side))
        } else {
            annulus.fill(Self.grout)
                .frame(width: side, height: side)
        }
    }

    // MARK: - Geometry

    private func offset(_ index: Int, count: Int) -> CGSize {
        let unit = RadialMenuGeometry.unitPosition(index: index, itemCount: count)
        // SwiftUI's y grows downward.
        return CGSize(width: unit.dx * QuickRingLayout.itemRadius, height: -unit.dyUp * QuickRingLayout.itemRadius)
    }

    /// The annular sector for one action. Slice 0 sits at 12 o'clock and indices
    /// grow clockwise, exactly like the pointer's pick. A few degrees of gap
    /// either side leave the grout line.
    private func wedge(index: Int, count: Int, inner: CGFloat, outer: CGFloat) -> QuickRingWedge {
        let span = 360.0 / Double(max(count, 1))
        let gap = 3.0
        let center = -90.0 + span * Double(index)
        let half = span / 2 - gap / 2
        let inset: CGFloat = 2
        return QuickRingWedge(inner: inner + inset, outer: outer - inset,
                              start: .degrees(center - half), end: .degrees(center + half))
    }

    private func fill(for entry: QuickRingEntry, highlighted: Bool) -> Color {
        if highlighted {
            let tint = entry.item == .stopRecording ? Self.recordRed : Self.accent
            return usesGlass ? tint.opacity(0.9) : tint
        }
        // On glass the material itself is the idle tile; the hairlines draw
        // the segments.
        return usesGlass ? .clear : Self.tile
    }

    // MARK: - Item label

    /// Icon above its name, both upright so they read at a glance. The whole
    /// tile lifts a touch when pointed; the name never hides in the middle.
    private func label(_ entry: QuickRingEntry, strings: QuickRingStrings, highlighted: Bool) -> some View {
        let isStop = entry.item == .stopRecording
        let symbolColor: Color = isStop && !highlighted ? Self.recordRed : .white
        return VStack(spacing: 4) {
            Image(systemName: entry.item.symbolName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(symbolColor)
            Text(entry.item.title(strings))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(highlighted ? 1 : 0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 72)
        .scaleEffect(highlighted && !reduceMotion ? 1.06 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.8), value: highlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.item.title(strings))
        .accessibilityAddTraits(entry.isCurrent ? [.isButton, .isSelected] : .isButton)
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

/// One tile of the ring: the sector of an annulus between two angles. Angles
/// run clockwise from 3 o'clock in SwiftUI's y-down space; the view maps slice
/// 0 to the top (-90°). The outer arc goes forward, the inner arc back, so the
/// two meet into a closed wedge with a clear hole.
struct QuickRingWedge: Shape {
    let inner: CGFloat
    let outer: CGFloat
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
