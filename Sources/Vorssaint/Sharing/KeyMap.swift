// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)
// G's Avengers — Windows virtual-key codes -> Mac key codes
import Foundation

enum HostMod: String, CaseIterable { case ctrl, shift, alt, win }
enum MacMod: String, CaseIterable { case control, option, shift, command, fn }

enum KeyMap {
    // Mac key codes for modifiers
    static let kShift: UInt16 = 0x38, kRShift: UInt16 = 0x3C, kControl: UInt16 = 0x3B, kRControl: UInt16 = 0x3E
    static let kOption: UInt16 = 0x3A, kROption: UInt16 = 0x3D, kCommand: UInt16 = 0x37, kRCommand: UInt16 = 0x36
    static let kFn: UInt16 = 0x3F, kCaps: UInt16 = 0x39

    /// Normalise a Windows VK + extended flag to a specific left/right VK where it matters.
    static func normalize(vk: UInt16, extended: Bool) -> UInt16 {
        switch vk {
        case 0x10: return 0xA0           // SHIFT -> LSHIFT (right shift arrives as 0xA1 from LL hooks)
        case 0x11: return extended ? 0xA3 : 0xA2
        case 0x12: return extended ? 0xA5 : 0xA4
        case 0x0D: return extended ? 0x10D : 0x0D // numpad Enter gets a private code
        default: return vk
        }
    }

    /// Which host modifier a (normalised) VK is, if any.
    static func hostMod(_ vk: UInt16) -> HostMod? {
        switch vk {
        case 0xA2, 0xA3: return .ctrl
        case 0xA0, 0xA1: return .shift
        case 0xA4, 0xA5: return .alt
        case 0x5B, 0x5C: return .win
        default: return nil
        }
    }

    static func macModKey(_ m: MacMod) -> UInt16 {
        switch m { case .control: return kControl; case .option: return kOption; case .shift: return kShift; case .command: return kCommand; case .fn: return kFn }
    }

    static let table: [UInt16: UInt16] = {
        var t: [UInt16: UInt16] = [:]
        let letters: [UInt16] = [0x00, 0x0B, 0x08, 0x02, 0x0E, 0x03, 0x05, 0x04, 0x22, 0x26, 0x28, 0x25, 0x2E,
                                 0x2D, 0x1F, 0x23, 0x0C, 0x0F, 0x01, 0x11, 0x20, 0x09, 0x0D, 0x07, 0x10, 0x06] // A..Z
        for (i, k) in letters.enumerated() { t[UInt16(0x41 + i)] = k }
        let digits: [UInt16] = [0x1D, 0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19] // 0..9
        for (i, k) in digits.enumerated() { t[UInt16(0x30 + i)] = k }
        let fkeys: [UInt16] = [0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F,
                               0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A] // F1..F20
        for (i, k) in fkeys.enumerated() { t[UInt16(0x70 + i)] = k }
        let pad: [UInt16] = [0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5B, 0x5C] // numpad 0..9
        for (i, k) in pad.enumerated() { t[UInt16(0x60 + i)] = k }
        let rest: [(UInt16, UInt16)] = [
            (0x08, 0x33), (0x09, 0x30), (0x0D, 0x24), (0x10D, 0x4C), (0x1B, 0x35), (0x20, 0x31),
            (0x21, 0x74), (0x22, 0x79), (0x23, 0x77), (0x24, 0x73), (0x25, 0x7B), (0x26, 0x7E), (0x27, 0x7C), (0x28, 0x7D),
            (0x2C, 0x69), (0x2D, 0x72), (0x2E, 0x75), (0x91, 0x6B), (0x13, 0x71), (0x14, 0x39),
            (0x6A, 0x43), (0x6B, 0x45), (0x6D, 0x4E), (0x6E, 0x41), (0x6F, 0x4B), (0x90, 0x47),
            (0xBA, 0x29), (0xBB, 0x18), (0xBC, 0x2B), (0xBD, 0x1B), (0xBE, 0x2F), (0xBF, 0x2C), (0xC0, 0x32),
            (0xDB, 0x21), (0xDC, 0x2A), (0xDD, 0x1E), (0xDE, 0x27), (0xE2, 0x0A),
            (0xAD, 0x4A), (0xAE, 0x49), (0xAF, 0x48),
        ]
        for (w, m) in rest { t[w] = m }
        return t
    }()

    /// Keys that a real Apple keyboard reports with the Fn / numeric-pad flags.
    static func hardwareFlags(_ mac: UInt16) -> (fn: Bool, pad: Bool) {
        switch mac {
        case 0x7B, 0x7C, 0x7D, 0x7E: return (true, true)
        case 0x73, 0x74, 0x75, 0x77, 0x79, 0x72,
             0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A:
            return (true, false)
        case 0x41, 0x43, 0x45, 0x47, 0x4B, 0x4C, 0x4E, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5B, 0x5C:
            return (false, true)
        default: return (false, false)
        }
    }

    // Names for the remap editor
    static let hostKeyNames: [(String, UInt16)] = {
        var r: [(String, UInt16)] = [("Space", 0x20), ("Enter", 0x0D), ("Tab", 0x09), ("Esc", 0x1B), ("Backspace", 0x08)]
        for i in 0..<26 { r.append((String(UnicodeScalar(65 + i)!), UInt16(0x41 + i))) }
        for i in 0..<10 { r.append(("\(i)", UInt16(0x30 + i))) }
        for i in 1...12 { r.append(("F\(i)", UInt16(0x6F + i))) }
        r += [("Left", 0x25), ("Up", 0x26), ("Right", 0x27), ("Down", 0x28)]
        return r
    }()
    static func hostKeyName(_ vk: UInt16) -> String { hostKeyNames.first { $0.1 == vk }?.0 ?? String(format: "0x%02X", vk) }
    static func macKeyName(_ code: UInt16) -> String {
        if let vk = table.first(where: { $0.value == code && $0.key < 0x100 })?.key,
           let n = hostKeyNames.first(where: { $0.1 == vk })?.0 { return n }
        return String(format: "key %d", code)
    }
}
