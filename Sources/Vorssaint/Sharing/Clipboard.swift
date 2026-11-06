// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)
// G's Avengers — clipboard sharing (text + images)
import AppKit

final class Clipboard {
    enum Item { case text(String), png(Data) }
    var onLocalChange: ((Item) -> Void)?
    private var lastCount = NSPasteboard.general.changeCount
    private var watching = false
    private let maxBytes = 16 << 20

    /// Watches the pasteboard only while a trusted laptop is connected,
    /// through the app's one shared change-only watch.
    func start() {
        guard !watching else { return }
        lastCount = NSPasteboard.general.changeCount
        PasteboardWatch.shared.subscribe("sharing") { [weak self] in self?.poll() }
        watching = true
    }

    func stop() { PasteboardWatch.shared.unsubscribe("sharing"); watching = false }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount
        // skip passwords and other things apps mark as private
        if pb.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) == true { return }
        if let s = pb.string(forType: .string) {
            if s.utf8.count <= maxBytes { onLocalChange?(.text(s)) }
        } else if let png = pb.data(forType: .png) {
            if png.count <= maxBytes { onLocalChange?(.png(png)) }
        } else if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]), png.count <= maxBytes {
            onLocalChange?(.png(png))
        }
    }

    /// Put something that came from the other computer on this Mac's clipboard.
    func set(_ item: Item) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item {
        case .text(let t): pb.setString(t, forType: .string)
        case .png(let d):
            pb.setData(d, forType: .png)
            if let rep = NSBitmapImageRep(data: d), let tiff = rep.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
        }
        lastCount = pb.changeCount // don't echo it back
    }
}
