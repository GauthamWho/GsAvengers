// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI
import AppKit

/// "Quiet instrument", clipboard edition. Visual reference: design/stylesheet.html.
/// Wording: design/CONTENT.md. Every view reads tokens from here.
enum DS {
    enum Palette {
        static let label = Color(nsColor: .labelColor)
        static let secondary = Color(nsColor: .secondaryLabelColor)
        static let tertiary = Color(nsColor: .tertiaryLabelColor)
        static let separator = Color(nsColor: .separatorColor)
        static let fill = Color.primary.opacity(0.045)
        /// Readable quiet text (hints, counts, badges): ≥4.5:1 on the panel, unlike tertiary grey.
        static let meta = Color(nsColor: NSColor(name: "meta") { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.56) : NSColor(srgbRed: 0.43, green: 0.43, blue: 0.45, alpha: 1)
        })
        /// The accent: selection, active page and category, links. See `Accent`.
        static let tint = Color(nsColor: NSColor(name: "tint") { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? Accent.dark : Accent.light
        })
        static let pin = Color(nsColor: .systemOrange)
        static let critical = Color(nsColor: .systemRed)
    }

    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 20
    }

    enum Radius {
        static let thumb: CGFloat = 8, tile: CGFloat = 7, row: CGFloat = 10, card: CGFloat = 14, preview: CGFloat = 18, panel: CGFloat = 20
    }

    enum Size {
        /// The Mac emoji picker's own size (⌃⌘Space), measured on macOS 26.
        static let panel = CGSize(width: 346, height: 470)
        static let tile: CGFloat = 28
        /// Photos in the list: full row width, tall enough to see what's in them without hovering.
        static let photoHeight: CGFloat = 116
        static let previewMax = CGSize(width: 520, height: 400)
    }

    /// Regular and medium only; never bold.
    enum Text {
        static let title = Font.system(size: 15, weight: .medium)
        static let search = Font.system(size: 13)
        static let row = Font.system(size: 12.5)
        static let name = Font.system(size: 12.5, weight: .medium)
        static let meta = Font.system(size: 11)
        static let chip = Font.system(size: 11, weight: .medium)
        static let badge = Font.system(size: 10.5, weight: .medium, design: .rounded)
        static let overline = Font.system(size: 11, weight: .medium)
    }

    static func wash(_ scheme: ColorScheme) -> Color { Palette.tint.opacity(scheme == .dark ? 0.17 : 0.10) }
    static func washEdge(_ scheme: ColorScheme) -> Color { Palette.tint.opacity(scheme == .dark ? 0.40 : 0.30) }
}

/// Accent colour: a deeper shade on light glass so small text stays readable (≥4.5:1),
/// a brighter one on dark glass.
enum Accent {
    /// Apple blue (picked 2026-11-06, replacing pink).
    static var light = NSColor(srgbRed: 0.0, green: 0.392, blue: 0.824, alpha: 1)  // #0064D2
    static var dark = NSColor(srgbRed: 0.239, green: 0.608, blue: 1.0, alpha: 1)   // #3D9BFF

    #if DEBUG
    /// Design checks: GSCLIP_TINT="#RRGGBB,#RRGGBB" (light, dark) overrides the accent.
    static func applyOverride() {
        guard let v = ProcessInfo.processInfo.environment["GSCLIP_TINT"] else { return }
        let parts = v.split(separator: ",").map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "# ")) }
        func color(_ h: String) -> NSColor? {
            guard h.count == 6, let n = Int(h, radix: 16) else { return nil }
            return NSColor(srgbRed: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
        }
        if parts.count == 2, let l = color(parts[0]), let d = color(parts[1]) { light = l; dark = d }
    }
    #endif
}

enum Brand {
    static let blue = Color(red: 0.12, green: 0.42, blue: 1.0)      // #1F6BFF
    static let deep = Color(red: 0.04, green: 0.24, blue: 0.80)     // #0A3DCC
    static let sky = Color(red: 0.56, green: 0.80, blue: 1.0)       // #8FCCFF
    static let pink = Color(red: 1.0, green: 0.37, blue: 0.66)      // #FF5FA8, UI accent
    static let paperEdge = Color(red: 0.78, green: 0.84, blue: 0.95) // #C7D6F2
    static let name = "Gautham's Clipboard"
    static let maker = "GauthamWho"
    static let copyright = "© 2026 GauthamWho. All rights reserved."
}

