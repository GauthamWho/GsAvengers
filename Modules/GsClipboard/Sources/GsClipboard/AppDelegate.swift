import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    /// Inside G’s Avengers (Contents/Library/LoginItems) the main app owns the only menu-bar icon.
    static let isEmbedded = Bundle.main.bundlePath.contains("/Contents/Library/LoginItems/")
    private var panel: PanelController!
    private var model: AppModel!
    private let hotKey = HotKeyManager.shared
    private let updates = UpdateChecker.shared
    private var previousApp: NSRunningApplication?
    /// The text field you were in when the panel opened; focused again before pasting.
    private var previousFocus: AXUIElement?
    private var state: PanelState!
    private var preview: PreviewController!
    private var aboutWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CLI helpers used by the installer and release tooling.
        BrandAssets.runIfRequested()
        if CommandLine.arguments.contains("--version") {
            print("Gautham's Clipboard \(version)")
            NSApp.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--register-login") {
            do {
                try SMAppService.mainApp.register()
                NSLog("GsClipboard: login item registered")
            } catch {
                NSLog("GsClipboard: register login item failed: \(error)")
            }
            NSApp.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--unregister-login") {
            do {
                try SMAppService.mainApp.unregister()
                NSLog("GsClipboard: login item unregistered")
            } catch {
                NSLog("GsClipboard: unregister login item failed: \(error)")
            }
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        #if DEBUG
        // Debug helper: draw the panel offscreen and save it as a PNG, then exit.
        //   GsClipboard --snapshot out.png [emoji] [dark]
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), flag + 1 < CommandLine.arguments.count {
            snapshotPanel(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
            return
        }
        #endif

        // Single-instance guard: if another copy is already running, hand over and quit.
        let bundleID = Bundle.main.bundleIdentifier ?? UpdateChecker.bundleID
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        if let other = others.first {
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        model = AppModel()
        configureLoginItemIfNeeded()

        #if DEBUG
        // Debug helper: copy the newest item back to the pasteboard and report
        // what landed there, then exit. Used to verify text and image restore.
        if CommandLine.arguments.contains("--selftest") {
            if let item = model.store.items.first {
                model.copy(item)
                let pb = NSPasteboard.general
                let types = pb.types?.map(\.rawValue).joined(separator: ",") ?? "none"
                Diag.log("selftest kind=\(item.kind.rawValue) types=\(types)")
            } else {
                Diag.log("selftest no items")
            }
            NSApp.terminate(nil)
            return
        }
        #endif

        #if DEBUG
        // Debug helper: print the newest history items and exit. Used to confirm
        // that a copy really was captured.
        if CommandLine.arguments.contains("--dump") {
            Diag.log("dump: \(model.store.items.count) items")
            for item in model.store.items.prefix(10) {
                print("[\(item.kind.rawValue)] \(item.preview)")
            }
            NSApp.terminate(nil)
            return
        }
        #endif

        #if DEBUG
        // Debug helper: install a local zip as an update (used for testing).
        if let flag = CommandLine.arguments.firstIndex(of: "--install-update"),
           flag + 1 < CommandLine.arguments.count {
            let zip = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
            let destination = ProcessInfo.processInfo.environment["GS_UPDATE_DEST"]
            updates.applyUpdate(zipURL: zip, destination: destination)
            return
        }
        #endif

        state = PanelState(model: model)
        state.onPick = { [weak self] item, paste in self?.pick(item, paste: paste) }
        state.onClose = { [weak self] in self?.closePanel() }
        state.onPickEmojiText = { [weak self] text, type in self?.pickEmoji(text, type: type) }
        state.onOpenSettings = { [weak self] in self?.showSettings() }
        panel = PanelController { [unowned self] in
            ContentView(state: self.state, model: self.model, updates: self.updates)
        }
        panel.keyHandler = { [weak self] e in self?.state.handle(e) ?? false }
        panel.onShow = { [weak self] in self?.state.prepareForShow() }
        panel.onMouseMoved = { [weak self] in
            guard let s = self?.state, !s.hoverArmed else { return }
            s.hoverArmed = true
        }
        panel.onHide = { [weak self] in self?.preview.hide(); self?.state.isOpen = false }
        preview = PreviewController(state: state, panel: panel)
        model.startCare { [weak self] in self?.panel.isVisible ?? false }

        if Self.isEmbedded {
            listenForMainApp()
        } else {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        if let button = statusItem?.button {
            button.image = MenuBarMark.image()
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Gautham's Clipboard — \(hotKey.display)"
        }

        hotKey.onPressed = { [weak self] slot in
            self?.togglePanel(from: nil, page: slot == .emoji ? .emoji : .all)
        }
        hotKey.start()

        // Check for updates quietly a few seconds after launch (once per day).
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.updates.checkIfDue()
        }

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.showPanel(at: .caret(NSRect(x: 900, y: 700, width: 4, height: 20)))
                // Debug: `--show --filter Images` opens on a filter (used for screenshots).
                let args = CommandLine.arguments
                if let i = args.firstIndex(of: "--filter"), i + 1 < args.count,
                   let f = PanelState.Filter(rawValue: args[i + 1]) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.state.filter = f
                        self.state.selectedID = self.state.visible.first?.id
                    }
                }
            }
        }

        if CommandLine.arguments.contains("--show-about") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAbout()
            }
        }

        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showSettings()
            }
        }
    }

    // MARK: - Login item

    /// First launch: turn on "launch at login" automatically, once.
    private func configureLoginItemIfNeeded() {
        guard !Self.isEmbedded else { return }
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "didSetupLoginItem") == nil else { return }
        defaults.set(true, forKey: "didSetupLoginItem")
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
            NSLog("GsClipboard: first-run login item registered")
        } catch {
            NSLog("GsClipboard: first-run login item failed: \(error)")
        }
    }

    // MARK: - Commands from G’s Avengers

    /// The main app's menu and window send these (HelperWire.ClipboardCommand)
    /// instead of a second menu-bar icon. Every command and every settings
    /// change here is answered with a full state post.
    private func listenForMainApp() {
        DistributedNotificationCenter.default().addObserver(
            forName: HelperWire.clipboardCommand, object: nil, queue: .main
        ) { [weak self] note in
            guard let command = HelperWire.clipboardCommand(from: note.userInfo) else { return }
            MainActor.assumeIsolated { self?.handle(command) }
        }
        for name in [UserDefaults.didChangeNotification, HotKeyManager.changed] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedulePost() }
            }
        }
        postState()
    }

    private func handle(_ command: HelperWire.ClipboardCommand) {
        switch command {
        case .show: togglePanel(from: nil)
        case .emoji: togglePanel(from: nil, page: .emoji)
        case .settings: showSettings()
        case .about: showAbout()
        case .state: break
        case .pasteAfterPick(let on): Paster.enabled = on
        case .smartCleanup(let on): ClipStore.smartCleanup = on
        case .maxItems(let count): model.store.maxItems = count
        }
        postState()
    }

    private var postPending = false

    private func schedulePost() {
        guard !postPending else { return }
        postPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.postPending = false
            self?.postState()
        }
    }

    private func postState() {
        let state = HelperWire.ClipboardState(
            pasteAfterPick: Paster.enabled, smartCleanup: ClipStore.smartCleanup,
            maxItems: UserDefaults.standard.integer(forKey: "maxItems"),
            shortcut: Shortcut.stored(.clipboard).display, emojiShortcut: Shortcut.stored(.emoji).display)
        DistributedNotificationCenter.default().postNotificationName(
            HelperWire.clipboardState, object: nil, userInfo: HelperWire.userInfo(state: state), deliverImmediately: true)
    }

    // MARK: - Status item

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePanel(from: statusItem?.button)
        }
    }

    private func showStatusMenu() {
        if panel.isVisible { closePanel() }

        let menu = NSMenu()

        let about = NSMenuItem(title: "About Gautham's Clipboard", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        if let version = updates.available?.version {
            let install = NSMenuItem(title: "Install Update \(version)…", action: #selector(installUpdate), keyEquivalent: "")
            install.target = self
            menu.addItem(install)
        } else {
            let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            check.target = self
            menu.addItem(check)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Gautham's Clipboard", action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        if let button = statusItem?.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 6),
                       in: button)
        }
    }

    @objc private func checkForUpdates() {
        updates.check()
    }

    @objc private func installUpdate() {
        updates.installAvailable()
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    // MARK: - Windows

    @objc func showAbout() {
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "About Gautham's Clipboard"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = .windowBackgroundColor
            aboutWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSLog("GsClipboard: about window shown")
    }

    private func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Gautham's Clipboard Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSLog("GsClipboard: settings window shown")
    }

    // MARK: - Panel

    /// Menu bar icon: drop down under it. Shortcut: open right next to your text cursor.
    /// `page`: fn V opens the clipboard, fn E opens straight on Emoji. Pressing the other
    /// shortcut while the panel is open flips the page; the same one closes it.
    private func togglePanel(from button: NSStatusBarButton?, page: PanelState.Filter = .all) {
        if panel.isVisible {
            if state.filter != page {
                withAnimation(Motion.slide) { state.filter = page }
                state.emojiIndex = 0
            } else {
                closePanel()
            }
            return
        }
        // Find the caret before we take focus, while your app still has it.
        if let button, let window = button.window {
            showPanel(at: .statusItem(window.convertToScreen(button.convert(button.bounds, to: nil))))
        } else {
            showPanel(at: Caret.anchor())
        }
        if page != .all { state.filter = page }
    }

    private func showPanel(at anchor: PanelAnchor) {
        if !panel.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
            previousFocus = Paster.focusedElement()
        }
        panel.show(at: anchor)
    }

    private func closePanel() {
        panel.hide()
        restorePreviousApp()
    }

    /// Puts the item on the clipboard, closes the panel, hands focus back to the app you were
    /// in, then (if allowed) presses ⌘V there so it lands where your cursor was.
    private func pick(_ item: ClipItem, paste: Bool) {
        model.copy(item)
        let target = previousApp, field = previousFocus
        closePanel()
        Diag.log("picked \(item.kind.rawValue) paste=\(paste) trusted=\(Paster.isTrusted) target=\(target?.localizedName ?? "?")")
        if paste && Paster.enabled { Paster.paste(into: target, element: field) }
    }

    /// Emoji are pasted where your cursor was, then your clipboard is put back as it was.
    /// Pasting (not typing keystrokes) works in every app. Without Accessibility, with ⌥↩, or if
    /// your app does not come back to the front, the emoji is left on the clipboard so ⌘V still works.
    private func pickEmoji(_ text: String, type: Bool) {
        let target = previousApp, field = previousFocus
        closePanel()
        let pb = NSPasteboard.general
        let willPaste = type && Paster.enabled && Paster.isTrusted
        let saved = willPaste ? PasteboardSnapshot(pb) : nil
        pb.clearContents()
        pb.setString(text, forType: .string)
        let ours = pb.changeCount
        model.monitor.ignoreChanges(through: ours)
        Diag.log("picked emoji paste=\(willPaste) trusted=\(Paster.isTrusted) target=\(target?.localizedName ?? "?")")
        guard willPaste, let saved else { return }
        Paster.paste(into: target, element: field) { [weak self] ok in
            guard ok else { return } // the emoji stays on the clipboard
            // Put your clipboard back only once the app has read the emoji (some apps read it late),
            // and only if nothing else was copied meanwhile.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                guard pb.changeCount == ours else { return }
                saved.restore(to: pb)
                self?.model.monitor.ignoreChanges(through: pb.changeCount)
                Diag.log("clipboard restored after emoji paste")
            }
        }
    }

    /// Hands focus back so the paste lands in whatever app you were using.
    private func restorePreviousApp() {
        guard let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier, !previousApp.isTerminated else { return }
        if #available(macOS 14.0, *) { NSApp.yieldActivation(to: previousApp) }
        previousApp.activate(options: [])
    }

    #if DEBUG
    /// Renders the real panel view (real history, no glass) into a PNG for design checks.
    private func snapshotPanel(to url: URL) {
        let args = CommandLine.arguments
        Accent.applyOverride()
        let model = AppModel()
        model.monitor.stop()
        let state = PanelState(model: model)
        state.prepareForShow()
        state.showPermissionCard = false
        if args.contains("emoji") { state.filter = .emoji }
        if let q = args.first(where: { $0.hasPrefix("search=") }) { state.search = String(q.dropFirst(7)) }
        let dark = args.contains("dark")
        let root = ContentView(state: state, model: model, updates: UpdateChecker())
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: DS.Size.panel)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        window.orderFrontRegardless()
        window.setFrameOrigin(NSPoint(x: -3000, y: -3000))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { exit(1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            print("snapshot written: \(url.path)")
            exit(0)
        }
    }
    #endif
}
