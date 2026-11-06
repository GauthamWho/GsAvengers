// Gautham's Clipboard by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var state: PanelState
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateChecker
    @ObservedObject private var hotKey = HotKeyManager.shared
    @FocusState private var searchFocused: Bool
    @Namespace private var selection

    var body: some View { panelBody }

    /// Laid out like the Mac emoji picker (⌃⌘Space): search on top, the page in the middle,
    /// a bar along the bottom. Clipboard and Emoji are two pages of the same frame (fn V / fn E or the switch flips).
    private var panelBody: some View {
        let items = state.visible
        return VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 21).padding(.top, 21).padding(.bottom, 8)
            if state.showPermissionCard {
                PermissionCard(state: state).padding(.horizontal, 13).padding(.bottom, 6).transition(.rise)
            }
            Group {
                if !state.isOpen { Color.clear }
                else if state.filter == .emoji { EmojiGrid(state: state) } else { list(items) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 13)
            bottomBar
        }
        .frame(width: DS.Size.panel.width, height: DS.Size.panel.height)
        .animation(Motion.arrive, value: state.showPermissionCard)
        .onReceive(NotificationCenter.default.publisher(for: .gsClipboardDidShow)) { _ in
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: state.search) { _, _ in state.selectedID = state.visible.first?.id; state.emojiIndex = 0 }
        .onChange(of: state.filter) { _, _ in state.selectedID = state.visible.first?.id; searchFocused = true }
        .coordinateSpace(name: "panel")
        .onPreferenceChange(RowFrameKey.self) { frames in
            MainActor.assumeIsolated { state.rowFrames = frames }
        }
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundStyle(DS.Palette.meta)
            TextField(state.filter == .emoji ? "Search emoji" : "Search clipboard", text: $state.search)
                .textFieldStyle(.plain)
                .font(DS.Text.search)
                .focused($searchFocused)
            if !state.search.isEmpty {
                Button { state.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(DS.Palette.meta)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(DS.Palette.fill.opacity(1.4), in: Capsule())
    }

    // MARK: Clipboard page

    /// Pinned first, then Today / Yesterday / Earlier, like the picker's sections. Flat while searching.
    private func sections(_ items: [ClipItem]) -> [(title: String, rows: [(Int, ClipItem)])] {
        let indexed = Array(items.enumerated())
        guard state.search.isEmpty else { return [("", indexed)] }
        let cal = Calendar.current
        func title(_ item: ClipItem) -> String {
            if item.pinned { return "Pinned" }
            if cal.isDateInToday(item.createdAt) { return "Today" }
            if cal.isDateInYesterday(item.createdAt) { return "Yesterday" }
            return "Earlier"
        }
        var out: [(title: String, rows: [(Int, ClipItem)])] = []
        for pair in indexed {
            let t = title(pair.element)
            if out.last?.title == t { out[out.count - 1].rows.append(pair) } else { out.append((t, [pair])) }
        }
        return out
    }

    @ViewBuilder
    private func list(_ items: [ClipItem]) -> some View {
        if items.isEmpty {
            EmptyState(hasHistory: !model.store.items.isEmpty, query: state.search)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(sections(items), id: \.title) { section in
                            if !section.title.isEmpty {
                                Overline(section.title).padding(.leading, 10).padding(.top, 8).padding(.bottom, 3)
                            }
                            ForEach(section.rows, id: \.1.id) { i, item in
                                ClipRow(item: item, index: i, state: state, selected: state.selectedID == item.id,
                                        blobsDir: model.store.blobsDir, ns: selection)
                                    .id(item.id)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.never)
                .onChange(of: state.keyboardMove) { _, _ in
                    if let id = state.selectedID { withAnimation(Motion.quick) { proxy.scrollTo(id, anchor: nil) } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .gsClipboardDidShow)) { _ in
                    if let first = items.first { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            PageSwitch(state: state, ns: selection)
            if state.filter == .emoji {
                EmojiCategoryBar(state: state)
            } else {
                Text("\(Paster.willPaste ? "↩ Paste" : "↩ Copy") · \(hotKey.emojiDisplay) Emoji")
                    .font(DS.Text.meta).foregroundStyle(DS.Palette.meta).lineLimit(1)
                Spacer(minLength: 0)
                if let version = updates.available?.version {
                    Button { updates.installAvailable() } label: { Text("Update \(version)").font(DS.Text.chip) }
                        .buttonStyle(.plain).foregroundStyle(DS.Palette.tint)
                }
                Menu {
                    Button("Settings…") { state.onClose(); state.onOpenSettings() }
                    Button("Clear history (keeps pins)") { model.store.clearAll() }
                    Divider()
                    Button("Quit \(Brand.name)") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape").font(.system(size: 11.5, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(DS.Palette.secondary)
            }
        }
        .padding(.leading, 12).padding(.trailing, 14)
        .frame(height: 46)
    }
}

/// "Clipboard | Emoji" switch at the bottom left (fn V / fn E or Tab do the same).
struct PageSwitch: View {
    @ObservedObject var state: PanelState
    let ns: Namespace.ID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelState.Filter.allCases) { f in
                let on = state.filter == f
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { state.filter = f }
                    state.emojiIndex = 0
                } label: {
                    Text(f.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(on ? DS.Palette.label : DS.Palette.secondary)
                        .padding(.horizontal, 9).frame(height: 22)
                        .background {
                            if on {
                                Capsule().fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                                    .matchedGeometryEffect(id: "page", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DS.Palette.fill.opacity(1.4), in: Capsule())
    }
}

// MARK: - Row

struct RowFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    @ObservedObject var state: PanelState
    let selected: Bool
    let blobsDir: URL
    let ns: Namespace.ID
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if item.kind == .image { photoRow } else { standardRow }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, item.kind == .image ? 6 : 7)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                    .fill(DS.wash(scheme))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                        .strokeBorder(DS.washEdge(scheme), lineWidth: 0.5))
                    .matchedGeometryEffect(id: "selection", in: ns)
            } else if hovering {
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous).fill(DS.Palette.fill)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous))
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selected)
        .onHover { h in
            hovering = h
            if h { state.hover(item.id) }
        }
        .onTapGesture { state.onPick(item, true) }
        .background(GeometryReader { g in
            Color.clear.preference(key: RowFrameKey.self, value: [item.id: g.frame(in: .named("panel"))])
        })
        .contextMenu {
            Button("Paste") { state.onPick(item, true) }
            Button("Copy only") { state.onPick(item, false) }
            Button(item.pinned ? "Unpin" : "Pin") { state.model.store.togglePin(item) }
            Divider()
            Button("Delete", role: .destructive) { state.delete(item) }
        }
        .help(item.kind == .text ? String((item.text ?? "").prefix(600)) : "")
    }

    /// A photo shows big, across the whole row, so you can see what's in it without hovering.
    private var photoRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            photo
            HStack(spacing: 4) {
                if item.pinned { Image(systemName: "pin.fill").font(.system(size: 8.5)).foregroundStyle(DS.Palette.pin) }
                Text([title, dims, meta].compactMap { $0 }.joined(separator: " · ")).lineLimit(1)
                Spacer(minLength: 4)
                trailing
            }
            .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
        }
    }

    @ViewBuilder
    private var photo: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.row - 2, style: .continuous)
        if let name = item.blobName,
           let img = ThumbnailCache.shared.image(for: blobsDir.appendingPathComponent(name), maxPixel: 600) {
            Color.clear
                .frame(maxWidth: .infinity).frame(height: DS.Size.photoHeight)
                .overlay(Image(nsImage: img).resizable().aspectRatio(contentMode: .fill))
                .background(Color.white)
                .clipShape(shape)
                .overlay(shape.strokeBorder(DS.Palette.separator, lineWidth: 0.5))
        } else {
            shape.fill(DS.Palette.fill).frame(maxWidth: .infinity).frame(height: DS.Size.photoHeight)
                .overlay(Image(systemName: "photo").foregroundStyle(DS.Palette.meta))
        }
    }

    private var standardRow: some View {
        HStack(alignment: .center, spacing: 10) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(item.kind == .image ? DS.Text.name : DS.Text.row)
                    .foregroundStyle(DS.Palette.label)
                    .lineLimit(item.kind == .text ? 2 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let dims { Text(dims).font(DS.Text.meta).foregroundStyle(DS.Palette.secondary) }
                HStack(spacing: 4) {
                    if item.pinned { Image(systemName: "pin.fill").font(.system(size: 8.5)).foregroundStyle(DS.Palette.pin) }
                    Text(meta).lineLimit(1)
                }
                .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
            }
            trailing
        }
    }

    // MARK: Parts

    @ViewBuilder
    private var leading: some View {
        if item.kind == .file, let path = item.text?.split(separator: "\n").first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: String(path)))
                .resizable().frame(width: DS.Size.tile, height: DS.Size.tile)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Palette.secondary)
                .frame(width: DS.Size.tile, height: DS.Size.tile)
                .background(DS.Palette.fill, in: RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
        }
    }

    @ViewBuilder
    private var trailing: some View {
        ZStack(alignment: .trailing) {
            if hovering {
                HStack(spacing: 2) {
                    iconButton(item.pinned ? "pin.slash" : "pin", help: item.pinned ? "Unpin" : "Pin",
                               color: item.pinned ? DS.Palette.pin : DS.Palette.secondary) { state.model.store.togglePin(item) }
                    iconButton("trash", help: "Delete", color: DS.Palette.secondary) { state.delete(item) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if index < 9 {
                Text("⌘\(index + 1)").font(DS.Text.badge).foregroundStyle(selected ? DS.Palette.secondary : DS.Palette.meta)
                    .transition(.opacity)
            }
        }
        .frame(width: 46, alignment: .trailing)
        .animation(Motion.quick, value: hovering)
    }

    private func iconButton(_ symbol: String, help: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10.5, weight: .medium))
                .frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(PressSquish())
        .foregroundStyle(color)
        .help(help)
    }

    // MARK: Text

    private var isLink: Bool {
        guard item.kind == .text, let t = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !t.contains(" ") && (t.hasPrefix("http://") || t.hasPrefix("https://"))
    }

    private var symbol: String {
        switch item.kind {
        case .text: isLink ? "link" : "text.alignleft"
        case .image: "photo"
        case .file: "doc"
        }
    }

    private var title: String {
        switch item.kind {
        case .image: isScreenshot ? "Screenshot" : "Image"
        default: item.preview.isEmpty ? "(empty)" : item.preview
        }
    }

    private var isScreenshot: Bool {
        let s = item.sourceApp?.lowercased() ?? ""
        return s.contains("screenshot") || s.contains("screencapture")
    }

    private var dims: String? {
        guard item.kind == .image, let name = item.blobName,
              let s = ThumbnailCache.shared.pixelSize(for: blobsDir.appendingPathComponent(name)) else { return nil }
        return "\(Int(s.width)) × \(Int(s.height))"
    }

    private var meta: String {
        var parts: [String] = []
        if item.kind == .file, let t = item.text {
            let n = t.split(separator: "\n").count
            parts.append(n == 1 ? "1 file" : "\(n) files")
        }
        parts.append(Fmt.ago(item.createdAt))
        if let s = item.sourceApp { parts.append(s) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Small parts

struct PermissionCard: View {
    @ObservedObject var state: PanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "cursorarrow.click.2").font(.system(size: 11, weight: .medium)).foregroundStyle(DS.Palette.tint)
                Text("Paste right where you clicked").font(DS.Text.name)
            }
            Text("macOS needs your OK once: turn on \(Brand.name) in Privacy & Security › Accessibility. It lets \(HotKeyManager.shared.display) open the clipboard and paste where you clicked. Until then, picks are copied and you press ⌘V.")
                .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button("Open Settings") { Paster.openAccessibilitySettings(); state.onClose() }
                    .glassButton(prominent: true, tint: DS.Palette.tint)
                Button("Not now") {
                    UserDefaults.standard.set(true, forKey: "permissionCardDismissed")
                    state.showPermissionCard = false
                }
                .glassButton()
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [DS.Palette.tint.opacity(0.14), DS.Palette.tint.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).strokeBorder(DS.Palette.tint.opacity(0.30), lineWidth: 0.5))
        .pointerGlow(.white, radius: 160, strength: 0.35, corner: DS.Radius.card)
    }
}

