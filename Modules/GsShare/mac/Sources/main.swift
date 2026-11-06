// G's Avengers — Mac app entry: menu-bar icon + settings window
import AppKit
import Combine
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    lazy var server = Server(state: state)
    var statusItem: NSStatusItem?
    /// Inside G’s Avengers (Contents/Library/LoginItems) the main app owns the only menu-bar icon
    /// and talks to us with distributed notifications.
    let embedded = Bundle.main.bundlePath.contains("/Contents/Library/LoginItems/")
    private var stateWatch: AnyCancellable?
    var window: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        if let i = CommandLine.arguments.firstIndex(of: "--demo-look"), i + 1 < CommandLine.arguments.count {
            demo(look: Int(CommandLine.arguments[i + 1]) ?? 0); return
        }
        // one copy only
        let me = Bundle.main.bundleIdentifier ?? ""
        if NSRunningApplication.runningApplications(withBundleIdentifier: me).count > 1 { NSApp.terminate(nil); return }

        if embedded {
            listenForMainApp()
        } else {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = Self.menuIcon()
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        }

        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
        // start with the Mac by default (can be switched off in the window)
        if !embedded && !UserDefaults.standard.bool(forKey: "loginItemSet") {
            UserDefaults.standard.set(true, forKey: "loginItemSet")
            try? SMAppService.mainApp.register()
        }
        server.start()
        if CommandLine.arguments.contains("--show") || (!embedded && !UserDefaults.standard.bool(forKey: "seenWindow")) {
            UserDefaults.standard.set(true, forKey: "seenWindow")
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { showWindow(); return true }

    @objc func showWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 720), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isMovableByWindowBackground = true
            w.contentView = NSHostingView(rootView: MainView(state: state, server: server))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc func quit() { NSApp.terminate(nil) }

    /// Commands from the main app (HelperWire.ShareCommand). Every command and
    /// every change of our own is answered with a full state post.
    private func listenForMainApp() {
        DistributedNotificationCenter.default().addObserver(forName: HelperWire.shareCommand, object: nil, queue: .main) { [weak self] note in
            guard let self, let command = HelperWire.shareCommand(from: note.userInfo) else { return }
            self.apply(command)
            self.postState()
        }
        stateWatch = state.objectWillChange
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.postState() }
        postState()
    }

    func apply(_ command: HelperWire.ShareCommand) {
        switch command {
        case .show: showWindow()
        case .state: break
        case .pause: server.setPaused(true)
        case .resume: server.setPaused(false)
        case .confirmPair: if state.pairCode != nil && !state.iConfirmed { server.confirmPair() }
        case .rule(let id, let on):
            guard let rule = KeyRules.toggle(id) else { return }
            state.config.keyRules[id] = (on == rule.defaultOn) ? nil : on
            configChanged()
        case .side(let raw):
            guard let side = Side(rawValue: raw), !state.peerId.isEmpty else { return }
            state.config.peerSide[state.peerId] = side
            configChanged()
            server.setLayout(peerSide: side)
        case .mouseSpeed(let v): state.config.mouseSpeed = v; configChanged()
        case .scrollSpeed(let v): state.config.scrollSpeed = v; configChanged()
        case .reverseScroll(let on): state.config.reverseScroll = on; configChanged()
        case .shareClipboard(let on): state.config.shareClipboard = on; configChanged()
        }
    }

    private func configChanged() { state.save(); server.configChanged() }

    static func snapshot(of state: AppState) -> HelperWire.ShareState {
        let c = state.config
        return HelperWire.ShareState(
            connected: state.connected, paused: state.paused, active: state.active, trusted: state.trusted,
            peer: state.peerName, peerId: state.peerId, lastSeen: state.lastPeerSeen,
            paired: !c.pairings.isEmpty, pairCode: state.pairCode, pairConfirmed: state.iConfirmed,
            side: (c.peerSide[state.peerId] ?? .right).rawValue,
            shareClipboard: c.shareClipboard, mouseSpeed: c.mouseSpeed, scrollSpeed: c.scrollSpeed,
            reverseScroll: c.reverseScroll,
            rules: KeyRules.toggles.map {
                HelperWire.ShareRule(id: $0.id, group: $0.group, windows: $0.windows, mac: $0.mac,
                                     on: c.keyRules[$0.id] ?? $0.defaultOn)
            })
    }

    private func postState() {
        let trusted = AXIsProcessTrusted()
        if state.trusted != trusted { state.trusted = trusted }
        DistributedNotificationCenter.default().postNotificationName(
            HelperWire.shareState, object: nil, userInfo: HelperWire.userInfo(state: Self.snapshot(of: state)),
            deliverImmediately: true)
    }

    /// Picker screenshots: show the real window in a given look with sample data, no networking.
    /// Writes the window number to /tmp/gsav-demo-window so a script can capture it.
    func demo(look: Int) {
        state.config = Config()
        state.config.look = look
        state.config.remaps.append(Remap(fromMods: ["ctrl", "shift"], fromKey: 0x56, toMods: ["command", "shift"], toKey: 0x09))
        state.trusted = true
        state.connected = true
        state.peerName = "WINDOWS-PC"; state.peerId = "demo"
        state.config.peerSide["demo"] = .right
        state.pairCode = CommandLine.arguments.contains("--pair") ? "482913" : nil
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 780), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden; w.isOpaque = false; w.backgroundColor = .clear
        w.contentView = NSHostingView(rootView: MainView(state: state, server: nil))
        w.center(); window = w
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        try? "\(w.windowNumber)".write(toFile: "/tmp/gsav-demo-window", atomically: true, encoding: .utf8)
        let f = w.frame, sh = NSScreen.screens[0].frame.height
        try? "\(Int(f.minX)),\(Int(sh - f.maxY)),\(Int(f.width)),\(Int(f.height))".write(toFile: "/tmp/gsav-demo-rect", atomically: true, encoding: .utf8)
        if CommandLine.arguments.contains("--motion") { motionScript() }
    }

    /// A scripted run-through of the app's motion, for the screen recording.
    func motionScript() {
        state.connected = false
        state.pairCode = nil
        let spring = Animation.spring(response: 0.45, dampingFraction: 0.75)
        let steps: [(Double, () -> Void)] = [
            (1.8, { withAnimation(spring) { self.state.pairCode = "482913" } }),
            (4.6, { withAnimation(spring) { self.state.pairCode = nil; self.state.connected = true } }),
            (6.2, { withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { self.state.config.peerSide["demo"] = .bottom } }),
            (7.3, { withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { self.state.config.peerSide["demo"] = .left } }),
            (8.4, { withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { self.state.config.peerSide["demo"] = .right } }),
            (9.6, { self.state.active = true }),
            (11.0, { self.state.active = false }),
            (11.6, { withAnimation { self.state.config.shareClipboard = false } }),
            (12.3, { withAnimation { self.state.config.shareClipboard = true } }),
        ]
        for (t, f) in steps { DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
    }

    /// Menu-bar glyph: two screens joined (template image, follows light/dark menu bar)
    static func menuIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { _ in
            NSColor.black.setStroke(); NSColor.black.setFill()
            let a = NSBezierPath(roundedRect: NSRect(x: 1, y: 4, width: 8, height: 7), xRadius: 1.5, yRadius: 1.5)
            a.lineWidth = 1.5; a.stroke()
            let b = NSBezierPath(roundedRect: NSRect(x: 11, y: 4, width: 8, height: 7), xRadius: 1.5, yRadius: 1.5)
            b.lineWidth = 1.5; b.stroke()
            NSBezierPath(rect: NSRect(x: 8, y: 7, width: 4, height: 1.5)).fill()
            NSBezierPath(ovalIn: NSRect(x: 8.2, y: 12, width: 3.6, height: 3.6)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = NSMenuItem(title: state.status, action: nil, keyEquivalent: ""); s.isEnabled = false
        menu.addItem(s)
        menu.addItem(.separator())
        let pause = NSMenuItem(title: state.paused ? "Resume Sharing" : "Pause Sharing", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pause)
        menu.addItem(NSMenuItem(title: "Open G's Avengers…", action: #selector(showWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        for i in menu.items { i.target = self }
    }

    @objc func togglePause() { server.setPaused(!state.paused) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
