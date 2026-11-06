// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

/// The one wire format between G’s Avengers and its two embedded helpers
/// (clipboard, Windows sharing). This single file is compiled into all three
/// apps (the helpers link to it), so the sender and the reader can never
/// disagree about a field. Commands go out as distributed notifications;
/// each helper answers every command, and every change of its own, with a
/// full state post, so the main window always shows the helper's real state.
enum HelperWire {
    static let clipboardCommand = Notification.Name("com.gauthamwho.gsavengers.clipboard.command")
    static let clipboardState = Notification.Name("com.gauthamwho.gsavengers.clipboard.state")
    static let shareCommand = Notification.Name("com.gauthamwho.gsavengers.share.command")
    static let shareState = Notification.Name("com.gauthamwho.gsavengers.share.state")

    /// One Windows-habit key switch, as the sharing helper defines it.
    struct ShareRule: Codable, Equatable, Identifiable {
        var id: String
        var group: String
        var windows: String
        var mac: String
        var on: Bool
    }

    /// Everything the sharing helper knows that the window shows or changes.
    struct ShareState: Codable, Equatable {
        var connected = false
        var paused = false
        var active = false              // the Windows pointer is on this Mac right now
        var trusted = false             // Accessibility allowed for the helper
        var peer = ""
        var peerId = ""
        var lastSeen = ""               // a laptop seen on the network but not connected
        var paired = false              // at least one Windows laptop paired before
        var pairCode: String?           // shown while a new pairing waits for "Pair"
        var pairConfirmed = false       // Pair pressed here, waiting for Windows
        var side = 1                    // where Windows sits: 0 left, 1 right, 2 top, 3 bottom
        var shareClipboard = true
        var mouseSpeed = 1.0
        var scrollSpeed = 1.0
        var reverseScroll = false
        var rules: [ShareRule] = []
    }

    /// The clipboard helper's own settings.
    struct ClipboardState: Codable, Equatable {
        var pasteAfterPick = true
        var smartCleanup = true
        var maxItems = 0                // 0 = no limit
        var shortcut = "fn V"
        var emojiShortcut = "fn E"
    }

    enum ShareCommand: Equatable {
        case show, state, pause, resume, confirmPair
        case rule(String, Bool)
        case side(Int)
        case mouseSpeed(Double)
        case scrollSpeed(Double)
        case reverseScroll(Bool)
        case shareClipboard(Bool)
    }

    enum ClipboardCommand: Equatable {
        case show, emoji, settings, about, state
        case pasteAfterPick(Bool)
        case smartCleanup(Bool)
        case maxItems(Int)
    }

    // MARK: - Encoding

    static func userInfo<T: Encodable>(state: T) -> [String: String] {
        guard let data = try? JSONEncoder().encode(state) else { return [:] }
        return ["json": String(decoding: data, as: UTF8.self)]
    }

    static func state<T: Decodable>(_ type: T.Type, from info: [AnyHashable: Any]?) -> T? {
        guard let json = info?["json"] as? String else { return nil }
        return try? JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private static func flag(_ on: Bool) -> String { on ? "1" : "0" }

    static func userInfo(_ command: ShareCommand) -> [String: String] {
        switch command {
        case .show: return ["cmd": "show"]
        case .state: return ["cmd": "state"]
        case .pause: return ["cmd": "pause"]
        case .resume: return ["cmd": "resume"]
        case .confirmPair: return ["cmd": "pair"]
        case .rule(let id, let on): return ["cmd": "rule", "id": id, "value": flag(on)]
        case .side(let side): return ["cmd": "side", "value": String(side)]
        case .mouseSpeed(let speed): return ["cmd": "mouseSpeed", "value": String(speed)]
        case .scrollSpeed(let speed): return ["cmd": "scrollSpeed", "value": String(speed)]
        case .reverseScroll(let on): return ["cmd": "reverseScroll", "value": flag(on)]
        case .shareClipboard(let on): return ["cmd": "shareClipboard", "value": flag(on)]
        }
    }

    static func shareCommand(from info: [AnyHashable: Any]?) -> ShareCommand? {
        guard let cmd = info?["cmd"] as? String else { return nil }
        let value = info?["value"] as? String
        let on = value == "1"
        switch cmd {
        case "show": return .show
        case "state": return .state
        case "pause": return .pause
        case "resume": return .resume
        case "pair": return .confirmPair
        case "rule":
            guard let id = info?["id"] as? String, !id.isEmpty, value != nil else { return nil }
            return .rule(id, on)
        case "side":
            guard let side = value.flatMap(Int.init), (0...3).contains(side) else { return nil }
            return .side(side)
        case "mouseSpeed":
            guard let speed = value.flatMap(Double.init), speed.isFinite else { return nil }
            return .mouseSpeed(min(max(speed, 0.4), 2.5))
        case "scrollSpeed":
            guard let speed = value.flatMap(Double.init), speed.isFinite else { return nil }
            return .scrollSpeed(min(max(speed, 0.2), 3))
        case "reverseScroll": return value == nil ? nil : .reverseScroll(on)
        case "shareClipboard": return value == nil ? nil : .shareClipboard(on)
        default: return nil
        }
    }

    static func userInfo(_ command: ClipboardCommand) -> [String: String] {
        switch command {
        case .show: return ["cmd": "show"]
        case .emoji: return ["cmd": "emoji"]
        case .settings: return ["cmd": "settings"]
        case .about: return ["cmd": "about"]
        case .state: return ["cmd": "state"]
        case .pasteAfterPick(let on): return ["cmd": "pasteAfterPick", "value": flag(on)]
        case .smartCleanup(let on): return ["cmd": "smartCleanup", "value": flag(on)]
        case .maxItems(let count): return ["cmd": "maxItems", "value": String(count)]
        }
    }

    static func clipboardCommand(from info: [AnyHashable: Any]?) -> ClipboardCommand? {
        guard let cmd = info?["cmd"] as? String else { return nil }
        let value = info?["value"] as? String
        switch cmd {
        case "show": return .show
        case "emoji": return .emoji
        case "settings": return .settings
        case "about": return .about
        case "state": return .state
        case "pasteAfterPick": return value == nil ? nil : .pasteAfterPick(value == "1")
        case "smartCleanup": return value == nil ? nil : .smartCleanup(value == "1")
        case "maxItems":
            guard let count = value.flatMap(Int.init), count >= 0 else { return nil }
            return .maxItems(count)
        default: return nil
        }
    }
}
