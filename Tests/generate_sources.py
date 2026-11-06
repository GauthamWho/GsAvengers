#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Compile selected production methods against test doubles, without an app.

Bodies are read verbatim on every build, never copied into a maintained fixture.
The narrow declaration/indentation contract fails closed if a method moves or
changes shape; the Swift compiler then checks the generated source normally.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/generated-tests"


def declaration(path, prefix, scope=None):
    lines = (ROOT / path).read_text().splitlines(keepends=True)
    lower, upper = 0, len(lines)
    if scope is not None:
        scopes = [i for i, line in enumerate(lines) if line.startswith(scope)]
        if len(scopes) != 1:
            raise ValueError(f"Expected one scope {scope!r} in {path}")
        lower = scopes[0] + 1
        upper = next(i for i in range(lower, len(lines)) if lines[i].rstrip() == "}")
    starts = [i for i in range(lower, upper) if lines[i].startswith(prefix)]
    if len(starts) != 1:
        raise ValueError(f"Expected one declaration {prefix!r} in {path}")
    start = starts[0]
    indent = prefix[:len(prefix) - len(prefix.lstrip())]
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip() == indent + "}")
    body = "".join(lines[start:end + 1])
    return f'#sourceLocation(file: {json.dumps(path)}, line: {start + 1})\n{body}\n#sourceLocation()\n'


def write(name, text):
    path = OUTPUT / name
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


