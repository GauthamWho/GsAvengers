// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import Combine

/// The one menu-bar icon. Left click opens the G’s Avengers window, right
/// click a small menu. The icon only changes when keep-awake starts or
/// stops (a notification, never a timer).
final class StatusItemController {
    private(set) var statusItem: NSStatusItem!
    var onLeftClick: (() -> Void)?
    var onRightClick: ((NSStatusBarButton?) -> Void)?
    private var watch: AnyCancellable?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "GsAvengersStatusItem"
        statusItem.behavior = []
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.image = MenuBarGlyph.image(active: false)
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = AppInfo.name
        }
        watch = KeepAwakeManager.shared.$isActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.statusItem.button?.image = MenuBarGlyph.image(active: active) }
    }

    var button: NSStatusBarButton? { statusItem.button }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            onRightClick?(statusItem.button)
        } else {
            onLeftClick?()
        }
    }

    /// Shows the icon again if macOS hid it.
    func reshow() { statusItem.isVisible = true }
}

/// The bundled mark (a template image, so it follows light and dark menu
/// bars); orange while keep-awake holds the Mac awake.
enum MenuBarGlyph {
    static let pointSize = NSSize(width: 26, height: 20)

    private static let base: NSImage? = {
        let image = NSImage(size: pointSize)
        for resource in ["MenuBarIcon", "MenuBarIcon@2x"] {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let rep = NSBitmapImageRep(data: data)
            else { continue }
            rep.size = pointSize
            image.addRepresentation(rep)
        }
        guard !image.representations.isEmpty else { return nil }
        image.isTemplate = true
        return image
    }()

    static func image(active: Bool) -> NSImage? {
        guard let mark = base ?? fallback else { return nil }
        guard active else { return mark }
        let tinted = NSImage(size: mark.size, flipped: false) { rect in
            mark.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.systemOrange.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }

    /// Keeps a clickable icon if the bundled asset is missing (bare binary).
    private static let fallback: NSImage? = {
        let symbol = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: AppInfo.name)
        symbol?.isTemplate = true
        return symbol
    }()
}
