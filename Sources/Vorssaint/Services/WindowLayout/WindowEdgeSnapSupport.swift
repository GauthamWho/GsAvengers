// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum WindowEdgeDragClassification: Equatable {
    case waiting
    case moving
    case resizing
    case unrelated
}

struct WindowEdgeSnapScreen: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
}

/// The eight drop zones around the screen: four corners and four edges, each
/// edge holding one or more areas. Raw values are persisted, so they stay
/// stable even if the visual arrangement changes later.
enum WindowEdgeSnapZone: String, CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight

    /// What the area does until someone picks another placement for it.
    var defaultAction: WindowLayoutAction {
        switch self {
        case .topLeft: return .topLeft
        case .top: return .maximize
        case .topRight: return .topRight
        case .left: return .leftHalf
        case .right: return .rightHalf
        case .bottomLeft: return .bottomLeft
        case .bottom: return .bottomHalf
        case .bottomRight: return .bottomRight
        }
    }

    /// The top and bottom edges split into areas side by side, the left and
    /// right edges into areas stacked from top to bottom. A corner is always
    /// one area.
    var isHorizontalEdge: Bool { self == .top || self == .bottom }
    var isVerticalEdge: Bool { self == .left || self == .right }

    var maximumParts: Int {
        isHorizontalEdge || isVerticalEdge ? WindowEdgeSnapLayout.maximumParts : 1
    }

    static let allEnabled = Set(allCases)

    static func disabledZones(from storedValue: String?) -> Set<WindowEdgeSnapZone> {
        guard let storedValue else { return [] }
        return Set(storedValue.split(separator: ",").compactMap {
            WindowEdgeSnapZone(rawValue: $0.trimmingCharacters(in: .whitespaces))
        })
    }

    static func disabledZonesStorageValue(_ zones: Set<WindowEdgeSnapZone>) -> String {
        allCases.filter(zones.contains).map(\.rawValue).joined(separator: ",")
    }

    static func enabledZones(from storedValue: String?) -> Set<WindowEdgeSnapZone> {
        allEnabled.subtracting(disabledZones(from: storedValue))
    }
}

/// The placements a drop area can use, in the families Settings lists them
/// in. Each one fills a fixed part of the screen, so a drag can preview it.
/// Center, full screen, restore and the display moves depend on the window or
/// leave the screen, so they are left out.
enum WindowEdgeSnapPlacementGroup: CaseIterable {
    case halves, thirds, quarterRows, quarterColumns, sixths, corners, other

    var actions: [WindowLayoutAction] {
        switch self {
        case .halves:
            return [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerHalf]
        case .thirds:
            return [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .centerTwoThirds,
                    .topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds]
        case .quarterRows:
            return [.topQuarter, .upperMiddleQuarter, .lowerMiddleQuarter, .bottomQuarter]
        case .quarterColumns:
            return [.leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter]
        case .sixths:
            return [.topLeftSixth, .topCenterSixth, .topRightSixth,
                    .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth]
        case .corners:
            return [.topLeft, .topRight, .bottomLeft, .bottomRight]
        case .other:
            return [.maximize, .marginMaximize]
        }
    }

    func title(_ text: WindowLayoutFeatureStrings) -> String {
        switch self {
        case .halves: return text.halves
        case .thirds: return text.thirds
        case .quarterRows: return text.quarterRows
        case .quarterColumns: return text.quarterColumns
        case .sixths: return text.sixths
        case .corners: return text.corners
        case .other: return text.other
        }
    }

    static let placements = Set(allCases.flatMap(\.actions))
}

/// What each drop area does. A corner holds one placement, and a straight
/// edge holds one for each area it is split into, from left to right or from
/// top to bottom. Only areas changed from their default are stored, as
/// `zone=action` entries with `+` between the areas of a split edge.
struct WindowEdgeSnapLayout: Equatable {
    static let maximumParts = 4
    static let standard = WindowEdgeSnapLayout()

    private var changed: [WindowEdgeSnapZone: [WindowLayoutAction]] = [:]

    init() {}

