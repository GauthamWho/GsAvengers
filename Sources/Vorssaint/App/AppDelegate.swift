// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import Combine

/// G’s Avengers: one process, one menu-bar icon, one window. Sharing and the
/// clipboard run in this process too (they used to be helper apps).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppAppearanceController.shared.apply()
        GlobalShortcut.startObservingKeyboardLayout()
        // Another app's slow Accessibility answer must never hold this one.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.35)

        // Once: drop the deleted features' settings and side effects, adopt
        // the old helper apps' clipboard settings, start at login by default.
        LeanMigration.runIfNeeded()
        LaunchAtLogin.repairAtStartup()

        installMainMenu()

        statusController = StatusItemController()
        statusController.onLeftClick = { AvengersWindowController.shared.show() }
        statusController.onRightClick = { [weak self] button in self?.showContextMenu(from: button) }

        SharingEngine.shared.onPairingRequest = { AvengersWindowController.shared.show(.sharing) }

        SystemShortcutTakeover.recoverIfNeeded(keeping: AppSwitcher.launchTakeoverIDs())
        HotkeyManager.shared.onActivate = { KeepAwakeManager.shared.toggle() }
        KeepAwakeManager.shared.recoverIfNeeded {
            KeepAwakeManager.shared.activateOnLaunchIfNeeded()
        }
        // Only features that are on start; everything else never loads.
        FeatureRuntime.shared.syncAtLaunch()

        // Accessibility granted while running: bring the input features up
        // without a relaunch. Driven by the system's own notification.
        Permissions.shared.$accessibility
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { trusted in
                FeatureRuntime.shared.sync([.switcher, .dockPreview, .finderCutPaste, .autoQuit,
                                            .windowLayout, .quickRing, .keepAwake])
                SharingEngine.shared.accessibilityChanged(trusted)
                MainActor.assumeIsolated { ClipboardEngine.shared.accessibilityChanged() }
            }
            .store(in: &cancellables)
        Permissions.shared.$screenRecording
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { _ in FeatureRuntime.shared.sync([.dockPreview, .screenRecorder]) }
            .store(in: &cancellables)

        L10n.shared.$language
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.installMainMenu() }
            .store(in: &cancellables)

        // First run: no setup screen, the window itself shows every switch.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: DefaultsKey.hasOnboarded) {
            defaults.set(true, forKey: DefaultsKey.hasOnboarded)
            DispatchQueue.main.async { AvengersWindowController.shared.show() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SharingEngine.shared.stop()
        URLCleanerService.shared.stop()
        WindowLayoutService.shared.suspend()
        // The Dock's app and window switcher hotkeys persist after quit.
        AppSwitcher.shared.suspend()
        DockPreviewService.shared.stop()
        SystemShortcutTakeover.restoreAll()
        KeepAwakeManager.shared.deactivate(reason: .quit)
    }

    /// Opening the app again (Finder, Spotlight) while it runs: the icon
    /// comes back and the window opens, so there is always a way in.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusController?.reshow()
        AvengersWindowController.shared.show()
        return true
    }

    // MARK: - Right-click menu

    private func showContextMenu(from button: NSStatusBarButton?) {
        let strings = L10n.shared.s
        let text = FeatureStrings.avengers(L10n.shared.language)
        let menu = NSMenu()
        let open = NSMenuItem(title: text.openApp, action: #selector(menuOpen), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        if AppFeature.keepAwake.isOn {
            let awake = NSMenuItem(title: FeatureStrings.home(L10n.shared.language).keepAwakeNow,
                                   action: #selector(menuToggleAwake), keyEquivalent: "")
            awake.state = KeepAwakeManager.shared.isActive ? .on : .off
            awake.target = self
            menu.addItem(awake)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: strings.menuQuit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        guard let item = statusController?.statusItem else { return }
        item.menu = menu
        item.button?.performClick(nil)
        DispatchQueue.main.async { item.menu = nil }
    }

    @objc private func menuOpen() { AvengersWindowController.shared.show() }
    @objc private func menuToggleAwake() { KeepAwakeManager.shared.toggle() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(string: L10n.shared.s.aboutDescription,
                                         attributes: [.font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    // MARK: - Application menu

    /// An accessory app gets no main menu, so the standard shortcuts
    /// (⌘W, ⌘Q, ⌘C/V/X/A) would do nothing in the window. A minimal one.
    func installMainMenu() {
        let strings = L10n.shared.s
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        let about = NSMenuItem(title: strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: strings.menuHide, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: strings.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: strings.menuEdit)
        editMenuItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: strings.menuUndo, action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: strings.menuRedo, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: strings.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: strings.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: strings.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: strings.menuSelectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: strings.menuWindow)
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: strings.menuMinimize, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: strings.menuClose, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}
