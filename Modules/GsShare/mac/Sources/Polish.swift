// G's Avengers — premium controls: glass toggle, glass slider, key menu, entrances, flip-in digits.
import SwiftUI

/// Springy glass switch; the label sits left, the switch right.
struct GlassToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View { GlassToggleBody(configuration: configuration) }
}

struct GlassToggleBody: View {
    @Environment(\.look) var L
    let configuration: ToggleStyleConfiguration
    @State private var hover = false
    @State private var pressing = false
    var body: some View {
        let on = configuration.isOn
        HStack(spacing: 12) {
            configuration.label.foregroundColor(L.text)
            Spacer(minLength: 8)
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(L.text.opacity(L.dark ? 0.14 : 0.10))
                Capsule().fill(L.accentGradient).opacity(on ? 1 : 0)
                Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)).opacity(on ? 1 : 0.4)
                Capsule().strokeBorder(Color.white.opacity(L.dark ? 0.12 : 0.7), lineWidth: 0.8)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(hex: 0xF3F4F8)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1.5)
                    .frame(width: pressing ? 26 : 22, height: 22)
                    .padding(2)
            }
            .frame(width: 46, height: 26)
            .shadow(color: L.accent.opacity(on ? 0.35 * max(L.glow, 0.5) : 0), radius: hover ? 9 : 6, y: 2)
            .scaleEffect(hover ? 1.04 : 1)
            .onHover { hover = $0 }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressing { withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { pressing = true } } }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { pressing = false; configuration.isOn.toggle() }
                })
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.34, dampingFraction: 0.62), value: on)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
    }
}

/// Glass slider: gradient fill, knob that swells while you drag it.
struct GlassSlider: View {
    @Environment(\.look) var L
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var dragging = false
    @State private var hover = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, knob: CGFloat = 20
            let t = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let x = t * (w - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(L.text.opacity(L.dark ? 0.12 : 0.09)).frame(height: 6)
                Capsule().fill(L.accentGradient).frame(width: x + knob / 2, height: 6)
                    .shadow(color: L.accent.opacity(0.4 * max(L.glow, 0.5)), radius: 4)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(hex: 0xF1F2F6)], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.2), radius: dragging ? 6 : 3, y: dragging ? 3 : 1.5)
                    .frame(width: knob, height: knob)
                    .scaleEffect(dragging ? 1.22 : (hover ? 1.08 : 1))
                    .offset(x: x)
            }
            .frame(height: g.size.height)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !dragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { dragging = true } }
                    let nt = min(max((v.location.x - knob / 2) / (w - knob), 0), 1)
                    value = range.lowerBound + Double(nt) * (range.upperBound - range.lowerBound)
                }
                .onEnded { _ in withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { dragging = false } })
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
        }
        .frame(height: 26)
    }
}

/// Glass capsule menu for picking a key.
struct KeyMenu: View {
    @Environment(\.look) var L
    let options: [(String, UInt16)]
    @Binding var selection: UInt16
    @State private var hover = false
    var body: some View {
        let name = options.first { $0.1 == selection }?.0 ?? "—"
        Menu {
            ForEach(options, id: \.1) { o in Button(o.0) { selection = o.1 } }
        } label: {
            Text(name)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .tint(L.text)
        .fixedSize()
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(L.text)
        .padding(.leading, 12).padding(.trailing, 22).padding(.vertical, 5)
        .frame(minWidth: 74)
        .background(Capsule().fill(L.text.opacity(hover ? 0.11 : 0.07)))
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold)).foregroundColor(L.muted).padding(.trailing, 8).allowsHitTesting(false)
        }
        .scaleEffect(hover ? 1.04 : 1)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
    }
}

/// Sections float up into place one after another when the window opens.
struct Entrance: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .scaleEffect(shown ? 1 : 0.98, anchor: .top)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.05 + Double(index) * 0.07)) { shown = true }
            }
    }
}
extension View { func entrance(_ i: Int) -> some View { modifier(Entrance(index: i)) } }

/// One pairing digit: flips in, staggered.
struct PairDigit: View {
    @Environment(\.look) var L
    let ch: Character
    let index: Int
    @State private var shown = false
    var body: some View {
        Text(String(ch))
            .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().foregroundColor(L.text)
            .frame(width: 46, height: 58)
            .background(CardSurface(radius: 13))
            .rotation3DEffect(.degrees(shown ? 0 : -90), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.15 + Double(index) * 0.06)) { shown = true } }
    }
}

/// A ring that expands once when the link comes up.
struct ConnectRipple: View {
    let color: Color
    let trigger: Bool
    @State private var go = true   // resting = invisible
    var body: some View {
        Capsule().strokeBorder(color.opacity(0.7), lineWidth: 1.5).blur(radius: 1.2)
            .scaleEffect(go ? 1.6 : 1).opacity(go ? 0 : 0.8)
            .allowsHitTesting(false)
            .opacity(trigger ? 1 : 0)
            .onChange(of: trigger) { t in
                guard t else { return }
                go = false
                DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.9)) { go = true } }
            }
    }
}