def availability_declaration(path, prefix):
    return declaration(path, prefix).replace(".feature.isAvailable", ".feature.isAvailable(in: ReviewDefaults.current)")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    slider_area = "Sources/Vorssaint/UI/SliderScrollArea.swift"
    wheel_route = "Sources/Vorssaint/Services/HorizontalWheelScrolling.swift"
    recent_captures = "Sources/Vorssaint/Services/QuickTools/RecentCaptureService.swift"
    write("RecentCapturePanel.swift", "import Foundation\nimport Carbon.HIToolbox\n"
          + "extension RecentCapturePanelTests {\nfinal class Service: Fixture {\n"
          + "".join(declaration(recent_captures, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func installPanelMonitors(",
                                   "    private func removePanelMonitors()", "    func hideHistoryWindow()"])
          + "}\n}\n")
    resolver = "Sources/Vorssaint/Services/Switcher/AXWindowResolver.swift"
    resolver_lines = (ROOT / resolver).read_text().splitlines()
    resolver_constants = "".join(
        next(line for line in resolver_lines if line.startswith(prefix))
        .replace("private static", "static", 1) + "\n"
        for prefix in ["    private static let remoteElementIDLimit:",
                       "    static let remoteLookupBudget:"])
    write("AXHiddenSpaceLookup.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension AXHiddenSpaceLookupTests.Resolver {\n"
          + resolver_constants
          + "".join(declaration(resolver, prefix).replace("private static", "static", 1)
                    for prefix in ["    static func elementsOnHiddenSpace(",
                                   "    static func prepareForRequest("])
          + "}\n")
    recorder = "Sources/Vorssaint/Services/Recorder/ScreenRecorderService.swift"
    write("RecorderPreparation.swift", "import Foundation\nextension RecorderPreparationTests {\n"
          + "final class Service: Fixture {\n"
          + "".join(declaration(recorder, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func beginRecording(", "    private func pendingStartIsAuthorized(",
                                   "    private func invalidatePendingStart()", "    var hasActiveCapture:",
                                   "    func stopOrCancelActiveCapture()", "    func prepareForSelection()"])
          + "}\n}\n")
    tap = "Sources/Vorssaint/Services/Recorder/RecorderSystemAudioTap.swift"
    write("RecorderSystemAudioTrust.swift", "import Accelerate\nimport AVFoundation\nimport Darwin\n"
          + "extension RecorderSystemAudioTrustTests {\n"
          + declaration(tap, "final class RecorderAudioFlag {")
          + declaration(tap, "final class RecorderAudioHostTime {")
          + declaration(tap, "enum RecorderAudioProbe {")
          + "final class Session: Fixture {\n"
          + declaration(recorder, "    private func streamHeardSound(against").replace("private func", "func", 1)
          # The first line alone tells it from the one-line didStopWith callback.
          + declaration(recorder, "    func captureEngine(_ engine: RecorderCaptureEngine,\n")
          + "}\n}\n")
    write("SwitcherAccessibilitySnapshot.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension SwitcherAccessibilitySnapshotTests.Reader {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Switcher/WindowEnumerator.swift", prefix)
                    .replace("private ", "", 1) for prefix in [
                        "    private struct AccessibilityWindowSnapshot {",
                        "    private struct AccessibilityWindowSnapshotList {",
                        "    private struct AccessibilityWindowAttributes {",
                        "    private enum WindowReading {",
                        "    private static func accessibilityWindows(for pid: pid_t,",
                        "    private static func userFacingReading(",
                        "    private static func frameLooksFullscreen(",
                        "    private static func hasWorkingMinimizeButton(",
                        "    private static func accessibilityWindowAttribute(",
                        "    private static func boolAttribute(",
                        "    private static func appendUnique(", "    private static func contains("])
          + "}\n")
    cleaner_view = "Sources/Vorssaint/UI/Cleaner/CleanerView.swift"
    write("ScrollingCaptureLoop.swift", "import AppKit\nimport CoreGraphics\n"
          + "extension ScreenshotScrollingCaptureTests {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotScrollingCapture.swift",
                        "enum ScreenshotScrollingCapture {").replace(
                            "    private static func stitch(", "    static func stitch(")
          + "}\n")
    editor = "Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift"
    write("ScreenshotClipboard.swift", "import AppKit\nextension ScreenshotClipboardTests {\n"
          + "final class Editor: State {\n"
          + "".join(declaration(editor, prefix).replace(
              "ScreenshotSupport.copiedFilesDirectory()", "ScreenshotClipboardTests.copyDirectory")
              for prefix in [
              "    func copyToClipboard()", "    static func copyImage(", "    static func copyFile(",
              "    struct ClipboardPayload:",
              "    static func clipboardPayload(from export: ScreenshotRenderer.Export) ->",
              "    static func clipboardPayload(from export: ScreenshotRenderer.Export,",
              "    static func copyClipboardPayload("])
          + "}\n}\n")
    expansion_preview = "Sources/Vorssaint/UI/Screenshot/ScreenshotCanvasExpansionPreview.swift"
    write("ScreenshotExpansionPreviewChrome.swift", "import SwiftUI\n"
          + "extension ScreenshotCanvasSupportTests {\nenum ExpansionPreview {\n"
          + declaration(expansion_preview, "    struct Layout {")
          + declaration(expansion_preview, "    static func cardHole(")
          + "}\n}\n")
    panel = "Sources/Vorssaint/App/AppDelegate.swift"
    activator = "Sources/Vorssaint/Services/Switcher/WindowActivator.swift"
    resolver = "Sources/Vorssaint/Services/Switcher/AXWindowResolver.swift"
    (OUTPUT / "AXWindowResolver.swift").unlink(missing_ok=True)
    write("AXWindowResolverContract.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension AXWindowResolverTests.Resolver {\n"
          + resolver_constants
          + "".join(declaration(resolver, prefix).replace("private static", "static", 1)
                    for prefix in ["    static func windowID(", "    static func element(",
                                   "    private static func actionElement(",
                                   "    private static func resolveRemoteElement(",
                                   "    static func elementsOnHiddenSpace(",
                                   "    static func prepareForRequest(", "    private static func isWindow("])
          + "}\n")
    write("SwitcherActivationBodies.swift", "import AppKit\nimport ApplicationServices\n"
          + declaration(activator, "final class SwitcherActivationWriteGuard {")
              .replace("NSEvent", "SwitcherActivationTests.InputEvent")
          + "extension SwitcherActivationTests.Activator {\n"
          + "".join(declaration(activator, prefix).replace("private static", "static", 1)
                    for prefix in ["    private static func activateApp(",
                                   "    static func activateAppCooperatively(",
                                   "    private static func activateSource(",
                                   "    static func activationMinimizedState(",
                                   "    static func windowMinimizedState(target:"])
          + "}\nextension SwitcherActivationTests.HiddenSpaceActivator {\n"
          + "".join(declaration(activator, prefix).replace("private static", "static", 1)
                    for prefix in ["    static func raiseWindowOnHiddenSpace(",
                                   "    private static func scheduleSourceStaging(",
                                   "    private static func prepareWindowForActivation(",
                                   "    private static func restoreWindowBeforeFocus(",
                                   "    static func focusWindow(",
                                   "    private static func stageSourceBehindTargetIfNeeded("])
          + "}\nextension SwitcherActivationTests.Bridge {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift", prefix)
                    .replace("private static", "static", 1) for prefix in [
                        "    static func frontWindow(", "    static func focusWithoutRaise(",
                        "    private static func makeKeyWithoutRaise("])
          + declaration("Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift",
                        "    private static func postFocusRecord(")
          .replace("private static", "@discardableResult static", 1)
          + "}\n")
    write("SwitcherWindowClose.swift", "import AppKit\nimport ApplicationServices\n"
          + "extension SwitcherWindowCloseTests.Activator {\n"
          + "".join(declaration(activator, prefix)
                    .replace("fileprivate static", "static", 1)
                    .replace("private static", "static", 1)
                    .replace("    static func finishPendingWindowClose(",
                             "    @discardableResult\n    static func finishPendingWindowClose(", 1)
                    for prefix in ["    static func closeWindow(", "    private static func closableElement(",
                                   "    private static func leaveFullscreenToClose(",
                                   "    static func closeWindowIncludingHiddenState(",
                                   "    fileprivate static func finishPendingWindowClose(",
                                   "    fileprivate static func windowExistsForClose("])
          + "}\nextension SwitcherWindowCloseTests {\n"
          + declaration(activator, "fileprivate final class SwitcherPendingWindowClose")
              .replace("fileprivate final class", "final class", 1)
          + "}\n")
    write("WindowServerCapture.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension WindowServerCaptureContract.Provider {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/WindowPreviewProvider.swift",
                        "    static func captureViaWindowServer(")
          + "}\n")
    write("ScreenshotAttachedCapture.swift", "import AppKit\nimport ScreenCaptureKit\n"
          + "extension ScreenshotAttachedCaptureTests {\nenum Engine {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotCaptureEngine.swift",
                        "    private static func composeAttached(").replace("private static", "static", 1)
          + "}\n}\n")
    ports = "Sources/Vorssaint/Services/PortManager/PortManagerService.swift"
    disk_sampler = "Sources/Vorssaint/Services/Metrics/DiskSampler.swift"
    monitor = "Sources/Vorssaint/Services/SystemMonitor/SystemMonitor.swift"
    uninstall = "Sources/Vorssaint/Services/Uninstall/AppUninstaller.swift"
    paste_plain = "Sources/Vorssaint/Services/QuickTools/PastePlainService.swift"
    disk_image = "Sources/Vorssaint/Services/DiskImageInstaller/DiskImageInstallerService.swift"
    cleaner = "Sources/Vorssaint/Services/URLCleanerService.swift"
    homebrew = "Sources/Vorssaint/Services/Homebrew/HomebrewManager.swift"
    dock = "Sources/Vorssaint/Services/DockPreview/DockPreviewService.swift"
    write("DockPreviewScroll.swift", "import AppKit\nimport SwiftUI\n"
          + "extension DockPreviewScrollTests {\n"
          + declaration("Sources/Vorssaint/UI/Switcher/DockPreviewPanelView.swift",
                        "private struct DockPreviewPanelContent:").replace("private struct", "struct", 1)
          + "}\n")
    write("DockPreviewPosition.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension DockPreviewPositionTests.Service {\n"
          + "".join(declaration(dock, prefix, scope="final class DockPreviewService:")
                    .replace("private func", "func", 1)
                    for prefix in ["    private func handleMouseMoved(",
                                   "    private func currentZone(",
                                   "    private func showPanel(",
                                   "    private func resizePanelForCurrentWindows()",
                                   "    private func clampedPanelFrame("])
          + "}\n")
    write("DockPreviewFrameRetry.swift", "import Foundation\nextension DockPreviewFrameRestorationTests {\n"
          + declaration("Sources/Vorssaint/Services/DockPreview/DockPreviewFrameRestoration.swift",
                        "    private static func restore(").replace("private static func", "static func", 1)
          + "}\n")
    write("DockPreviewScope.swift", "import Foundation\nextension DockPreviewScopeTests.Service {\n"
          + "".join(declaration(dock, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func syncSpaceObservation()",
                                   "    private func stopSpaceObservation()"])
          + "}\nextension DockPreviewScopeTests.WindowEnumerator {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/WindowEnumerator.swift",
                        "    static func dockPreviewMayActivate(")
          + "}\n")
    write("DockAutohideInput.swift", "import CoreGraphics\nimport Foundation\nextension DockAutohideHoldTests.Service {\n"
          + "".join(declaration(dock, prefix, scope="final class DockPreviewService:")
                    .replace("private func", "func", 1)
                    for prefix in ["    private func beginDockAutohideHold()",
                                   "    private func releaseDockAutohideHold()",
                                   "    private func handleDockHoldInput(type:",
                                   "    func commit("])
          + "}\n")
    # The raw wheel tap runs as shipped: linear scrolling's cap, carry and
    # write-back, then the direction change. Only the services it asks and
    # the defaults it reads are fixtures.
    mouse_buttons = "Sources/Vorssaint/Services/MouseButtons/MouseButtonShortcutService.swift"
    smooth = "Sources/Vorssaint/Services/SmoothScrollService.swift"
    # Entire input/mute services retain their production control flow. Only
    # visibility, scheduling, defaults and HAL transport are replaced by fixtures.
    input_source = "Sources/Vorssaint/Services/Audio/AudioInputDeviceManager.swift"
    mute_source = "Sources/Vorssaint/Services/QuickTools/MicMuteService.swift"
    mixer = "Sources/Vorssaint/Services/Audio/AppVolumeMixer.swift"
    tap_scope = "private final class TapGainEngine:"
    callback_start = "guard AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregateID, nil, { now, input, _, output, _ in\n"
    cleaner = "Sources/Vorssaint/Services/Cleaner/JunkCleaner.swift"

    super_key = "Sources/Vorssaint/Services/SuperKey/SuperKeyService.swift"


    updates = "Sources/Vorssaint/Services/AppUpdates/AppUpdatesService.swift"
    loader = "Sources/Vorssaint/Services/AppUpdates/AppUpdateFeedLoader.swift"
    # Only the network configuration, clock and declaration visibility change.
    # The loader, batch loop, catalog matching and fallback resolution stay verbatim.
    # Rule mutations and completion stay verbatim; only declaration visibility changes.
    usage = "Sources/Vorssaint/Services/SystemMonitor/ProcessUsageService.swift"
    quit_panel = "Sources/Vorssaint/Services/QuickTools/QuitAppsPanelController.swift"
    quit_service = "Sources/Vorssaint/Services/QuickTools/QuickTogglesService.swift"
    write("OverlayPanelDeclaration.swift", "import AppKit\n"
          + declaration("Sources/Vorssaint/UI/OverlayPanel.swift", "class OverlayPanel:"))
    shelf = "Sources/Vorssaint/Services/Shelf/ShelfService.swift"
    recorder = "Sources/Vorssaint/Services/Recorder/RecorderEditorController.swift"
    write("RecorderZoomAiming.swift", "import Foundation\nimport Combine\n"
          + "extension RecorderZoomAimingTests {\nfinal class Model: State {\n"
          + declaration(recorder, "    @Published var document:").replace("@Published var", "override var", 1)
          + declaration(recorder, "    @Published var selectedZoomID:")
          + "".join(declaration(recorder, prefix) for prefix in [
              "    private func documentDidChange(", "    func undo()", "    func redo()",
              "    private func apply(_ next:", "    func zoom(_ id:",
              "    func beginAiming(", "    func endAiming(", "    func aim(",
              "    func setSelectedZoomFocus(", "    private func applyDuringInteraction(",
              "    func beginPickingBlurArea(", "    func endPickingBlurArea("])
          + "}\n}\n")
    update = "Sources/Vorssaint/Services/Update/UpdateService.swift"
    renderer = "Sources/Vorssaint/App/MenuBarRenderer.swift"
    spacing = "Sources/Vorssaint/App/MenuBarSpacingSupport.swift"
    # The Features page's wording and route live outside the tests, so the
    # row's copy speaks the feature's name and goes nowhere.
    media_workspace = "Sources/Vorssaint/UI/Media/MediaWorkspaceView.swift"
    write("RecorderExportChip.swift", "import AppKit\nimport SwiftUI\n\nextension RecorderExportChipTests {\n"
          + "struct Chip: View {\n@ObservedObject var model: Model\nlet strings = Strings()\n"
          + "var exportProgressLabel: String { strings.exportingLabel }\n"
          + "var body: some View { exportProgressChip }\n"
          + declaration("Sources/Vorssaint/UI/Recorder/RecorderEditorView.swift", "    private var exportProgressChip:")
          + "}\n}\n")
    switcher = "Sources/Vorssaint/UI/Switcher/SwitcherView.swift"
    switcher_service = "Sources/Vorssaint/Services/Switcher/AppSwitcher.swift"
    write("SwitcherAllWindows.swift", "import AppKit\n"
          + "extension SwitcherAllWindowsTests.Model {\n"
          + "".join(declaration(switcher_service, prefix).replace("private ", "", 1)
                    for prefix in ["    private func initialSelectionIndex(",
                                   "    private func advanceSelection(",
                                   "    private func advanceAppSelection(",
                                   "    private func advanceWindowInSelectedApp("])
          + "}\n")
    write("SwitcherScroll.swift", "import AppKit\nimport SwiftUI\n"
          + "extension SwitcherScrollContract {\nstruct Strip: View {\n"
          + "@ObservedObject var switcher: Model\n"
          + "var instantSelection = false\n"
          + "var iconRowContentWidth: CGFloat { switcher.iconRowLayout.contentWidth(simpleMode: true, windowRow: false) }\n"
          + "var body: some View {\nif selectedWindow != nil {\nlet appWindows = selectedAppWindows\n"
          + "if switcher.simple {\nGroup {\n"
          + declaration(switcher, "                ScrollViewReader { proxy in")
          + "}\n.frame(width: iconRowContentWidth - 2 * SwitcherIconRowLayout.simpleTitlePanelPadding, "
          + "height: 25 * SwitcherIconRowLayout.scale)\n} else {\n"
          + declaration(switcher, "                    ScrollViewReader { proxy in")
          + "}\n}\n}\n"
          + declaration(switcher, "    private var selectedWindow:")
          + declaration(switcher, "    private var selectedAppWindows:")
          + declaration(switcher, "    private func revealSelection(")
          + "}\n}\nextension SwitcherScrollContract.Model {\n"
          + "func search(_ query: String) { searchQuery = query; applySearchFilter(preferredItemID: selectedItemID) }\n"
          + declaration(switcher_service, "    private var selectedItemID:")
          + declaration(switcher_service, "    private func applySearchFilter(")
          + "}\n")
    write("SwitcherSearchLayout.swift", "import AppKit\nimport SwiftUI\n"
          + "extension SwitcherSearchLayoutTests {\n"
          + declaration(switcher_service, "struct SwitcherGrid:")
          + declaration(switcher, "private enum SwitcherIconStyle {").replace("private enum", "enum", 1)
          + "}\nextension SwitcherSearchLayoutTests.Model {\n"
          + "typealias SwitcherGrid = SwitcherSearchLayoutTests.SwitcherGrid\n"
          + "".join(declaration(switcher_service, prefix).replace("private ", "", 1)
                    for prefix in ["    private var currentPanelSize:", "    var searchTopInset:",
                                   "    private func pinSearch()"])
          + "}\nextension SwitcherSearchLayoutTests.Host {\n"
          + "".join(f"typealias {name} = SwitcherSearchLayoutTests.{name}\n"
                    for name in ["SwitcherGrid", "HUDBackdrop", "SwitcherIconStyle", "SwitcherIconRowSurface"])
          + declaration(switcher, "    var body: some View {", scope="struct SwitcherView: View {")
              .replace("    var body:", "    @ViewBuilder var body:", 1)
          + "".join(declaration(switcher, prefix).replace("private ", "", 1)
                    for prefix in ["    private var standardPanel:", "    private var iconRowPanel:",
                                   "    private var iconRowPanelSize:"])
          + declaration(switcher, "    private var searchChip:").replace("    private var", "    @ViewBuilder var", 1)
          + "}\n")
    service = "Sources/Vorssaint/Services/QuickTools/QuickLauncherService.swift"
    view = "Sources/Vorssaint/UI/QuickLauncher/QuickLauncherView.swift"
    # The panel's tabs and the rows they hold, as shipped. PanelOrderItem is
    # declared once, in QuickLauncherBodies.swift above.


    preview = "Sources/Vorssaint/Services/QuickTools/ScreenshotQuickPreviewController.swift"
    screen_text = "Sources/Vorssaint/Services/QuickTools/ScreenTextService.swift"
    write("ScreenshotOCRControl.swift", "import AppKit\nimport SwiftUI\n"
          + "extension ScreenshotOCRControlTests {\n"
          + declaration(preview, "final class ScreenshotQuickPreviewModel:")
          + declaration(preview, "private struct ScreenshotQuickPreviewView:").replace("private struct", "struct", 1)
          + "enum ScreenshotQuickPreviewController {\n"
          + declaration(preview, "    enum Action {")
          + declaration(preview, "    fileprivate static func size(").replace("fileprivate", "", 1)
          + "}\n}\nextension View {\n"
          + declaration("Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift", "    func screenshotSafeHelp(")
              .replace("    func", "    @ViewBuilder\n    func", 1)
          + "}\n")
    write("ScreenTextCompletion.swift", "import Foundation\n"
          + "extension ScreenTextCompletionTests {\nfinal class ScreenTextService: State {\n"
          + "".join(declaration(screen_text, prefix).replace("private func", "func", 1)
                    for prefix in ["    func copyText(", "    func receiveUnifiedCapture(",
                                   "    private func recognize(", "    func syncWithPreferences()",
                                   "    func suspend()", "    private func cancelSession()",
                                   "    enum Outcome:"])
          + "}\n}\n")
    write("ScreenshotShareCompletion.swift", "import Foundation\n"
          + "extension ScreenshotShareCompletionTests {\nfinal class Controller: State {\n"
          + "".join(declaration(preview, prefix).replace("private func", "func", 1)
                    for prefix in ["    func shareLink()", "    private func performShare(",
                                   "    private func copySharedLink()", "    private func scheduleAutoDismiss(",
                                   "    private func copyText()"])
          + "}\nfinal class Editor: EditorState {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift",
                        "    func share(duration:")
          + "}\n@MainActor final class CreationGate: CreationState {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotShareService.swift",
                        "    func createLink(pngData:")
          + "}\n}\n")
    screenshot_service = "Sources/Vorssaint/Services/QuickTools/ScreenshotService.swift"
    write("ScreenshotAutoCopy.swift", "import Foundation\nextension ScreenshotAutoCopyTests {\n"
          + "@MainActor final class Service: State {\n"
          + declaration(screenshot_service, "    private func autoCopy(").replace("private func", "func", 1)
          + "}\n}\n")
    write("ScreenshotShortcutCompletion.swift", "import Foundation\n"
          + "extension ScreenshotShareCompletionTests {\n@MainActor final class Uploader: UploadState {\n"
          + "".join(declaration(screenshot_service, prefix).replace("private func", "func", 1)
                    .replace("uploadShortcutEnabled()", "uploadShortcutEnabled(in: defaults)")
                    .replace("retainsLatestCapture()", "retainsLatestCapture(in: defaults)")
                    for prefix in ["    private func uploadLastCapture()", "    private func copyUploadedLink(",
                                   "    func openEditor(with", "    func editorDidClose(",
                                   "    private func invalidateLatestCaptureUploads()",
                                   "    private func beginLatestCapture(", "    private func discardLatestCapture(",
                                   "    private func withholdLatestCapture()", "    private func syncLatestCapture(",
                                   "    func afterAutoCopy("])
          + "}\n}\n")
    write("ScreenshotPreviewHover.swift", "import Foundation\n"
          + "extension ScreenshotPreviewHoverTests {\nfinal class Controller: State {\n"
          + "".join(declaration(preview, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func hoverChanged(", "    private func scheduleAutoDismiss(",
                                   "    private func perform("])
          + "}\n}\n")
    editor = "Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift"
    editor_view = "Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift"
    write("ScreenshotSpotlightEditing.swift", "import CoreGraphics\nimport Foundation\nimport SwiftUI\n"
          + "extension ScreenshotSpotlightEditingTests {\nfinal class Model: State {\n"
          + declaration(editor, "    @Published var spotlightDimStrength: CGFloat {")
          .replace("@Published var", "override var", 1)
          + "".join(declaration(editor, prefix).replace("private func", "func", 1)
                    for prefix in ["    func beginDrag(at point:", "    func selectedAnnotationOwns(",
                                   "    func hitTest(", "    private func refreshDirtyState()"])
          + "}\nstruct Bar {\nlet model: Model\n"
          + "".join(declaration(editor_view, prefix).replace("private var", "var", 1)
                    for prefix in ["    private var showsColorControls:",
                                   "    private var showsSpotlightControls:",
                                   "    private var spotlightDimValue:"])
          + declaration(editor_view, "    private func updateHoverCursor(").replace("private func", "func", 1)
          + "}\n}\n")
    selection = "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift"
    refresh_methods = [
        "    private func screenCaptureToolDidChange()",
        "    private func adoptCapturePolicy(",
        "    private func applySource(",
        "    private func loadLiveLoupeImages()",
        "    private func markCapturePending()",
        "    private func confirmSelectionWithKeyboard()",
        "    private func captureFullDisplayUnderMouse()",
        "    fileprivate func captureFullScreenFromControl(",
        "    private func captureFullDisplay(",
        "    private func repeatLastRegion()",
        "    fileprivate func confirmWindow(",
        "    fileprivate func confirmRegion(",
        "    fileprivate func confirmColor(",
    ]
    hop = "Sources/Vorssaint/Services/Switcher/SpaceHop.swift"






    keep_awake = "Sources/Vorssaint/Services/KeepAwakeManager.swift"
    keep_awake_methods = [
        "    func refreshPasswordlessStatus(",
        "    func activate(minutes:",
        "    func activate(until date:",
        "    func startLastPick(",
        "    func resumeAfterSystemTeardown(",
        "    private func activate(end:",
        "    func deactivate(reason:",
        "    private func applyClamshellPreference(",
        "    private func prepareClamshellPreference(",
        "    private func finishClamshellSetup(",
        "    private func markClamshellSetupFailed(",
        "    private func enableClamshell(",
        "    private func disableClamshell(",
        "    private func sleepIfLidAlreadyClosed(",
        "    func recoverIfNeeded(",
        "    private func finishRecovery(",
        "    private var clamshellNeedsRestore:",
        "    private func finishClamshellRestore(",
        "    private func recoverDimmedDisplayIfNeeded(",
        "    private func syncLidDimmingObserver(",
        "    private func lidStateMayHaveChangedForDimming(",
        "    private func applyDimmingAction(",
        "    private func attemptDisplayRestore(",
    ]
    write("KeepAwakeTimerHandoff.swift", "import Foundation\n\nextension KeepAwakeTimerHandoffContract {\n"
          + "final class Service {\nvar sessionTrigger = SessionTrigger.manual\n"
          + "var automationSuppressedUntilConditionsClear = false\n"
          + "var activeAutomationConditions: Set<KeepAwakeAutomationCondition> = []\n"
          + "var enabled: Set<KeepAwakeAutomationCondition> = []\n"
          + "var matching: Set<KeepAwakeAutomationCondition> = []\n"
          + "var requireAll = false\nvar batteryAllows = true\n"
          + "var activations: [(end: Date?, trigger: SessionTrigger)] = []\n"
          + "func automaticSessionAllowedByBatteryProtection() -> Bool { batteryAllows }\n"
          + "func currentMatchingAutomationConditions() -> Set<KeepAwakeAutomationCondition> { matching }\n"
          + "func currentEnabledAutomationConditions() -> Set<KeepAwakeAutomationCondition> { enabled }\n"
          + "func automationRequiresAllConditions() -> Bool { requireAll }\n"
          + "func activate(end: Date?, trigger: SessionTrigger) { activations.append((end, trigger)) }\n"
          + declaration(keep_awake, "    private func continueAutomaticallyAfterTimerIfNeeded()")
            .replace("private func", "func", 1)
          + "}\n}\n")

    spaces_order = "Sources/Vorssaint/Services/SpacesOrder/SpacesOrderHold.swift"

    self_uninstall = "Sources/Vorssaint/Services/SelfUninstall.swift"


    window_directional = "Sources/Vorssaint/Services/WindowLayout/WindowLayoutService.swift"
    window_maximizer = "Sources/Vorssaint/Services/WindowMaximizer.swift"
    window_gesture = "Sources/Vorssaint/Services/WindowLayout/WindowGestureSupport.swift"

    factories = []
    pattern = r"static\s+func\s+(\w+)\s*\(\s*_\s+\w+:\s*AppLanguage\s*\)\s*->"
    for path in sorted((ROOT / "Sources/Vorssaint/Core").glob("*Strings.swift")):
        source = path.read_text()
        if "extension FeatureStrings" in source or "enum FeatureStrings" in source:
            scopes = re.findall(r"(?:extension|enum) FeatureStrings \{(.*?)^\}", source, re.S | re.M)
            names = [name for scope in scopes for name in re.findall(pattern, scope)]
            if not names:
                raise ValueError(f"No language factory found in {path}")
            factories.extend(names)
    if not factories or len(factories) != len(set(factories)):
        raise ValueError("Missing or duplicate localization factories")
    write("LocalizationCatalog.swift", "extension LocalizationTests {\n"
          + "static let factories: [(String, (AppLanguage) -> Any)] = [\n"
          + "".join(f'("{name}", {{ FeatureStrings.{name}($0) }}),\n' for name in factories)
          + "]\n}\n")

    screens = "Sources/Vorssaint/Core/AppKitExtensions.swift"
    bridge = "Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift"


    write("ScrollingTitleMotion.swift", "import Foundation\n"
          + "extension ScrollingTitleMotionTests {\nfinal class Host: Fixture {\n"
          + declaration("Sources/Vorssaint/UI/Switcher/ScrollingTitle.swift",
                        "    private var shouldScroll:").replace("private var", "var", 1)
          + "}\n}\n")






    # Same-file extensions exercise private routing and AppKit content without
    # widening production interfaces or presenting an application window.
    service = "Sources/Vorssaint/Services/QuitProtection/QuitProtectionService.swift"
    checks = "Tests/Fixtures/QuitProtectionRoutingChecks.swift"
    hud = "Sources/Vorssaint/UI/QuitProtection/QuitProtectionHUD.swift"
    checks = "Tests/Fixtures/QuitProtectionHUDChecks.swift"


if __name__ == "__main__":
    main()
