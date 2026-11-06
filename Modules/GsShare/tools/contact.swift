// contact sheet: swift contact.swift out.png cols img...
import AppKit
let a = CommandLine.arguments; let out = a[1]; let cols = Int(a[2])!; let files = Array(a[3...])
let imgs = files.map { NSImage(contentsOfFile: $0)! }
let w: CGFloat = 400; let h = w * imgs[0].size.height / imgs[0].size.width
let rows = (imgs.count + cols - 1) / cols
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w) * cols, pixelsHigh: Int(h) * rows, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.5, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: w * CGFloat(cols), height: h * CGFloat(rows)).fill()
for (i, im) in imgs.enumerated() { let c = i % cols, r = rows - 1 - i / cols; im.draw(in: NSRect(x: CGFloat(c) * w, y: CGFloat(r) * h, width: w, height: h)) }
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
