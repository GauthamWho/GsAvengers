// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import SwiftUI

/// G’s Clipboard (fn V history, fn E emoji), running inside G’s Avengers
/// itself (it used to be a helper app). Nothing is built and nothing watches
/// the pasteboard until the Clipboard switch is on; switching it off tears
/// everything down again.
@MainActor
final class ClipboardEngine {
    static let shared = ClipboardEngine()

    private var panel: PanelController!
    private(set) var model: AppModel!
    private let hotKey = ClipboardHotKeys.shared
    private var previousApp: NSRunningApplication?
    /// The text field you were in when the panel opened; focused again before pasting.
    private var previousFocus: AXUIElement?
    private var state: PanelState!
    private var preview: PreviewController!

    private init() {}

    var isRunning: Bool { model != nil }

    func syncWithPreferences() {
        if AppFeature.clipboardHistory.isOn { start() } else { stop() }
    }

    func start() {
        guard model == nil else { return }
        model = AppModel()
        state = PanelState(model: model)
        state.onPick = { [weak self] item, paste in self?.pick(item, paste: paste) }
        state.onClose = { [weak self] in self?.closePanel() }
        state.onPickEmojiText = { [weak self] text, type in self?.pickEmoji(text, type: type) }
        state.onOpenSettings = { AvengersWindowController.shared.show(.clipboard) }
        panel = PanelController { [unowned self] in
            ContentView(state: self.state, model: self.model)
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
        hotKey.onPressed = { [weak self] slot in
            self?.togglePanel(from: nil, page: slot == .emoji ? .emoji : .all)
        }
        hotKey.start()
    }

    func stop() {
        guard model != nil else { return }
        if panel.isVisible { panel.hide() }
        hotKey.stop()
        model.stop()
        preview.hide()
        panel = nil; preview = nil; state = nil; model = nil
    }

    /// Accessibility was just granted: fn shortcuts can now install their tap.
    func accessibilityChanged() {
        guard isRunning else { return }
        hotKey.retryIfWaiting()
    }

    func open(page: PanelState.Filter = .all) {
        guard isRunning else { return }
        if panel.isVisible && state.filter == page { return }
        togglePanel(from: nil, page: page)
    }

    // MARK: - Panel

    /// Menu bar icon: drop down under it. Shortcut: open right next to your text cursor.
    /// `page`: fn V opens the clipboard, fn E opens straight on Emoji. Pressing the other
    /// shortcut while the panel is open flips the page; the same one closes it.
    func togglePanel(from button: NSStatusBarButton?, page: PanelState.Filter = .all) {
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

}
