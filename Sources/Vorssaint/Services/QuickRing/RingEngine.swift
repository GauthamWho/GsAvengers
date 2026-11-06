// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit

/// Pure slice math shared by the ring view and the pointer tracking. Slice 0
/// sits at 12 o'clock and indices grow clockwise.
enum RadialMenuGeometry {
    static func angle(dx: CGFloat, dyUp: CGFloat) -> CGFloat {
        let raw = atan2(dx, dyUp)
        return raw < 0 ? raw + 2 * .pi : raw
    }

    static func index(forAngle angle: CGFloat, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        let step = 2 * .pi / CGFloat(itemCount)
        let shifted = (angle + step / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let index = Int(shifted / step)
        return min(max(index, 0), itemCount - 1)
    }

    /// The slice under the pointer, nil inside the dead zone around the hub.
    static func highlightedIndex(dx: CGFloat, dyUp: CGFloat,
                                 deadZoneRadius: CGFloat, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        let distance = (dx * dx + dyUp * dyUp).squareRoot()
        guard distance >= deadZoneRadius else { return nil }
        return index(forAngle: angle(dx: dx, dyUp: dyUp), itemCount: itemCount)
    }

    /// Unit-circle position of a slice center, dyUp toward the screen top.
    static func unitPosition(index: Int, itemCount: Int) -> (dx: CGFloat, dyUp: CGFloat) {
        guard itemCount > 0 else { return (0, 1) }
        let theta = 2 * .pi * CGFloat(index) / CGFloat(itemCount)
        return (sin(theta), cos(theta))
    }
}

enum WheelMotion {
    static var isEnabled: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Ordered while still transparent, so the wheel is never seen at full
    /// strength for a frame before the fade starts.
    static func present(_ panel: NSPanel) {
        panel.ignoresMouseEvents = false
        guard isEnabled else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            panel.makeKey()
            return
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    /// Fades out, then hands back so the caller can order the panel away:
    /// only the caller knows whether a new session claimed it meanwhile.
    ///
    /// The keyboard is given back on the first frame, not the last. This panel
    /// takes key status without activating the app, and closing it is usually
    /// the prelude to typing into whatever is underneath; a window that is
    /// only fading out must not eat that. Ordering out and straight back in is
    /// what drops key status, and the pair lands in a single commit, so
    /// nothing blinks.
    static func dismiss(_ panel: NSPanel, completion: @escaping () -> Void) {
        guard isEnabled, panel.isVisible else {
            completion()
            return
        }
        if panel.isKeyWindow {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.13
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { completion() }
    }
}

/// The bookkeeping a fading wheel needs: only one closing at a time, and a
/// closing that a new summon overtook must never order the panel away
/// underneath it.
final class PanelDismissal {
    /// True while the panel is only a picture: its monitors and its keyboard
    /// are already gone, so the wheel counts as closed from here.
    private(set) var isActive = false
    private var token = 0

    /// Fades the panel away and orders it out, then runs `finish` once, unless
    /// a new session claimed the panel first.
    func begin(_ panel: NSPanel, finish: @escaping () -> Void) {
        isActive = true
        token &+= 1
        let started = token
        WheelMotion.dismiss(panel) { [weak self] in
            guard let self, self.isActive, self.token == started else { return }
            self.isActive = false
            panel.orderOut(nil)
            finish()
        }
    }

    /// A new summon takes the panel back, so the closing it interrupted
    /// finishes here and now instead of landing on the new one.
    func cancel(finish: () -> Void) {
        guard isActive else { return }
        isActive = false
        token &+= 1
        finish()
    }
}
