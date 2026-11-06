// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import CoreGraphics
import Foundation

/// One action on the Quick Ring. Record and Stop are the same slot in two
/// states, so the ring never grows a dead button.
enum QuickRingItem: String, CaseIterable {
    case capture, record, stopRecording, clipboard, windows

    var symbolName: String {
        switch self {
        case .capture: return "camera.viewfinder"
        case .record: return "record.circle"
        case .stopRecording: return "stop.circle"
        case .clipboard: return "doc.on.clipboard"
        case .windows: return "rectangle.on.rectangle"
        }
    }

    func title(_ s: QuickRingStrings) -> String {
        switch self {
        case .capture: return s.capture
        case .record: return s.record
        case .stopRecording: return s.stop
        case .clipboard: return s.clipboard
        case .windows: return s.windows
        }
    }

    /// Whether the action photographs or covers the screen, so it waits for
    /// the ring to be gone first.
    var waitsForRingToLeave: Bool { self == .capture || self == .record }
}

/// What the ring needs to know when it opens. Read once per opening; the
/// ring closes on every pick, so it never has to follow a change live.
struct QuickRingContext: Equatable {
    var recording: Bool
    var screenshotAvailable: Bool
    var recorderAvailable: Bool
    var clipboardAvailable: Bool
}

struct QuickRingEntry: Equatable {
    let item: QuickRingItem
    /// Shown lit: a recording in progress.
    let isCurrent: Bool
}

enum QuickRingSupport {
    /// Most actions the ring ever holds; the number keys 1–4 match them.
    static let maxItems = 4

    /// Clockwise from 12 o'clock: capture, record, clipboard, windows. Tools
    /// whose feature is uninstalled leave no slot, so a smaller ring is
    /// simply a smaller ring.
    static func entries(for context: QuickRingContext) -> [QuickRingEntry] {
        var entries: [QuickRingEntry] = []
        if context.screenshotAvailable {
            entries.append(QuickRingEntry(item: .capture, isCurrent: false))
        }
        if context.recorderAvailable {
            entries.append(QuickRingEntry(item: context.recording ? .stopRecording : .record,
                                          isCurrent: context.recording))
        }
        if context.clipboardAvailable {
            entries.append(QuickRingEntry(item: .clipboard, isCurrent: false))
        }
        entries.append(QuickRingEntry(item: .windows, isCurrent: false))
        return Array(entries.prefix(maxItems))
    }
}

/// The ring's size in points. The panel is a margin wider than the ring so
/// its soft shadow fades out instead of being cut square.
enum QuickRingLayout {
    static let itemDiameter: CGFloat = 52
    /// Centre of the ring to the centre of each button: four 52 pt buttons
    /// round a 70 pt radius, whose inner edges meet the clear hole.
    static let itemRadius: CGFloat = 70
    /// The glass ring's outer edge, a few points past the buttons.
    static let outerRadius: CGFloat = itemRadius + itemDiameter / 2 + 6
    /// The clear hole in the middle, where the pointer rests and nothing is
    /// picked (it is also the dead zone for pointing).
    static let innerRadius: CGFloat = 44
    /// Room round the ring for the glass's own shadow.
    static let shadowMargin: CGFloat = 26
    static let panelSize: CGFloat = (outerRadius + shadowMargin) * 2
    /// Gap kept between the ring and the screen's edge.
    static let edgeMargin: CGFloat = 8
    /// Pointer travel from the centre that closes the ring: well past the
    /// ring, so reaching for an outer button never closes it.
    static let dismissDistance: CGFloat = outerRadius + 150
}

/// Where the ring opens: on the pointer, with its centre pushed inward just
/// enough that the whole ring stays on the screen the pointer is on.
enum QuickRingPlacement {
    static func center(pointer: CGPoint, visibleFrame frame: CGRect,
                       radius: CGFloat = QuickRingLayout.outerRadius,
                       margin: CGFloat = QuickRingLayout.edgeMargin) -> CGPoint {
        let reach = radius + margin
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            // A screen too small for the ring centres it on that axis.
            low > high ? (low + high) / 2 : min(max(value, low), high)
        }
        return CGPoint(x: clamp(pointer.x, frame.minX + reach, frame.maxX - reach),
                       y: clamp(pointer.y, frame.minY + reach, frame.maxY - reach))
    }

    /// The button under the pointer: inside the ring's band (from the hole to
    /// just past the outer edge), by direction. Nil in the hole or outside.
    static func highlightedIndex(pointer: CGPoint, center: CGPoint, itemCount: Int) -> Int? {
        let dx = pointer.x - center.x
        let dyUp = pointer.y - center.y
        let distance = (dx * dx + dyUp * dyUp).squareRoot()
        guard distance <= QuickRingLayout.outerRadius + 12 else { return nil }
        return RadialMenuGeometry.highlightedIndex(dx: dx, dyUp: dyUp,
                                                   deadZoneRadius: QuickRingLayout.innerRadius,
                                                   itemCount: itemCount)
    }
}

/// Double-tap ⌃ Control, from modifier changes alone: two clean taps (Control
/// by itself, pressed briefly) close together. Any other key, click or
/// modifier in between starts over, and a held Control never counts, so
/// ⌃-typing, ⌃-click (the ring's own mouse trigger) and ⌃-drag never open it.
struct QuickRingDoubleTap {
    /// Longest press that still counts as a tap.
    static let maxHold: TimeInterval = 0.25
    /// Longest gap from the first tap's release to the second press.
    static let maxGap: TimeInterval = 0.30

    private var pressedAt: TimeInterval?
    private var lastTapReleasedAt: TimeInterval?

    /// Control went down or up. `otherModifiers` is any of ⌘ ⌥ ⇧ or Fn held
    /// with it. `interrupted` is true when a key or click went by while it
    /// was down that the tap itself could not hear (a system shortcut such
    /// as ⌃→ never reaches it). True when this release completes a double tap.
    mutating func controlChanged(isDown: Bool, otherModifiers: Bool, interrupted: Bool = false,
                                 at time: TimeInterval) -> Bool {
        guard !otherModifiers else {
            interrupt()
            return false
        }
        if isDown {
            if let last = lastTapReleasedAt, time - last > Self.maxGap { lastTapReleasedAt = nil }
            pressedAt = time
            return false
        }
        guard let pressed = pressedAt else { return false }
        pressedAt = nil
        guard !interrupted, time - pressed <= Self.maxHold, time >= pressed else {
            lastTapReleasedAt = nil
            return false
        }
        if let last = lastTapReleasedAt, pressed - last <= Self.maxGap, pressed >= last {
            lastTapReleasedAt = nil
            return true
        }
        lastTapReleasedAt = time
        return false
    }

    /// A key, a click or another modifier: whatever Control was doing, it was
    /// not a clean tap.
    mutating func interrupt() {
        pressedAt = nil
        lastTapReleasedAt = nil
    }
}

/// How the ring opens: a double-tap of ⌃ Control.
enum QuickRingTrigger: CaseIterable {
    case controlDoubleTap

    var defaultsKey: String { DefaultsKey.quickRingControlDoubleTap }
}
