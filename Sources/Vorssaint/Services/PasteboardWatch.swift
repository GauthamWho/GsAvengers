// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit

/// The one pasteboard watch in the app. macOS posts no notification when the
/// pasteboard changes, so its change count (a single integer, no data) is
/// read twice a second, by one timer shared by clipboard history, the URL
/// cleaner and clipboard sharing. Subscribers hear only actual changes, and
/// the timer exists only while at least one of them is on. Main thread.
final class PasteboardWatch {
    static let shared = PasteboardWatch()

    private var subscribers: [String: () -> Void] = [:]
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    private init() {}

    func subscribe(_ id: String, onChange: @escaping () -> Void) {
        subscribers[id] = onChange
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func unsubscribe(_ id: String) {
        subscribers[id] = nil
        guard subscribers.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        for handler in subscribers.values { handler() }
    }
}
