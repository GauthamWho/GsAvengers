// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

#if VORSSAINT_DEVELOPMENT
import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Developer builds only, and only when launched with `GSMAC_QUICKRING_PROBE=1`
/// or `--quickring-probe`: checks the Quick Ring live without a hand on the
/// mouse. Post the distributed notification
/// `com.gauthamwho.gsmac.dev.quickring.probe` (userInfo `action`: `state`,
/// `open`, `close`, `backdrop` with `value` light/dark/off, `select` with `index`, `key` with `code`, `control`, `option`,
/// `controlClick`, `middleClick`, `move` with `x`/`y`) and one JSON line per
/// result lands in `~/Library/Application Support/<bundle id>/quickring-probe.jsonl`.
/// The trigger actions post real events through the system, so they travel
/// the same taps a hand would. Lines hold the ring's state only.
enum QuickRingProbe {
    static let notification = Notification.Name("com.gauthamwho.gsmac.dev.quickring.probe")
    private static var observer: NSObjectProtocol?
    private static var backdrop: NSWindow?
    private static let fileLimit: UInt64 = 1_000_000

    static func install() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: notification, object: nil, queue: .main
        ) { note in
            handle(note.userInfo ?? [:])
        }
    }

    private static func handle(_ info: [AnyHashable: Any]) {
        let action = info["action"] as? String ?? "state"
        let ring = QuickRingService.shared
        switch action {
        case "open": ring.open()
        case "backdrop": showBackdrop(info["value"] as? String ?? "off")
        case "close": ring.close()
        case "select": ring.select(Int(info["index"] as? String ?? "") ?? (info["index"] as? Int ?? 0))
        case "key":
            let code = CGKeyCode(Int(info["code"] as? String ?? "") ?? kVK_Escape)
            postKey(code, down: true)
            postKey(code, down: false)
        case "control", "option":
            // Two clean taps of the left Control (or, to check it no longer
            // opens anything, Option) key, 80 ms apart, posted off the main
            // thread so its own work cannot stretch the gaps.
            let control = action == "control"
            DispatchQueue.global(qos: .userInteractive).async {
                for (pause, down) in [(0, true), (60_000, false), (80_000, true), (60_000, false)] as [(UInt32, Bool)] {
                    usleep(pause)
                    postModifier(control: control, down: down)
                }
            }
        case "controlClick": postClick(type: (.leftMouseDown, .leftMouseUp), button: .left, flags: .maskControl)
        case "middleClick": postClick(type: (.otherMouseDown, .otherMouseUp), button: .center, flags: [])
        case "clickItem", "clickHole":
            // A plain click on a ring button (by index) or in its hole, at
            // the place a hand would put it.
            guard let center = ring.probeCenter else { break }
            var target = center
            if action == "clickItem" {
                let index = Int(info["index"] as? String ?? "") ?? 0
                let unit = RadialMenuGeometry.unitPosition(index: index, itemCount: ring.entries.count)
                target.x += unit.dx * QuickRingLayout.itemRadius
                target.y += unit.dyUp * QuickRingLayout.itemRadius
            }
            let height = NSScreen.screens.first?.frame.height ?? 0
            let point = CGPoint(x: target.x, y: height - target.y)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point,
                    mouseButton: .left)?.post(tap: .cghidEventTap)
            for (delay, kind) in [(0.12, CGEventType.leftMouseDown), (0.17, .leftMouseUp)] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    CGEvent(mouseEventSource: nil, mouseType: kind, mouseCursorPosition: point,
                            mouseButton: .left)?.post(tap: .cghidEventTap)
                }
            }
        case "move":
            let x = Double(info["x"] as? String ?? "") ?? 0
            let y = Double(info["y"] as? String ?? "") ?? 0
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y),
                    mouseButton: .left)?.post(tap: .cghidEventTap)
        default: break
        }
        // Long enough for the spring, the fade and any action's delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            var line = ring.probeState
            line["action"] = action
            line["pointer"] = [Double(NSEvent.mouseLocation.x), Double(NSEvent.mouseLocation.y)]
            line["axTrusted"] = AXIsProcessTrusted()
            line["available"] = AppFeature.quickRing.isAvailable
            line["recording"] = AppFeature.screenRecorder.isAvailable && ScreenRecorderService.shared.isRecording
            line["frontApp"] = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
            line["timing"] = QuickRingFrameMeter.shared.last
            write(line)
        }
    }

    /// A stand-in page right behind the ring for look checks, so screenshots
    /// show glass over real type without anyone's own windows in them.
    private static func showBackdrop(_ kind: String) {
        backdrop?.orderOut(nil)
        backdrop = nil
        guard kind == "light" || kind == "dark" else { return }
        let size: CGFloat = 640
        // Centred on the open ring (else the pointer), so the shot never
        // reaches past it into anyone's windows.
        let mouse = QuickRingService.shared.probeCenter ?? NSEvent.mouseLocation
        let window = NSWindow(contentRect: NSRect(x: mouse.x - size / 2, y: mouse.y - size / 2,
                                                  width: size, height: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: QuickRingProbeBackdrop(dark: kind == "dark"))
        window.orderFrontRegardless()
        backdrop = window
    }

    private static func postModifier(control: Bool, down: Bool) {
        let key = CGKeyCode(control ? kVK_Control : kVK_Option)
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = down ? (control ? .maskControl : .maskAlternate) : []
        event.post(tap: .cghidEventTap)
    }

    private static func postKey(_ code: CGKeyCode, down: Bool) {
        CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)?.post(tap: .cghidEventTap)
    }

    private static func postClick(type: (CGEventType, CGEventType), button: CGMouseButton, flags: CGEventFlags) {
        // Quartz positions are top-left based.
        let mouse = NSEvent.mouseLocation
        let height = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: mouse.x, y: height - mouse.y)
        for (index, kind) in [type.0, type.1].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                guard let event = CGEvent(mouseEventSource: nil, mouseType: kind, mouseCursorPosition: point,
                                          mouseButton: button) else { return }
                event.flags = flags
                if button == .center { event.setIntegerValueField(.mouseEventButtonNumber, value: 2) }
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private static func write(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              var data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return }
        data.append(0x0A)
        let folder = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.gauthamwho.gsmac.dev")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("quickring-probe.jsonl")
        if let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? UInt64,
           size > fileLimit {
            try? FileManager.default.removeItem(at: file)
        }
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: file, options: .atomic)
        }
    }
}
/// A plain page of placeholder type: white like a web page, or dark and
/// colourful like a desktop.
private struct QuickRingProbeBackdrop: View {
    let dark: Bool
    private static let line = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs."

