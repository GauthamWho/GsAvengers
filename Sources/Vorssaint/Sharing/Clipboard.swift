// G's Avengers — clipboard sharing (text + images)
import AppKit

final class Clipboard {
    enum Item { case text(String), png(Data) }
    var onLocalChange: ((Item) -> Void)?
    private var lastCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let maxBytes = 16 << 20

    /// Watches the pasteboard only while a trusted laptop is connected.
    /// macOS has no pasteboard-changed notification, so it reads the change
    /// count (one integer, no data) every half second.
    func start() {
        guard timer == nil else { return }
        lastCount = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() { timer?.invalidate(); timer = nil }

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
