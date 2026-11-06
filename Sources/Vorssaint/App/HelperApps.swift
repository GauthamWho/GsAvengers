// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit

/// G’s Avengers is one app made of three: this one, clipboard history and
/// mouse & keyboard sharing. The other two live inside this bundle under
/// Contents/Library/LoginItems with no Dock icon of their own; they start
/// with this app and quit with it.
enum HelperApps {
    private static var bundles: [URL] {
        let folder = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
        let found = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return found.filter { $0.pathExtension == "app" }.sorted { $0.path < $1.path }
    }

    private static var identifiers: [String] {
        bundles.compactMap { Bundle(url: $0)?.bundleIdentifier }
    }

    /// The clipboard helper runs only while its switch is on.
    private static func wanted(_ identifier: String) -> Bool {
        !identifier.hasSuffix(".clipboard")
            || UserDefaults.standard.bool(forKey: DefaultsKey.gsavClipboardHelperEnabled)
    }

    /// Starts each wanted helper that is not already running, in the background.
    /// A helper left running from before this launch (an update or reinstall
    /// that stopped only the main app) is an old build: it is restarted.
    static func launchAll() {
        let started = NSRunningApplication.current.launchDate ?? .distantPast
        for url in bundles {
            guard let identifier = Bundle(url: url)?.bundleIdentifier, wanted(identifier) else { continue }
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            let stale = running.filter { ($0.launchDate ?? .distantPast) < started }
            if !stale.isEmpty {
                stale.forEach { $0.terminate() }
                relaunch(url, after: stale, attempts: 25)
                continue
            }
            guard running.isEmpty else { continue }
            open(url)
        }
    }

    private static func relaunch(_ url: URL, after old: [NSRunningApplication], attempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if old.contains(where: { !$0.isTerminated }) && attempts > 0 {
                relaunch(url, after: old, attempts: attempts - 1)
            } else {
                open(url)
            }
        }
    }

    private static func open(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// Asks each running helper to quit.
    static func quitAll() {
        for identifier in identifiers {
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).forEach { $0.terminate() }
        }
    }

    /// Quits the helpers whose switch is now off and starts the ones now on.
    static func syncWanted() {
        for identifier in identifiers where !wanted(identifier) {
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).forEach { $0.terminate() }
        }
        launchAll()
    }
}

/// Talks to the embedded helpers over HelperWire. Each helper answers every
/// command with its full state, so `sharing` and `clipboard` always hold what
/// the helper really runs on; they go back to nil when the helper quits.
final class HelperBridge: ObservableObject {
    static let shared = HelperBridge()

    /// Last state the sharing helper posted; nil until it has said anything.
    @Published private(set) var sharing: HelperWire.ShareState?
    /// Last settings the clipboard helper posted; nil while it is not running.
    @Published private(set) var clipboard: HelperWire.ClipboardState?

    private var pendingSends: [String: DispatchWorkItem] = [:]

    private init() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: HelperWire.shareState, object: nil, queue: .main) { [weak self] note in
            guard let state = HelperWire.state(HelperWire.ShareState.self, from: note.userInfo) else { return }
            self?.sharing = state
        }
        center.addObserver(forName: HelperWire.clipboardState, object: nil, queue: .main) { [weak self] note in
            guard let state = HelperWire.state(HelperWire.ClipboardState.self, from: note.userInfo) else { return }
            self?.clipboard = state
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let id = app?.bundleIdentifier, let main = Bundle.main.bundleIdentifier else { return }
            if id == main + ".share" { self?.sharing = nil }
            if id == main + ".clipboard" { self?.clipboard = nil }
        }
    }

    /// Asks both helpers for a fresh state (they also post on every change).
    func refresh() {
        send(.state)
        send(.state as HelperWire.ClipboardCommand)
    }

    var hasClipboard: Bool { helperExists(suffix: ".clipboard") }
    var hasSharing: Bool { helperExists(suffix: ".share") }
    var sharingRunning: Bool { isRunning(suffix: ".share") }

    func openClipboard() { send(.show as HelperWire.ClipboardCommand) }
    func openEmoji() { send(.emoji) }
    func openClipboardSettings() { send(.settings) }
    func openSharingWindow() { send(.show as HelperWire.ShareCommand) }
    func setSharingPaused(_ paused: Bool) {
        sharing?.paused = paused
        send(paused ? .pause : .resume)
    }

    /// The clipboard helper's own switch: quits or starts the helper.
    var clipboardEnabled: Bool { AvengersSwitch.clipboardHelper.isOn(in: .standard) }
    func setClipboardEnabled(_ on: Bool) {
        AvengersSwitch.clipboardHelper.write(on, in: .standard)
        if !on { clipboard = nil }
        HelperApps.syncWanted()
        objectWillChange.send()
    }

    func sharingStatusText(_ text: HelperAppStrings) -> String {
        guard sharingRunning, let state = sharing else { return text.statusNotRunning }
        if state.paused { return text.statusPaused }
        if state.pairCode != nil { return text.statusPairing }
        if state.connected { return String(format: text.statusConnectedFormat, state.peer) }
        return text.statusSearching
    }

    /// Sends a command now; `coalesce` waits for a quiet moment first, so a
    /// slider drag sends one change instead of sixty.
    func send(_ command: HelperWire.ShareCommand, coalesce: Bool = false) {
        post(HelperWire.shareCommand, HelperWire.userInfo(command), coalesce: coalesce)
    }

    func send(_ command: HelperWire.ClipboardCommand) {
        post(HelperWire.clipboardCommand, HelperWire.userInfo(command), coalesce: false)
    }

    /// Changes the window shows at once; the helper's answer confirms them.
    func setRule(_ id: String, _ on: Bool) {
        if let index = sharing?.rules.firstIndex(where: { $0.id == id }) { sharing?.rules[index].on = on }
        send(.rule(id, on))
    }

    func setShare<Value>(_ path: WritableKeyPath<HelperWire.ShareState, Value>, _ value: Value,
                         _ command: HelperWire.ShareCommand, coalesce: Bool = false) {
        sharing?[keyPath: path] = value
        send(command, coalesce: coalesce)
    }

    func setClipboard<Value>(_ path: WritableKeyPath<HelperWire.ClipboardState, Value>, _ value: Value,
                             _ command: HelperWire.ClipboardCommand) {
        clipboard?[keyPath: path] = value
        send(command)
    }

    #if VORSSAINT_DEVELOPMENT
    /// Sample states for the offscreen window snapshots.
    func preview(sharing: HelperWire.ShareState?, clipboard: HelperWire.ClipboardState?) {
        self.sharing = sharing
        self.clipboard = clipboard
        previewing = true
    }
    private(set) var previewing = false
    #endif

    private func helperExists(suffix: String) -> Bool {
        let folder = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
        let found = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return found.contains { Bundle(url: $0)?.bundleIdentifier?.hasSuffix(suffix) == true }
    }

    private func isRunning(suffix: String) -> Bool {
        #if VORSSAINT_DEVELOPMENT
        if previewing { return true }
        #endif
        guard let main = Bundle.main.bundleIdentifier else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: main + suffix).isEmpty
    }

    private func post(_ name: Notification.Name, _ info: [String: String], coalesce: Bool) {
        let key = name.rawValue + (info["cmd"] ?? "")
        pendingSends[key]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSends[key] = nil
            DistributedNotificationCenter.default().postNotificationName(
                name, object: nil, userInfo: info, deliverImmediately: true)
        }
        if coalesce {
            pendingSends[key] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        } else {
            work.perform()
        }
    }
}
