// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

// The runner lists every independently selectable suite. A filtered run says
// exactly which suites ran; an unknown or empty selection is an error.
@main
struct AvengersTests {
    static func main() {
        let suite = TestSuite()
        let groups: [(String, () -> Void)] = [
            ("harness", {
                TestHarnessTests.run(suite)
                PreferenceNamespaceTests.run(suite)
            }),
            ("features", { AvengersFeatureTests.run(suite) }),
            ("sharing", { SharingKeyRulesTests.run(suite) }),
            ("window-layout", {
                WindowStageManagerTests.run(suite)
                WindowVisibilityTests.run { suite.expect($0, $1) }
                WindowFocusHistoryTests.run { suite.expect($0, $1) }
            }),
            ("overlays", { OverlayPanelTests.run(suite) }),
            ("screenshot", {
                ScreenshotClipboardTests.run(suite)
                ScreenshotAutoCopyTests.run(suite)
                ScreenshotCanvasSupportTests.run(suite)
                ScreenTextCompletionTests.run(suite)
                ScreenshotOCRControlTests.run(suite)
                ScreenshotPreviewHoverTests.run(suite)
                RecentCapturePanelTests.run(suite)
                ScreenshotSpotlightEditingTests.run(suite)
                ScreenshotShareCompletionTests.run(suite)
                ScreenshotScrollingCaptureTests.run(suite)
                ScreenshotAttachedCaptureTests.run(suite)
                ScreenshotToolShortcutTests.run(suite)
                RecentCaptureStoreTests.run(suite)
            }),
            ("recorder", {
                RecorderGIFWriterTests.run(suite)
                RecorderZoomAimingTests.run(suite)
                RecorderExportSpeedTests.run(suite)
                RecorderExportRenderingTests.run(suite)
                RecorderPresetImageStoreTests.run(suite)
                RecorderPreparationTests.run(suite)
                RecorderSampleTimingTests.run(suite)
                RecorderWriterTests.run(suite)
                RecorderSystemAudioTrustTests.run(suite)
                RecorderExportChipTests.run { suite.expect($0, $1) }
            }),
            ("quick-ring", { QuickRingTests.run(suite) }),
            ("localization", {
                LocalizationTests.run(suite)
                LocalizationFeatureContractTests.run(suite)
            }),
            ("dock-preview", {
                DockPreviewPositionTests.run(suite)
                DockPreviewScrollTests.run(suite)
                DockPreviewScopeTests.run(suite)
                DockAutohideHoldTests.run(suite)
                DockPreviewFrameRestorationTests.run(suite)
            }),
            ("switcher", {
                SwitcherAllWindowsTests.run(suite)
                AXWindowResolverTests.run(suite)
                SwitcherSearchLayoutTests.run(suite)
                SwitcherScrollContract.run(suite)
                SwitcherActivationTests.run(suite)
                AXHiddenSpaceLookupTests.run(suite)
                SwitcherWindowCloseTests.run(suite)
                SwitcherAccessibilitySnapshotTests.run(suite)
                WindowServerCaptureContract.run(suite)
                ScrollingTitleMotionTests.run(suite)
                AssistiveKeyboardTests.run(suite)
            }),
            ("keep-awake", {
                KeepAwakeTimerHandoffTests.run { suite.expect($0, $1) }
            }),
        ]
        var selected = Set<String>()
        var listOnly = false
        for argument in CommandLine.arguments.dropFirst() {
            if argument == "--list" {
                listOnly = true
                continue
            }
            guard argument.hasPrefix("--suite="),
                  groups.contains(where: { $0.0 == String(argument.dropFirst(8)) }) else {
                fputs("Unknown test selection: \(argument)\n", stderr)
                exit(2)
            }
            selected.insert(String(argument.dropFirst(8)))
        }
        if listOnly {
            groups.forEach { print($0.0) }
            exit(0)
        }
        for (name, body) in groups where selected.isEmpty || selected.contains(name) {
            suite.run(name, body)
        }
        suite.finish()
    }
}