/// Small uppercase section label.
struct Overline: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(DS.Text.overline).tracking(0.7).foregroundStyle(DS.Palette.meta)
    }
}

// MARK: - Brand mark

/// The G from G.ai Token Tray: a ring opened at the top right, a crossbar, a dot at the tip.
/// Drawn on a 24-point grid.
struct GLetterShape: Shape {
    var dot = true
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        let o = CGPoint(x: r.midX - 12 * s, y: r.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var g = Path()
        g.addArc(center: p(12, 12), radius: 7.2 * s, startAngle: .degrees(-45), endAngle: .degrees(0), clockwise: true)
        g.addLine(to: p(12.6, 12))
        var out = g.strokedPath(StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
        if dot { out = out.union(Path(ellipseIn: CGRect(x: o.x + 15.0 * s, y: o.y + 4.8 * s, width: 4.2 * s, height: 4.2 * s))) }
        return out
    }
}

/// The two-sheet copy shape: a plain white sheet behind, a blue sheet with the white G in front.
/// `plate` adds the macOS icon squircle (app icon); without it the sheets sit on glass (panel header).
struct ClipMark: View {
    var size: CGFloat = 22
    var plate = false

    var body: some View {
        Canvas { ctx, canvas in
            let u = canvas.width / 1024
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * u, y: y * u, width: w * u, height: h * u) }
            // Without the plate the sheets grow to fill the frame.
            let back = plate ? r(250, 215, 400, 500) : r(150, 70, 520, 650)
            let front = plate ? r(374, 309, 400, 500) : r(354, 304, 520, 650)
            let sheetR = (plate ? 64 : 92) * u

            if plate {
                let body = Path(roundedRect: r(100, 100, 824, 824), cornerRadius: 185 * u, style: .continuous)
                ctx.fill(body, with: .linearGradient(Gradient(colors: [.white, Color(red: 0.87, green: 0.91, blue: 1)]),
                                                     startPoint: .init(x: 100 * u, y: 100 * u), endPoint: .init(x: 924 * u, y: 924 * u)))
                ctx.stroke(body, with: .color(.black.opacity(0.06)), lineWidth: max(0.5, 2 * u))
            }

            var shadowed = ctx
            shadowed.addFilter(.shadow(color: Brand.deep.opacity(plate ? 0.22 : 0.18), radius: (plate ? 22 : 14) * u, x: 0, y: (plate ? 18 : 10) * u))
            let backPath = Path(roundedRect: back, cornerRadius: sheetR, style: .continuous)
            shadowed.fill(backPath, with: .color(.white))
            ctx.stroke(backPath, with: .color(Brand.paperEdge), lineWidth: max(0.75, 7 * u))

            let frontPath = Path(roundedRect: front, cornerRadius: sheetR, style: .continuous)
            shadowed.fill(frontPath, with: .linearGradient(Gradient(colors: [Brand.blue, Brand.deep]),
                                                           startPoint: front.origin, endPoint: CGPoint(x: front.maxX, y: front.maxY)))
            ctx.stroke(Path(roundedRect: front.insetBy(dx: 2 * u, dy: 2 * u), cornerRadius: sheetR - 2 * u, style: .continuous),
                       with: .color(.white.opacity(0.22)), lineWidth: max(0.5, 3 * u))

            let g = front.width * 0.9
            let gRect = CGRect(x: front.midX - g / 2, y: front.midY - g / 2, width: g, height: g)
            ctx.fill(GLetterShape(dot: false).path(in: gRect), with: .color(.white))
            let s = g / 24
            ctx.fill(Path(ellipseIn: CGRect(x: gRect.minX + 15.0 * s, y: gRect.minY + 4.8 * s, width: 4.2 * s, height: 4.2 * s)),
                     with: .color(Brand.sky))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Still images

