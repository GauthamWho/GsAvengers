// Draws the G's Avengers app icon in code (no image models). Usage: swift make_icon.swift <out.png> <size>
import AppKit
let out = CommandLine.arguments[1], S = CGFloat(Double(CommandLine.arguments[2])!)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ink = NSColor(red: 0x1A/255, green: 0x1B/255, blue: 0x22/255, alpha: 1)
let ink2 = NSColor(red: 0x2E/255, green: 0x2F/255, blue: 0x38/255, alpha: 1)
let paper = NSColor(red: 0xFF/255, green: 0xFD/255, blue: 0xF8/255, alpha: 1)
let accent = NSColor(red: 0xE4/255, green: 0x57/255, blue: 0x2E/255, alpha: 1)
let m = S * 0.09, r = NSRect(x: m, y: m, width: S - 2*m, height: S - 2*m)
let body = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
NSGradient(starting: ink2, ending: ink)!.draw(in: body, angle: -90)
// two screens, joined by a bridge
func screen(_ x: CGFloat, _ fill: NSColor, _ stroke: NSColor) {
  let w = r.width * 0.30, h = r.width * 0.22, y = r.midY - h/2 - r.width*0.02
  let p = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: w*0.12, yRadius: w*0.12)
  fill.setFill(); p.fill(); stroke.setStroke(); p.lineWidth = S*0.018; p.stroke()
}
screen(r.minX + r.width*0.12, paper.withAlphaComponent(0.10), paper)
screen(r.maxX - r.width*0.42, accent.withAlphaComponent(0.25), accent)
let bridge = NSBezierPath(); bridge.lineWidth = S*0.026; bridge.lineCapStyle = .round
bridge.move(to: NSPoint(x: r.minX + r.width*0.44, y: r.midY - r.width*0.02)); bridge.line(to: NSPoint(x: r.maxX - r.width*0.44, y: r.midY - r.width*0.02))
paper.setStroke(); bridge.stroke()
// the G
let f = NSFont.systemFont(ofSize: r.width*0.30, weight: .heavy)
let g = NSAttributedString(string: "G", attributes: [.font: f, .foregroundColor: paper])
let gs = g.size(); g.draw(at: NSPoint(x: r.midX - gs.width/2, y: r.maxY - r.width*0.06 - gs.height))
// accent dot
accent.setFill(); NSBezierPath(ovalIn: NSRect(x: r.midX + gs.width*0.42, y: r.maxY - r.width*0.20, width: r.width*0.07, height: r.width*0.07)).fill()
let sub = NSAttributedString(string: "AVENGERS", attributes: [.font: NSFont.systemFont(ofSize: r.width*0.075, weight: .bold), .foregroundColor: paper.withAlphaComponent(0.75), .kern: r.width*0.012])
let ss = sub.size(); sub.draw(at: NSPoint(x: r.midX - ss.width/2, y: r.minY + r.width*0.11))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