    /// An entry with an unknown zone or placement, a placement an area cannot
    /// use or too many areas is dropped, so that zone keeps its default and a
    /// value written by a newer version never breaks the others.
    init(storageValue: String?) {
        for entry in (storageValue ?? "").split(separator: ",") {
            let pair = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2,
                  let zone = WindowEdgeSnapZone(rawValue: pair[0].trimmingCharacters(in: .whitespaces))
            else { continue }
            let names = pair[1].split(separator: "+", omittingEmptySubsequences: false)
            let actions = names.compactMap {
                WindowLayoutAction(rawValue: $0.trimmingCharacters(in: .whitespaces))
            }
            guard actions.count == names.count, Self.accepts(actions, for: zone) else { continue }
            set(actions, for: zone)
        }
    }

    var storageValue: String {
        WindowEdgeSnapZone.allCases.compactMap { zone in
            changed[zone].map { zone.rawValue + "=" + $0.map(\.rawValue).joined(separator: "+") }
        }.joined(separator: ",")
    }

    func actions(for zone: WindowEdgeSnapZone) -> [WindowLayoutAction] {
        changed[zone] ?? [zone.defaultAction]
    }

    /// The placement at a point along the edge between its corners, given as
    /// a fraction from its left or top end.
    func action(for zone: WindowEdgeSnapZone, along fraction: CGFloat) -> WindowLayoutAction {
        let actions = actions(for: zone)
        let position = fraction.isFinite ? min(max(fraction, 0), 1) : 0
        let index = Int((position * CGFloat(actions.count)).rounded(.down))
        return actions[min(index, actions.count - 1)]
    }

    mutating func setAction(_ action: WindowLayoutAction, for zone: WindowEdgeSnapZone, part: Int) {
        var actions = actions(for: zone)
        guard actions.indices.contains(part) else { return }
        actions[part] = action
        guard Self.accepts(actions, for: zone) else { return }
        set(actions, for: zone)
    }

    /// A split edge starts with the screen's equal columns along the top or
    /// bottom, or its equal rows along a side, so each area places the window
    /// in the column or row it sits on. Going back to one area brings the
    /// default back, and picking the count an edge already has keeps its
    /// placements.
    mutating func setPartCount(_ count: Int, for zone: WindowEdgeSnapZone) {
        guard count != actions(for: zone).count else { return }
        let parts: [WindowLayoutAction]
        switch (count, zone.isHorizontalEdge) {
        case (1, _): parts = [zone.defaultAction]
        case (2, true): parts = [.leftHalf, .rightHalf]
        case (3, true): parts = [.leftThird, .centerThird, .rightThird]
        case (4, true): parts = [.leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter]
        case (2, false): parts = [.topHalf, .bottomHalf]
        case (3, false): parts = [.topThird, .middleThird, .bottomThird]
        case (4, false): parts = [.topQuarter, .upperMiddleQuarter, .lowerMiddleQuarter, .bottomQuarter]
        default: return
        }
        guard parts.count <= zone.maximumParts else { return }
        set(parts, for: zone)
    }

    /// Where a placement puts a window on a 16:10 screen, as fractions of it
    /// measured from the top left, for the map in Settings to draw.
    static func previewRect(for action: WindowLayoutAction) -> CGRect {
        let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let rect = WindowLayoutGeometry.rect(for: action, current: screen, visibleFrame: screen)
        return CGRect(x: rect.minX / screen.width,
                      y: (screen.maxY - rect.maxY) / screen.height,
                      width: rect.width / screen.width,
                      height: rect.height / screen.height)
    }

    private mutating func set(_ actions: [WindowLayoutAction], for zone: WindowEdgeSnapZone) {
        changed[zone] = actions == [zone.defaultAction] ? nil : actions
    }

    private static func accepts(_ actions: [WindowLayoutAction], for zone: WindowEdgeSnapZone) -> Bool {
        !actions.isEmpty && actions.count <= zone.maximumParts
            && actions.allSatisfy(WindowEdgeSnapPlacementGroup.placements.contains)
    }
}

