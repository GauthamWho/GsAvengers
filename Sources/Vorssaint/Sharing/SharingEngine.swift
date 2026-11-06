// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import Combine

/// Windows keyboard & mouse sharing, running inside G’s Avengers itself (it
/// used to be a helper app). Nothing starts until the Sharing switch is on:
/// no listener, no discovery thread, no timers, no taps.
final class SharingEngine {
    static let shared = SharingEngine()

    /// What the window shows; published on the main thread.
    let state = SharingAppState()
    private var server: Server?
    /// Opens the window on the Sharing page when a laptop asks to pair.
    var onPairingRequest: (() -> Void)?

    private init() {}

    var isRunning: Bool { server != nil }

    func start() {
        guard server == nil else { return }
        let server = Server(state: state)
        self.server = server
        state.trusted = AXIsProcessTrusted()
        server.start()
    }

    func stop() {
        server?.stop()
        server = nil
    }

    func syncWithPreferences() {
        if AppFeature.sharing.isOn { start() } else { stop() }
    }

    // MARK: - Settings the window changes

    func confirmPair() {
        guard state.pairCode != nil, !state.iConfirmed else { return }
        server?.confirmPair()
    }

    func setRule(_ id: String, _ on: Bool) {
        guard let rule = KeyRules.toggle(id) else { return }
        state.config.keyRules[id] = (on == rule.defaultOn) ? nil : on
        configChanged()
    }

    func setSide(_ raw: Int) {
        guard let side = Side(rawValue: raw), !state.peerId.isEmpty else { return }
        state.config.peerSide[state.peerId] = side
        configChanged()
        server?.setLayout(peerSide: side)
    }

    func setMouseSpeed(_ value: Double) { state.config.mouseSpeed = min(max(value, 0.4), 2.5); configChanged() }
    func setScrollSpeed(_ value: Double) { state.config.scrollSpeed = min(max(value, 0.2), 3); configChanged() }
    func setReverseScroll(_ on: Bool) { state.config.reverseScroll = on; configChanged() }
    func setShareClipboard(_ on: Bool) { state.config.shareClipboard = on; configChanged() }

    private func configChanged() {
        state.save()
        server?.configChanged()
    }

    /// Accessibility was granted or revoked while running.
    func accessibilityChanged(_ trusted: Bool) {
        if state.trusted != trusted { state.trusted = trusted }
    }

    /// The window's view of the sharing state.
    var snapshot: SharingSnapshot {
        let c = state.config
        return SharingSnapshot(
            running: isRunning, connected: state.connected, active: state.active, trusted: state.trusted,
            peer: state.peerName, peerId: state.peerId, lastSeen: state.lastPeerSeen,
            paired: !c.pairings.isEmpty, pairCode: state.pairCode, pairConfirmed: state.iConfirmed,
            side: (c.peerSide[state.peerId] ?? .right).rawValue,
            shareClipboard: c.shareClipboard, mouseSpeed: c.mouseSpeed, scrollSpeed: c.scrollSpeed,
            reverseScroll: c.reverseScroll,
            rules: KeyRules.toggles.map {
                SharingRule(id: $0.id, group: $0.group, windows: $0.windows, mac: $0.mac,
                            on: c.keyRules[$0.id] ?? $0.defaultOn)
            })
    }
}

/// One Windows-habit key switch.
struct SharingRule: Equatable, Identifiable {
    var id: String
    var group: String
    var windows: String
    var mac: String
    var on: Bool
}

/// Everything about sharing that the window shows or changes.
struct SharingSnapshot: Equatable {
    var running = false
    var connected = false
    var active = false              // the Windows pointer is on this Mac right now
    var trusted = false             // Accessibility allowed
    var peer = ""
    var peerId = ""
    var lastSeen = ""               // a laptop seen on the network but not connected
    var paired = false              // at least one Windows laptop paired before
    var pairCode: String?           // shown while a new pairing waits for "Pair"
    var pairConfirmed = false       // Pair pressed here, waiting for Windows
    var side = 1                    // where Windows sits: 0 left, 1 right, 2 top, 3 bottom
    var shareClipboard = true
    var mouseSpeed = 1.0
    var scrollSpeed = 1.0
    var reverseScroll = false
    var rules: [SharingRule] = []
}