struct EmptyState: View {
    let hasHistory: Bool
    let query: String

    var body: some View {
        VStack(spacing: DS.Space.s) {
            ClipMark(size: 52)
                .opacity(hasHistory ? 0.5 : 1)
                .tiltAndFling(8)
            Text(hasHistory ? (query.isEmpty ? "Nothing in this filter" : "No match for \"\(query)\"") : "Nothing here yet")
                .font(DS.Text.title).foregroundStyle(DS.Palette.label)
            if !hasHistory {
                Text("Copy text, links or screenshots.\nPress \(HotKeyManager.shared.display) to bring them back.")
                    .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary).multilineTextAlignment(.center)
            }
        }
    }
}

enum Fmt {
    static func ago(_ d: Date) -> String {
        let s = max(0, Date().timeIntervalSince(d))
        if s < 45 { return "now" }
        if s < 3600 { return "\(Int(s / 60 + 0.5))m" }
        if s < 86_400 { return "\(Int(s / 3600))h" }
        if s < 7 * 86_400 { return "\(Int(s / 86_400))d" }
        return d.formatted(.dateTime.day().month(.abbreviated))
    }

    static func agoLong(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return Date().timeIntervalSince(d) < 45 ? "just now" : f.localizedString(for: d, relativeTo: Date())
    }
}
