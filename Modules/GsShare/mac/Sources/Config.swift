// G's Avengers — saved settings (~/Library/Application Support/GsAvengers/config.json)
import Foundation

/// Sides: where something is. 0 left, 1 right, 2 top, 3 bottom.
enum Side: Int, Codable, CaseIterable {
    case left = 0, right = 1, top = 2, bottom = 3
    var opposite: Side { switch self { case .left: return .right; case .right: return .left; case .top: return .bottom; case .bottom: return .top } }
    var label: String { ["left", "right", "top", "bottom"][rawValue] }
}

/// A key-combo swap applied while the cursor is on this Mac.
/// fromMods use the Windows names (ctrl, shift, alt, win); fromKey is a Windows virtual-key code.
/// toMods use Mac names (control, option, shift, command, fn); toKey is a Mac key code.
struct Remap: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var fromMods: [String]
    var fromKey: UInt16
    var toMods: [String]
    var toKey: UInt16
}

struct Config: Codable {
    var deviceId: String = UUID().uuidString.lowercased()
    var pairings: [String: String] = [:]      // peer id -> base64 pair key
    var peerNames: [String: String] = [:]
    var peerSide: [String: Side] = [:]         // where the peer sits relative to this Mac
    var keyRules: [String: Bool] = [:]         // Windows-habit switches the owner changed (KeyRules.toggles ids); unset = default
    var remaps: [Remap] = []                   // the owner's own extra key swaps (checked before the built-in table)
    var shareClipboard = true
    var mouseSpeed = 1.0
    var scrollSpeed = 1.0
    var reverseScroll = false
    var look = 4                               // Frost (picked 2026-11-06)

    init() {}
    // Tolerant decoding: settings added in later versions fall back to their defaults.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let z = Config()
        deviceId = (try? c.decode(String.self, forKey: .deviceId)) ?? z.deviceId
        pairings = (try? c.decode([String: String].self, forKey: .pairings)) ?? [:]
        peerNames = (try? c.decode([String: String].self, forKey: .peerNames)) ?? [:]
        peerSide = (try? c.decode([String: Side].self, forKey: .peerSide)) ?? [:]
        keyRules = (try? c.decode([String: Bool].self, forKey: .keyRules)) ?? z.keyRules
        remaps = (try? c.decode([Remap].self, forKey: .remaps)) ?? z.remaps
        // v1 shipped Ctrl+Space -> fn Space as a custom swap; it is now the built-in "ctrl.space" switch
        remaps.removeAll { $0.fromMods == ["ctrl"] && $0.fromKey == 0x20 && $0.toMods == ["fn"] && $0.toKey == 0x31 }
        shareClipboard = (try? c.decode(Bool.self, forKey: .shareClipboard)) ?? z.shareClipboard
        mouseSpeed = (try? c.decode(Double.self, forKey: .mouseSpeed)) ?? z.mouseSpeed
        scrollSpeed = (try? c.decode(Double.self, forKey: .scrollSpeed)) ?? z.scrollSpeed
        reverseScroll = (try? c.decode(Bool.self, forKey: .reverseScroll)) ?? z.reverseScroll
        look = (try? c.decode(Int.self, forKey: .look)) ?? z.look
    }

    static var dir: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GsAvengers")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static var file: URL { dir.appendingPathComponent("config.json") }

    static func load() -> Config {
        if let d = try? Data(contentsOf: file), let c = try? JSONDecoder().decode(Config.self, from: d) { return c }
        let c = Config(); c.save(); return c
    }
    func save() {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? e.encode(self) { try? d.write(to: Config.file, options: .atomic) }
    }
}
