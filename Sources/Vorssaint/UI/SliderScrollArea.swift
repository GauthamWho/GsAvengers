// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Enabled level controls receive the wheel before an enclosing horizontal strip.
protocol SliderScrollTarget: AnyObject {
    var acceptsSliderScroll: Bool { get }
}

/// A scroll over a level slider moves it, so it can be set without dragging.
/// Up and right raise it whichever way content scrolls. A wheel notch is one
/// step, like a volume key; a trackpad moves it with the fingers. A trackpad
/// gesture belongs to the slider only when it starts there: a list scrolling
/// under a still pointer keeps scrolling, and the momentum of a flick that
/// moved the slider is swallowed rather than moving it or the list.
struct SliderScroll {
    enum Phase { case none, began, changed, ended, momentum }
    enum Outcome: Equatable { case pass, hold, move(Double) }

    static let wheelStep = 0.05
    /// Two hundred points of finger travel cross the whole range.
    static let pointStep = 0.005
    /// Trackpads may send one phaseless event between the lift and momentum.
    static let liftGap = 0.35

    /// Where the gesture on the bar is heading, ahead of a level that settles late.
    private var level: Double?
    private var coasting = false
    private var liftedAt: Double?

    static func step(dx: Double, dy: Double, precise: Bool, inverted: Bool) -> Double {
        let up = dy * (inverted ? -1 : 1)
        let right = dx * (inverted ? 1 : -1)
        let amount = abs(dx) > abs(dy) ? right : up
        guard amount.isFinite, amount != 0 else { return 0 }
        return precise ? amount * pointStep : (amount > 0 ? wheelStep : -wheelStep)
    }

    mutating func handle(_ phase: Phase, dx: Double, dy: Double, precise: Bool, inverted: Bool,
                         timestamp: Double, current: Double, range: ClosedRange<Double>) -> Outcome {
        switch phase {
        case .began:
            level = current
            coasting = false
        case .changed:
            guard level != nil else { coasting = false; return .pass }
        case .ended:
            guard level != nil else { return .pass }
            level = nil
            coasting = true
            liftedAt = timestamp
            return .hold
        case .momentum:
            return coasting ? .hold : .pass
        case .none:
            if coasting, precise, let liftedAt, timestamp >= liftedAt, timestamp - liftedAt <= Self.liftGap {
                return .hold
            }
            coasting = false
        }
        let span = range.upperBound - range.lowerBound
        let step = Self.step(dx: dx, dy: dy, precise: precise, inverted: inverted)
        guard span.isFinite, span > 0, step != 0 else { return .hold }
        let base = (level ?? current).isFinite ? (level ?? current) : range.lowerBound
        let next = min(range.upperBound, max(range.lowerBound, base + step * span))
        if level != nil { level = next }
        return .move(next)
    }
}

extension SliderScroll {
    mutating func handle(_ event: NSEvent, current: Double, range: ClosedRange<Double>) -> Outcome {
        let phase: Phase
        if !event.momentumPhase.isEmpty { phase = .momentum }
        else if event.phase.contains(.began) { phase = .began }
        else if !event.phase.intersection([.changed, .stationary]).isEmpty { phase = .changed }
        else if event.phase.isEmpty { phase = .none }
        else { phase = .ended }
        return handle(phase, dx: Double(event.scrollingDeltaX), dy: Double(event.scrollingDeltaY),
                      precise: event.hasPreciseScrollingDeltas, inverted: event.isDirectionInvertedFromDevice,
                      timestamp: event.timestamp, current: current, range: range)
    }

    /// A scroll the bar does not take goes on to the list around it.
    static func pass(_ event: NSEvent, from view: NSView) {
        if let scroll = view.enclosingScrollView { scroll.scrollWheel(with: event) }
        else { view.nextResponder?.scrollWheel(with: event) }
    }
}

/// Laid over a SwiftUI slider, it takes only scroll events; clicks and drags
/// reach the slider underneath.
struct SliderScrollArea: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>

    func makeNSView(context: Context) -> AreaView { AreaView() }

    func updateNSView(_ view: AreaView, context: Context) {
        view.area = self
        view.isEnabled = context.environment.isEnabled
    }

    final class AreaView: NSView, SliderScrollTarget {
        var area: SliderScrollArea?
        var isEnabled = true
        var acceptsSliderScroll: Bool { isEnabled && area != nil }
        private var scroll = SliderScroll()

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard NSApp.currentEvent?.type == .scrollWheel else { return nil }
            return super.hitTest(point)
        }

        override func scrollWheel(with event: NSEvent) {
            guard let area, isEnabled else { return SliderScroll.pass(event, from: self) }
            switch scroll.handle(event, current: area.value, range: area.range) {
            case .pass: SliderScroll.pass(event, from: self)
            case .hold: break
            case .move(let value): area.value = value
            }
        }
    }
}
