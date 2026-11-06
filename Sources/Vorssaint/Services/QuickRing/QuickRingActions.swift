// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import AppKit

/// Everything the Quick Ring needs from the rest of the app: what to show
/// when it opens and how to run a pick. The ring itself knows no other
/// service, so it can move into another app with a provider of its own.
protocol QuickRingActionProvider {
    /// Read once per opening.
    func currentContext() -> QuickRingContext
    func run(_ item: QuickRingItem)
}

/// G’s Avengers' actions: the screenshot, the recorder, clipboard history
/// and Mission Control. Each one is asked only while its feature is
/// installed, so an uninstalled service never comes to life for the ring.
struct GsMacQuickRingActions: QuickRingActionProvider {
    func currentContext() -> QuickRingContext {
        let recorderAvailable = AppFeature.screenRecorder.isOn
        return QuickRingContext(
            recording: recorderAvailable && ScreenRecorderService.shared.isRecording,
            screenshotAvailable: AppFeature.screenshot.isOn,
            recorderAvailable: recorderAvailable,
            clipboardAvailable: AppFeature.clipboardHistory.isOn)
    }

    func run(_ item: QuickRingItem) {
        switch item {
        case .capture:
            guard AppFeature.screenshot.isAvailable else { return }
            ScreenshotService.shared.capture()
        case .record, .stopRecording:
            guard AppFeature.screenRecorder.isAvailable else { return }
            ScreenRecorderService.shared.toggle()
        case .clipboard:
            MainActor.assumeIsolated { ClipboardEngine.shared.open() }
        case .windows:
            // Mission Control's view of every open window.
            let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
