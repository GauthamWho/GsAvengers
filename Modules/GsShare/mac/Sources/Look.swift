// G's Avengers — the looks (themes). One struct drives every colour, material, radius and type choice.
import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, _ a: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: a)
    }
}

struct Look {
    let id: Int
    let name: String
    let blurb: String
    let dark: Bool
    let material: NSVisualEffectView.Material?   // real window glass (blurs what is behind the window)
    let bg: [Color]                               // gradient laid over the glass
    let aurora: [Color]                           // slow drifting light blobs (empty = none)
    let card: Color
    let cardStroke: Color
    let cardGlass: Bool                           // cards are frosted glass too
    let radius: CGFloat
    let text: Color
    let muted: Color
    let accent: Color
    let accent2: Color
    let ok: Color
    let titleDesign: Font.Design
    let titleWeight: Font.Weight
    let capsLabels: Bool
    let shadow: Color
    let glow: Double                              // 0…1 how much accent light leaks around active things
    let stage: Color

    var accentGradient: LinearGradient { LinearGradient(colors: [accent2, accent], startPoint: .topLeading, endPoint: .bottomTrailing) }
    func title(_ size: CGFloat) -> Font { .system(size: size, weight: titleWeight, design: titleDesign) }

    static let all: [Look] = [
        Look(id: 0, name: "Ink Glass", blurb: "Smoked glass over your desktop, vermilion light",
             dark: true, material: .hudWindow, bg: [Color(hex: 0x14151B, 0.70), Color(hex: 0x1A1B22, 0.82)],
             aurora: [Color(hex: 0xE4572E, 0.40), Color(hex: 0x6B3FA0, 0.28)],
             card: Color.white.opacity(0.055), cardStroke: Color.white.opacity(0.10), cardGlass: true, radius: 20,
             text: Color(hex: 0xFFFDF8), muted: Color(hex: 0xA6A3AC), accent: Color(hex: 0xE4572E), accent2: Color(hex: 0xF5885E),
             ok: Color(hex: 0x46D18A), titleDesign: .rounded, titleWeight: .bold, capsLabels: true,
             shadow: .black.opacity(0.45), glow: 0.8, stage: Color.black.opacity(0.22)),
        Look(id: 1, name: "Paper Editorial", blurb: "Warm paper, ink type, one vermilion mark — the EDZ house look",
             dark: false, material: nil, bg: [Color(hex: 0xFBF8F1), Color(hex: 0xF0E9DB)],
             aurora: [],
             card: Color(hex: 0xFFFDF8), cardStroke: Color(hex: 0x1A1B22, 0.10), cardGlass: false, radius: 16,
             text: Color(hex: 0x1A1B22), muted: Color(hex: 0x7B756A), accent: Color(hex: 0xD9481F), accent2: Color(hex: 0xEE6A3E),
             ok: Color(hex: 0x2F8F5B), titleDesign: .serif, titleWeight: .semibold, capsLabels: true,
             shadow: Color(hex: 0x5A3C1E, 0.14), glow: 0.15, stage: Color(hex: 0xEFE7D7)),
        Look(id: 2, name: "Midnight Aurora", blurb: "Deep night blue with northern-lights colour drifting behind glass",
             dark: true, material: .underWindowBackground, bg: [Color(hex: 0x060A1C, 0.82), Color(hex: 0x0C1330, 0.90)],
             aurora: [Color(hex: 0x3B5BFF, 0.50), Color(hex: 0x8A2BE2, 0.38), Color(hex: 0x00C2A8, 0.30)],
             card: Color.white.opacity(0.05), cardStroke: Color.white.opacity(0.11), cardGlass: true, radius: 22,
             text: Color(hex: 0xF3F5FF), muted: Color(hex: 0x9AA3C7), accent: Color(hex: 0x7B6CFF), accent2: Color(hex: 0x4FC3FF),
             ok: Color(hex: 0x3EE6B0), titleDesign: .default, titleWeight: .bold, capsLabels: true,
             shadow: .black.opacity(0.5), glow: 1.0, stage: Color.black.opacity(0.25)),
        Look(id: 3, name: "Graphite Pro", blurb: "Quiet pro-tool graphite, crisp hairlines, a single orange signal",
             dark: true, material: nil, bg: [Color(hex: 0x1D1D20), Color(hex: 0x161618)],
             aurora: [],
             card: Color(hex: 0x242427), cardStroke: Color.white.opacity(0.07), cardGlass: false, radius: 12,
             text: Color(hex: 0xF2F2F4), muted: Color(hex: 0x8E8E93), accent: Color(hex: 0xFF6B35), accent2: Color(hex: 0xFF6B35),
             ok: Color(hex: 0x32D74B), titleDesign: .default, titleWeight: .semibold, capsLabels: false,
             shadow: .black.opacity(0.35), glow: 0.0, stage: Color(hex: 0x1A1A1C)),
        Look(id: 4, name: "Frost", blurb: "Bright frosted glass, peach and sky light, soft shadows",
             dark: false, material: .popover, bg: [Color.white.opacity(0.45), Color(hex: 0xEEF2F8, 0.55)],
             aurora: [Color(hex: 0xFFC4AE, 0.55), Color(hex: 0xBFD3FF, 0.55)],
             card: Color.white.opacity(0.55), cardStroke: Color.white.opacity(0.85), cardGlass: true, radius: 22,
             text: Color(hex: 0x10131F), muted: Color(hex: 0x666B7C), accent: Color(hex: 0xE4572E), accent2: Color(hex: 0xFF9466),
             ok: Color(hex: 0x1FA463), titleDesign: .rounded, titleWeight: .bold, capsLabels: true,
             shadow: Color(hex: 0x3A4A7A, 0.16), glow: 0.35, stage: Color.white.opacity(0.35)),
        Look(id: 5, name: "Ember", blurb: "Near-black with warm ember light — bold, glowing, alive",
             dark: true, material: nil, bg: [Color(hex: 0x0C0806), Color(hex: 0x170D09)],
             aurora: [Color(hex: 0xFF5A1F, 0.42), Color(hex: 0xFFB347, 0.22)],
             card: Color.white.opacity(0.04), cardStroke: Color(hex: 0xFF8A5C, 0.20), cardGlass: false, radius: 18,
             text: Color(hex: 0xFFF6EE), muted: Color(hex: 0xB09A8C), accent: Color(hex: 0xFF5A1F), accent2: Color(hex: 0xFFB347),
             ok: Color(hex: 0x7BE495), titleDesign: .rounded, titleWeight: .heavy, capsLabels: true,
             shadow: .black.opacity(0.5), glow: 1.0, stage: Color.black.opacity(0.35)),
        Look(id: 6, name: "Noir & Champagne", blurb: "Black lacquer and champagne gold, thin elegant type",
             dark: true, material: nil, bg: [Color(hex: 0x060606), Color(hex: 0x0F0E0B)],
             aurora: [Color(hex: 0xD8BF8A, 0.10)],
             card: Color.white.opacity(0.028), cardStroke: Color(hex: 0xD8BF8A, 0.22), cardGlass: false, radius: 14,
             text: Color(hex: 0xF6F0E4), muted: Color(hex: 0x9E9584), accent: Color(hex: 0xC9A96A), accent2: Color(hex: 0xEBD7A6),
             ok: Color(hex: 0xBFD8A0), titleDesign: .serif, titleWeight: .regular, capsLabels: true,
             shadow: .black.opacity(0.6), glow: 0.35, stage: Color.black.opacity(0.4)),
        Look(id: 7, name: "Studio Daylight", blurb: "Clean daylight white, big soft shadows, calm and exact",
             dark: false, material: nil, bg: [Color(hex: 0xF6F6F8), Color(hex: 0xEDEDF1)],
             aurora: [],
             card: Color.white, cardStroke: Color.black.opacity(0.05), cardGlass: false, radius: 20,
             text: Color(hex: 0x1D1D1F), muted: Color(hex: 0x86868B), accent: Color(hex: 0xE4572E), accent2: Color(hex: 0xF27A4E),
             ok: Color(hex: 0x28A745), titleDesign: .default, titleWeight: .bold, capsLabels: false,
             shadow: .black.opacity(0.08), glow: 0.1, stage: Color(hex: 0xF3F3F6)),
    ]
}

private struct LookKey: EnvironmentKey { static let defaultValue = Look.all[0] }
extension EnvironmentValues { var look: Look { get { self[LookKey.self] } set { self[LookKey.self] = newValue } } }

/// Real window glass: blurs whatever is behind the window.
struct GlassView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = blending; v.state = .active; return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material; v.blendingMode = blending }
}

/// Slow drifting soft light, behind everything.
struct AuroraView: View {
    let colors: [Color]
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { t in
            let s = t.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                ZStack {
                    ForEach(Array(colors.enumerated()), id: \.offset) { i, c in
                        let p = Double(i) * 2.1
                        Circle().fill(c)
                            .frame(width: g.size.width * 0.9, height: g.size.width * 0.9)
                            .position(x: g.size.width * (0.5 + 0.38 * sin(s * 0.11 + p)),
                                      y: g.size.height * (0.28 + 0.30 * cos(s * 0.08 + p * 1.3)))
                            .blur(radius: 90)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
