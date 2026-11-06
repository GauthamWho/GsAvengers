// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)
//
// Draws the "GsA" monogram (SF Pro Display Semibold, tight tracking) as
// outlines and writes every brand master from it:
//   Resources/Brand/logo.png                    black mark on clear (menu-bar template + BrandMark source)
//   Resources/Brand/AppIcon-Default.png         finished macOS icon, graphite squircle + white mark
//   Resources/Brand/AppIcon.icon/Assets/gsa-mark.svg   white outlines for Icon Composer
//   docs/gsmac/logo/gsa-*.svg / gsa-appicon-1024.png
// Run: swift Tools/MakeBrandLogo.swift   (then ./build.sh rebuilds icons and Assets.car)

import AppKit
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
func out(_ path: String) -> URL { root.appendingPathComponent(path) }

// MARK: - Monogram outlines

/// "GsA" as one path in font units (y up), origin at the baseline.
func monogramPath() -> CGPath {
    let size: CGFloat = 1000
    let font = NSFont.systemFont(ofSize: size, weight: .semibold) // SF Pro Display at this size
    let text = NSAttributedString(string: "GsA", attributes: [.font: font, .kern: -0.045 * size])
    let line = CTLineCreateWithAttributedString(text)
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let runFont = attrs[kCTFontAttributeName] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for i in 0..<count {
            guard let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
            path.addPath(g, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
        }
    }
    return path
}

let mark = monogramPath()
let markBox = mark.boundingBoxOfPath

/// The mark scaled to `width` and centered on `center` (y-up coordinates).
func placedMark(width: CGFloat, center: CGPoint) -> CGPath {
    let s = width / markBox.width
    var t = CGAffineTransform(translationX: center.x - markBox.midX * s, y: center.y - markBox.midY * s)
    t = t.scaledBy(x: s, y: s)
    return mark.copy(using: &t)!
}

// MARK: - Raster helpers

func png(_ px: Int, _ draw: (CGContext) -> Void) -> Data {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// macOS icon body: 824 pt rounded square on the 1024 grid, Apple's 185 pt corner radius.
func squircle(_ r: CGRect) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: 185, cornerHeight: 185, transform: nil)
}

let markWidthInBody: CGFloat = 0.64 // share of the icon body the monogram spans

func appIcon(_ ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(body)
    // soft drop shadow, like the system's own icons
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(0x000000, 0.32))
    ctx.addPath(shape); ctx.setFillColor(rgb(0x111214)); ctx.fillPath()
    ctx.restoreGState()
    // graphite gradient, lighter at the top
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [rgb(0x34353B), rgb(0x1A1B1F), rgb(0x0B0B0D)] as CFArray,
                          locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
    // hairline top highlight
    ctx.addPath(shape); ctx.setStrokeColor(rgb(0xFFFFFF, 0.10)); ctx.setLineWidth(3); ctx.strokePath()
    // the monogram, with a whisper of depth
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: rgb(0x000000, 0.45))
    ctx.addPath(placedMark(width: body.width * markWidthInBody, center: CGPoint(x: 512, y: 512)))
    ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
}

// MARK: - SVG

func svgPathData(_ path: CGPath, flipHeight h: CGFloat) -> String {
    var d = ""
    func f(_ p: CGPoint) -> String { String(format: "%.2f %.2f", p.x, h - p.y) }
    path.applyWithBlock { e in
        let pts = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint: d += "M\(f(pts[0]))"
        case .addLineToPoint: d += "L\(f(pts[0]))"
        case .addQuadCurveToPoint: d += "Q\(f(pts[0])) \(f(pts[1]))"
        case .addCurveToPoint: d += "C\(f(pts[0])) \(f(pts[1])) \(f(pts[2]))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

func svg(fill: String, markWidth: CGFloat, background: String? = nil) -> String {
    let d = svgPathData(placedMark(width: markWidth, center: CGPoint(x: 512, y: 512)), flipHeight: 1024)
    let bg = background.map { "<rect width=\"1024\" height=\"1024\" rx=\"230\" fill=\"\($0)\"/>" } ?? ""
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\">\(bg)<path d=\"\(d)\" fill=\"\(fill)\"/></svg>\n"
}

// MARK: - Write

let iconPNG = png(1024, appIcon)
try iconPNG.write(to: out("Resources/Brand/AppIcon-Default.png"))
try png(1024) { ctx in
    ctx.addPath(placedMark(width: 900, center: CGPoint(x: 512, y: 512)))
    ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
}.write(to: out("Resources/Brand/logo.png"))

// Icon Composer canvas is the icon body itself, so the mark spans the same share of it.
try svg(fill: "#FFFFFF", markWidth: 1024 * markWidthInBody)
    .write(to: out("Resources/Brand/AppIcon.icon/Assets/gsa-mark.svg"), atomically: true, encoding: .utf8)

let docs = "docs/gsmac/logo/"
try iconPNG.write(to: out(docs + "gsa-appicon-1024.png"))
try svg(fill: "#FFFFFF", markWidth: 1024 * markWidthInBody, background: "#16171A")
    .write(to: out(docs + "gsa-appicon.svg"), atomically: true, encoding: .utf8)
try svg(fill: "#FFFFFF", markWidth: 900).write(to: out(docs + "gsa-mark.svg"), atomically: true, encoding: .utf8)
try svg(fill: "#000000", markWidth: 900).write(to: out(docs + "gsa-glyph.svg"), atomically: true, encoding: .utf8)
print("GsA brand masters written")