struct WindowEdgeSnapTarget: Equatable {
    let zone: WindowEdgeSnapZone
    let action: WindowLayoutAction
    let frame: CGRect
    let visibleFrame: CGRect
}

/// The pointer's recent path during a drag, kept just long enough to tell
/// how fast it is moving. One event can follow another by a millisecond, so
/// speed is read over a short span rather than between two events.
struct WindowEdgeSnapPointerTrail {
    /// How far back the speed reaches.
    static let span: TimeInterval = 0.05
    /// The least time a reading divides by. A mouse can report every
    /// millisecond, and the point it nudges while its button comes up must
    /// not read as a crossing.
    static let minimumSpan: TimeInterval = 0.02
    /// A pointer with no event for this long has stopped, whatever its last
    /// speed was.
    static let stillAfter: TimeInterval = 0.1
    /// The most samples kept. The span ages samples out only while event
    /// times move on, and this covers it even at 8000 Hz polling.
    static let capacity = 512

    private var samples: [(time: TimeInterval, point: CGPoint)] = []

    /// When the newest sample was taken, or nil while the trail is empty.
    var lastTime: TimeInterval? { samples.last?.time }

    mutating func append(_ point: CGPoint, at time: TimeInterval) {
        if let last = samples.last {
            if time < last.time {
                samples.removeAll()
            } else if time - last.time >= Self.stillAfter {
                // After a pause the path starts again from where the pointer
                // rested, as if it set off within the shortest span, so the
                // stop is not averaged in and a flick out of it reads fast.
                samples = [(time - Self.minimumSpan, last.point)]
            }
        }
        samples.append((time, point))
        // One sample from before the span stays as its starting point.
        while samples.count > 2, time - samples[1].time >= Self.span {
            samples.removeFirst()
        }
        if samples.count > Self.capacity {
            samples.removeFirst(samples.count - Self.capacity)
        }
    }

    mutating func reset() {
        samples.removeAll()
    }

    /// Points per second, in the coordinates the points were given in.
    func velocity(at now: TimeInterval) -> CGVector {
        guard samples.count > 1, let last = samples.last, let first = samples.first,
              now - last.time < Self.stillAfter else { return .zero }
        let elapsed = max(last.time - first.time, Self.minimumSpan)
        return CGVector(dx: (last.point.x - first.point.x) / elapsed,
                        dy: (last.point.y - first.point.y) / elapsed)
    }
}

enum WindowEdgeSnapSupport {
    /// Movement below this many points is a click, not a drag.
    static let dragSlop: CGFloat = 4

    static func exceedsDragSlop(from origin: CGPoint, to point: CGPoint) -> Bool {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        return (dx * dx + dy * dy).squareRoot() > dragSlop
    }

