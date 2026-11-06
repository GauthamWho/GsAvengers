// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import SwiftUI

/// The window's pages: Home has every switch; the others are the few
/// features that need more than a switch.
enum AvengersPage: String, CaseIterable, Identifiable {
    case home, sharing, keyboard, clipboard, capture, keepAwake

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .sharing: return "pc"
        case .keyboard: return "keyboard"
        case .clipboard: return "doc.on.clipboard"
        case .capture: return "camera.viewfinder"
        case .keepAwake: return "moon.zzz"
        }
    }

    func title(_ text: AvengersStrings, home: HomeStrings, setup: GsMacSetupStrings) -> String {
        switch self {
        case .home: return text.home
        case .sharing: return text.sharing
        case .keyboard: return text.keyboard
        case .clipboard: return setup.clipboard
        case .capture: return text.capture
        case .keepAwake: return home.keepAwake
        }
    }
}

/// The one window the menu-bar icon opens.
final class AvengersWindowController: NSObject, NSWindowDelegate {
    static let shared = AvengersWindowController()
    static let contentSize = NSSize(width: 780, height: 600)

    /// Built on open and released on close, with its model and views, so a
    /// closed window costs no memory and observes nothing.
    private var window: NSWindow?
    private var router: AvengersRouter?

    func show(_ page: AvengersPage? = nil) {
        if window == nil {
            let router = AvengersRouter()
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.contentSize),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "G’s Avengers"
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
            window.contentView = NSHostingView(rootView: AvengersRootView(router: router, model: AvengersModel()))
            window.delegate = self
            window.center()
            self.window = window
            self.router = router
        }
        if let page { router?.page = page }
        if window?.isVisible != true { WindowActivationPolicy.retain() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        WindowActivationPolicy.release()
        // Let go of the views and the model on the next turn, after AppKit is done with the window.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.isVisible != true else { return }
            self.window?.contentView = nil
            self.window?.delegate = nil
            self.window = nil
            self.router = nil
            // Hand the freed pages back to the system now rather than later.
            malloc_zone_pressure_relief(nil, 0)
        }
    }
}

final class AvengersRouter: ObservableObject {
    @Published var page: AvengersPage = .home
}

struct AvengersRootView: View {
    @ObservedObject var router: AvengersRouter
    @ObservedObject var model: AvengersModel
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.frostSnapshot) private var snapshot

    private var text: AvengersStrings { FeatureStrings.avengers(l10n.language) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Frost.text.opacity(0.06)).frame(width: 1)
            if snapshot {
                // An offscreen render cannot draw a scroll view; the page is
                // drawn as the window first shows it, from the top.
                Color.clear
                    .overlay(alignment: .top) { page.fixedSize(horizontal: false, vertical: true) }
                    .clipped()
            } else {
                ScrollView(showsIndicators: false) { page }.id(router.page)
            }
        }
        .frame(width: AvengersWindowController.contentSize.width, height: AvengersWindowController.contentSize.height)
        .background(FrostBackdrop())
        .environment(\.colorScheme, .light)
        .tint(Frost.accent)
    }

    private var page: some View {
        AvengersPageView(page: router.page, router: router, model: model)
            .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            if snapshot {
                // The real traffic lights belong to the window, not the view.
                HStack(spacing: 8) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840], id: \.self) { Circle().fill(Color(frost: UInt32($0))).frame(width: 12, height: 12) }
                }
                .padding(.leading, 8).padding(.top, -24).frame(height: 0, alignment: .top)
            }
            HStack(spacing: 9) {
                FrostLogo(size: 30)
                Text(verbatim: "G’s Avengers").font(Frost.title(15)).foregroundColor(Frost.text).lineLimit(1)
            }
            .padding(.horizontal, 6).padding(.bottom, 16)
            ForEach(AvengersPage.allCases) { page in
                navRow(page)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 44).padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 214, alignment: .topLeading)
    }

    private func navRow(_ page: AvengersPage) -> some View {
        let selected = router.page == page
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { router.page = page }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: page.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? AnyShapeStyle(Frost.accentGradient) : AnyShapeStyle(Frost.muted))
                    .frame(width: 20)
                Text(page.title(text, home: FeatureStrings.home(l10n.language), setup: FeatureStrings.gsMacSetup(l10n.language)))
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(Frost.text).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.8 : 0))
                    .shadow(color: Frost.shadow.opacity(selected ? 0.6 : 0), radius: 4, y: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if VORSSAINT_DEVELOPMENT
/// `--avengers-snapshot <folder>`: draws the window offscreen, once per page
/// named in `--pages` (default home and sharing), into PNGs. Sharing shows a
/// sample laptop so the layout can be judged without one on the network.
enum AvengersSnapshot {
    static func runAndExit(folder: String, pages: [AvengersPage]) -> Never {
        _ = NSApplication.shared
        MainActor.assumeIsolated {
            for page in pages {
                let router = AvengersRouter()
                router.page = page
                let renderer = ImageRenderer(content: AvengersRootView(router: router, model: AvengersModel()).environment(\.frostSnapshot, true))
                renderer.scale = 2
                guard let image = renderer.cgImage else { continue }
                let rep = NSBitmapImageRep(cgImage: image)
                let url = URL(fileURLWithPath: folder).appendingPathComponent("\(page.rawValue).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
                print(url.path)
            }
        }
        exit(0)
    }
}
#endif