    var body: some View {
        ZStack(alignment: .topLeading) {
            if dark {
                LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.30),
                                        Color(red: 0.45, green: 0.12, blue: 0.40),
                                        Color(red: 0.95, green: 0.45, blue: 0.20)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color.white
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Quarterly notes").font(.system(size: 26, weight: .bold))
                ForEach(0..<16, id: \.self) { index in
                    Text(Self.line).font(.system(size: index % 5 == 0 ? 17 : 14, weight: index % 5 == 0 ? .semibold : .regular))
                }
            }
            .foregroundStyle(dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
            .padding(28)
        }
    }
}
#endif

#if VORSSAINT_DEVELOPMENT
/// Developer builds only: how fast the ring answers and how smoothly it runs.
/// Times the trigger event to the handler, the handler to the panel being
/// ordered in, and to the first frame the window server drew; then, while it
/// is open, every frame's interval and the main thread's CPU time. Numbers
/// only, read by the probe.
final class QuickRingFrameMeter: NSObject {
    static let shared = QuickRingFrameMeter()

    private var link: CADisplayLink?
    private var triggerNs: UInt64 = 0
    private var handlerNs: UInt64 = 0
    private var orderedNs: UInt64 = 0
    private var firstFrameNs: UInt64 = 0
    private var lastFrame: CFTimeInterval = 0
    private var intervals: [Double] = []
    private var cpuAtOpen: UInt64 = 0
    private(set) var last: [String: Any] = [:]

    private static func now() -> UInt64 { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }
    private static func mainCPU() -> UInt64 { clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) }

    /// The event that fired the ring (its timestamp shares the uptime clock).
    func triggered(eventTimestamp: UInt64) {
        triggerNs = eventTimestamp
        handlerNs = Self.now()
    }

    func opening() {
        if triggerNs == 0 { handlerNs = Self.now() }
        cpuAtOpen = Self.mainCPU()
    }

    func ordered(_ panel: NSPanel) {
        orderedNs = Self.now()
        firstFrameNs = 0
        intervals = []
        lastFrame = 0
        link?.invalidate()
        let link = panel.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        if firstFrameNs == 0 { firstFrameNs = Self.now() }
        if lastFrame > 0 { intervals.append((link.timestamp - lastFrame) * 1000) }
        lastFrame = link.timestamp
    }

    func closed() {
        guard let link else { return }
        link.invalidate()
        self.link = nil
        let ms = { (from: UInt64, to: UInt64) -> Double in
            from == 0 || to < from ? -1 : Double(to - from) / 1_000_000
        }
        let budget = (NSScreen.main?.maximumFramesPerSecond).map { 1000 / Double(max($0, 1)) } ?? 16.7
        let cpu = Double(Self.mainCPU() &- cpuAtOpen) / 1_000_000
        last = ["triggerToHandlerMs": ms(triggerNs, handlerNs),
                "handlerToOrderedMs": ms(handlerNs, orderedNs),
                "handlerToFirstFrameMs": ms(handlerNs, firstFrameNs),
                "triggerToFirstFrameMs": ms(triggerNs == 0 ? handlerNs : triggerNs, firstFrameNs),
                "frames": intervals.count + 1,
                "frameBudgetMs": budget,
                "maxFrameMs": intervals.max() ?? 0,
                "longFrames": intervals.filter { $0 > budget * 1.5 }.count,
                "longFrameIndexes": intervals.indices.filter { intervals[$0] > budget * 1.5 },
                "mainCPUms": cpu,
                "mainCPUPerFrameMs": cpu / Double(intervals.count + 1)]
        triggerNs = 0
    }
}
#endif