    static let activationDistance: CGFloat = 12
    static let resizeCornerDistance: CGFloat = 12
    static let resizeEdgeDistance: CGFloat = 5
    /// Points per second across an edge, above which the pointer is passing
    /// rather than aiming. Tuned by hand against macOS tiling.
    static let crossingSpeed: CGFloat = 400
    static let desktopAndDockSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension"
    )!
    private static let systemTilingKeys = [
        "EnableTilingByEdgeDrag",
        "EnableTilingOptionAccelerator",
        "EnableTopTilingByEdgeDrag",
    ]
    private static let movementThreshold: CGFloat = 2
    private static let sizeTolerance: CGFloat = 2

    static var isSystemTilingEnabled: Bool {
        guard #available(macOS 15.0, *),
              let defaults = UserDefaults(suiteName: "com.apple.WindowManager") else { return false }
        return systemTilingEnabled(
            valueFor: { key in
                guard defaults.object(forKey: key) != nil else { return nil }
                return defaults.bool(forKey: key)
            },
            displaysSpan: displaysSpan(spacesPreference("spans-displays"))
        )
    }

    /// The system's edge tiling choices arrive enabled when their preference
    /// has never been written. Keeping this pure makes the conflict gate
    /// testable without changing somebody's desktop settings.
    ///
    /// When displays span (Separate Spaces off) those switches are greyed
    /// out and the system's own tiling is inert, even if a key was written
    /// as enabled. The warning's instruction is unreachable then (issue #1079).
    static func systemTilingEnabled(valueFor: (String) -> Bool?,
                                    displaysSpan: Bool = false) -> Bool {
        if displaysSpan { return false }
        return systemTilingKeys.contains { valueFor($0) ?? true }
    }

    /// Separate Spaces off is the only configuration where displays span.
    /// An absent preference is Apple's default: one Space per display.
    static func displaysSpan(_ value: Bool?) -> Bool {
        value ?? false
    }

    private static func spacesPreference(_ key: String) -> Bool? {
        guard let defaults = UserDefaults(suiteName: "com.apple.spaces") else { return nil }
        return defaults.object(forKey: key).map { _ in defaults.bool(forKey: key) }
    }

    static var isSystemTopWindowOverviewDragEnabled: Bool {
        guard #available(macOS 15.0, *) else { return true }
        guard let defaults = UserDefaults(suiteName: "com.apple.dock") else { return true }
        let key = "enterMissionControlByTopWindowDrag"
        let value = defaults.object(forKey: key).map { _ in defaults.bool(forKey: key) }
        return systemTopWindowOverviewDragEnabled(value: value)
    }

    /// The top-edge gesture also arrives enabled before its preference is
    /// written. The event tap keeps a confirmed window drag away from the
    /// physical top while edge snapping uses the menu bar's lower boundary.
    static func systemTopWindowOverviewDragEnabled(value: Bool?) -> Bool {
        value ?? true
    }

    /// Keeps a confirmed window drag one point inside the display while the
    /// pointer is pressed against its top edge. The snap target still sees the
    /// edge, but the system never receives the exact coordinate that opens its
    /// window overview. Callers must only use this after proving that a window,
    /// rather than content inside it, is moving.
    static func locationAvoidingSystemTopDrag(_ point: CGPoint,
                                              screenFrames: [CGRect],
                                              enabledZones: Set<WindowEdgeSnapZone> =
                                                  WindowEdgeSnapZone.allEnabled) -> CGPoint {
        guard let screen = screenFrames.first(where: {
            point.x >= $0.minX && point.x <= $0.maxX
                && abs(point.y - $0.minY) < 0.5
        }), enabledZones.contains(topZone(atX: point.x, in: screen)) else { return point }
        return CGPoint(x: point.x, y: screen.minY + 1)
    }

    static func startsAtResizeHandle(_ point: CGPoint,
                                     frame: CGRect) -> Bool {
        guard point.x >= frame.minX - resizeCornerDistance,
              point.x <= frame.maxX + resizeCornerDistance,
              point.y >= frame.minY - resizeCornerDistance,
              point.y <= frame.maxY + resizeCornerDistance else { return false }
        let nearVerticalCorner = abs(point.x - frame.minX) <= resizeCornerDistance
            || abs(point.x - frame.maxX) <= resizeCornerDistance
        let nearHorizontalCorner = abs(point.y - frame.minY) <= resizeCornerDistance
            || abs(point.y - frame.maxY) <= resizeCornerDistance
        let nearEdge = abs(point.x - frame.minX) <= resizeEdgeDistance
            || abs(point.x - frame.maxX) <= resizeEdgeDistance
            || abs(point.y - frame.minY) <= resizeEdgeDistance
            || abs(point.y - frame.maxY) <= resizeEdgeDistance
        return nearEdge || (nearVerticalCorner && nearHorizontalCorner)
    }

    /// A pointer drag is only a window move after the same window follows it.
    /// Content drags leave the frame still, while native resizing keeps at
    /// least two frame edges anchored. Neither may turn into a placement just
    /// because the pointer ends at a screen edge. A tiled window restoring its
    /// old size while it starts moving is still a move.
    static func classify(initialFrame: CGRect,
                         currentFrame: CGRect,
                         pointerStart: CGPoint,
                         pointerNow: CGPoint) -> WindowEdgeDragClassification {
        let sizeChanged = abs(currentFrame.width - initialFrame.width) > sizeTolerance
            || abs(currentFrame.height - initialFrame.height) > sizeTolerance
        if sizeChanged, sharesPerpendicularEdges(initialFrame, currentFrame) {
            return .resizing
        }

        let windowDelta = CGPoint(x: currentFrame.minX - initialFrame.minX,
                                  y: currentFrame.minY - initialFrame.minY)
        let pointerDelta = CGPoint(x: pointerNow.x - pointerStart.x,
                                   y: pointerNow.y - pointerStart.y)
        let windowDistance = hypot(windowDelta.x, windowDelta.y)
        guard windowDistance > movementThreshold else { return .waiting }

        let pointerDistance = hypot(pointerDelta.x, pointerDelta.y)
        guard pointerDistance > movementThreshold else { return .unrelated }
        let alignment = (windowDelta.x * pointerDelta.x + windowDelta.y * pointerDelta.y)
            / (windowDistance * pointerDistance)
        let ratio = windowDistance / pointerDistance
        return alignment >= 0.6 && ratio >= 0.2 && ratio <= 1.8 ? .moving : .unrelated
    }

    /// Resolves the hot zone under an AppKit-coordinate pointer. Screen frames
    /// choose the reachable edge; visible frames keep the result clear of the
    /// menu bar and Dock.
    ///
    /// A seam two displays share counts only while the pointer is slow across
    /// it, the way macOS tiling tells aiming from passing: a window dragged
    /// through at speed crosses to the next display, and one slowed down
    /// there tiles. An edge with nothing beyond it is a wall that stops the
    /// pointer, so it counts at any speed, and a window flung at it and let
    /// go at once still tiles. Speed along an edge never counts, so sliding
    /// from a half to a corner keeps the preview.
    ///
    /// An edge split into areas divides its length between the corners
    /// equally, the way the map in Settings draws it.
    static func target(at point: CGPoint,
                       screens: [WindowEdgeSnapScreen],
                       velocity: CGVector = .zero,
                       distance: CGFloat = activationDistance,
                       enabledZones: Set<WindowEdgeSnapZone> =
                           WindowEdgeSnapZone.allEnabled,
                       layout: WindowEdgeSnapLayout = .standard) -> WindowEdgeSnapTarget? {
        let settledAcross = abs(velocity.dx) <= crossingSpeed
        let settledUpDown = abs(velocity.dy) <= crossingSpeed
        let frames = screens.map(\.frame)
        let ordered = screens.enumerated().sorted {
            let first = distanceSquared(from: point, to: $0.element.frame)
            let second = distanceSquared(from: point, to: $1.element.frame)
            guard first == second else { return first < second }
            // On a seam both displays are at distance zero. The one holding
            // the pointer wins, and an otherwise equal pair keeps the order
            // the system gave, which sorting alone does not promise.
            let holdsFirst = holds($0.element.frame, point)
            guard holdsFirst == holds($1.element.frame, point) else { return holdsFirst }
            return $0.offset < $1.offset
        }
        for (_, screen) in ordered {
            let frame = screen.frame
            guard frame.width > 0, frame.height > 0,
                  screen.visibleFrame.width > 0, screen.visibleFrame.height > 0,
                  point.x >= frame.minX - distance,
                  point.x <= frame.maxX + distance,
                  point.y >= frame.minY - distance,
                  point.y <= frame.maxY + distance
            else { continue }

            // Just past each edge, level with the pointer: another display
            // there makes the edge a seam.
            let open = { (probe: CGPoint) in frames.contains { $0 != frame && $0.contains(probe) } }
            let nearLeft = abs(point.x - frame.minX) <= distance
                && (settledAcross || !open(CGPoint(x: frame.minX - 0.5, y: point.y)))
            let nearRight = abs(point.x - frame.maxX) <= distance
                && (settledAcross || !open(CGPoint(x: frame.maxX + 0.5, y: point.y)))
            let visibleTop = min(max(screen.visibleFrame.maxY, frame.minY), frame.maxY)
            let nearTop = point.y >= visibleTop - distance && point.y <= frame.maxY + distance
                && (settledUpDown || !open(CGPoint(x: point.x, y: frame.maxY + 0.5)))
            let nearBottom = abs(point.y - frame.minY) <= distance
                && (settledUpDown || !open(CGPoint(x: point.x, y: frame.minY - 0.5)))
            guard nearLeft || nearRight || nearTop || nearBottom else { continue }

            let horizontalCorner = horizontalCornerWidth(for: frame)
            let verticalCorner = min(max(frame.height * 0.18, 80), 160)
            let zone: WindowEdgeSnapZone
            if nearTop {
                if point.x <= frame.minX + horizontalCorner {
                    zone = .topLeft
                } else if point.x >= frame.maxX - horizontalCorner {
                    zone = .topRight
                } else {
                    zone = .top
                }
            } else if nearBottom {
                if point.x <= frame.minX + horizontalCorner {
                    zone = .bottomLeft
                } else if point.x >= frame.maxX - horizontalCorner {
                    zone = .bottomRight
                } else {
                    zone = .bottom
                }
            } else if nearLeft {
                if point.y >= frame.maxY - verticalCorner {
                    zone = .topLeft
                } else if point.y <= frame.minY + verticalCorner {
                    zone = .bottomLeft
                } else {
                    zone = .left
                }
            } else {
                if point.y >= frame.maxY - verticalCorner {
                    zone = .topRight
                } else if point.y <= frame.minY + verticalCorner {
                    zone = .bottomRight
                } else {
                    zone = .right
                }
            }
            guard enabledZones.contains(zone) else { return nil }

            let along: CGFloat
            if zone.isHorizontalEdge {
                along = (point.x - frame.minX - horizontalCorner)
                    / max(frame.width - 2 * horizontalCorner, 1)
            } else if zone.isVerticalEdge {
                along = (frame.maxY - verticalCorner - point.y)
                    / max(frame.height - 2 * verticalCorner, 1)
            } else {
                along = 0
            }
            let action = layout.action(for: zone, along: along)
            let targetFrame = WindowLayoutGeometry.rect(for: action,
                                                        current: screen.visibleFrame,
                                                        visibleFrame: screen.visibleFrame,
                                                        windowGap: WindowLayoutGaps.windowGap,
                                                        screenGap: WindowLayoutGaps.screenGap,
                                                        marginPercent: WindowLayoutMargin.percent)
            return WindowEdgeSnapTarget(zone: zone,
                                        action: action,
                                        frame: targetFrame.integral,
                                        visibleFrame: screen.visibleFrame)
        }
        return nil
    }

    private static func horizontalCornerWidth(for frame: CGRect) -> CGFloat {
        min(max(frame.width * 0.18, 96), 180)
    }

    private static func topZone(atX x: CGFloat, in frame: CGRect) -> WindowEdgeSnapZone {
        let cornerWidth = horizontalCornerWidth(for: frame)
        if x <= frame.minX + cornerWidth { return .topLeft }
        if x >= frame.maxX - cornerWidth { return .topRight }
        return .top
    }

    private static func sharesPerpendicularEdges(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let sharesVerticalEdge = abs(lhs.minX - rhs.minX) <= sizeTolerance
            || abs(lhs.maxX - rhs.maxX) <= sizeTolerance
        let sharesHorizontalEdge = abs(lhs.minY - rhs.minY) <= sizeTolerance
            || abs(lhs.maxY - rhs.maxY) <= sizeTolerance
        return sharesVerticalEdge && sharesHorizontalEdge
    }

    /// Which display an AppKit coordinate belongs to. The pointer lives in
    /// Quartz space, where each display owns its left and top rows, so a seam
    /// coordinate belongs to the display on its right or, once y is flipped,
    /// to the one below it.
    private static func holds(_ frame: CGRect, _ point: CGPoint) -> Bool {
        point.x >= frame.minX && point.x < frame.maxX
            && point.y > frame.minY && point.y <= frame.maxY
    }

    private static func distanceSquared(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}

/// The pointer layout mode also accepts a held modifier chord. Ordinary global
/// shortcuts retain their key requirement and their existing storage format.
