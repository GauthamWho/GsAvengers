// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit
import HIDEventSystem
import ServiceManagement

/// Runs once, on the first launch of the thirteen-feature, one-process app:
///  - removes every setting of the features that were deleted,
///  - puts back anything those features changed in the system while they ran,
///  - adopts the old Clipboard helper's settings (history files already live
///    in a shared folder; sharing pairings in ~/Library/Application Support/
///    GsAvengers/config.json are read as they are),
///  - turns launch at login on, for the main app only.
enum LeanMigration {
    static let doneKey = "leanMigrationDone.1"

    static func runIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }
        undoSystemSideEffects(defaults: defaults)
        removeDeletedSettings(in: defaults)
        adoptHelperSettings(into: defaults)
        defaults.set(true, forKey: doneKey)
        // Start at login by default (the main app only; helpers never register).
        LaunchAtLogin.setEnabled(true) { _, _ in }
    }

    // MARK: - Settings of deleted features

    /// Removes the deleted features' keys and their availability switches.
    static func removeDeletedSettings(in defaults: UserDefaults) {
        let kept = Set(AppFeature.allCases.map(\.availabilityKey))
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("featureAvailable.") && !kept.contains(key) {
            defaults.removeObject(forKey: key)
        }
        for key in LeanMigrationKeys.removed {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Old helper apps

    /// The Clipboard helper kept its settings under its own bundle id; they
    /// move into this app's preferences once (only keys not already set here).
    static func adoptHelperSettings(into defaults: UserDefaults) {
        guard let main = Bundle.main.bundleIdentifier else { return }
        let keys = ["maxItems", "smartCleanup", "pasteAfterPick", "shortcut", "emojiShortcut",
                    "recentEmoji", "permissionCardDismissed", "accentOverride"]
        for suffix in [".clipboard", ".share"] {
            guard let old = UserDefaults(suiteName: main + suffix),
                  let values = old.persistentDomain(forName: main + suffix) else { continue }
            for key in keys where defaults.object(forKey: key) == nil {
                if let value = values[key] { defaults.set(value, forKey: key) }
            }
        }
    }

    // MARK: - System side effects

    static func undoSystemSideEffects(defaults: UserDefaults) {
        restoreSpacesOrder(defaults: defaults)
        restoreMouseAcceleration()
        removeSuperKeyMapping(defaults: defaults)
        unregisterFanHelper(defaults: defaults)
    }

    /// "Keep Spaces in order" held the Dock's mru-spaces preference; put back
    /// what it found, then restart the Dock so it reads it.
    private static func restoreSpacesOrder(defaults: UserDefaults) {
        guard let marker = defaults.string(forKey: "spacesOrderRestore") else { return }
        let domain = "com.apple.dock" as CFString
        switch marker {
        case "absent":
            CFPreferencesSetValue("mru-spaces" as CFString, nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        case "on":
            CFPreferencesSetValue("mru-spaces" as CFString, kCFBooleanTrue, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        default:
            return
        }
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
    }

    /// "Mouse acceleration off" changed HID properties of connected mice and
    /// journaled the originals for this boot; put each one back.
    private static func restoreMouseAcceleration() {
        guard let url = PrivateFileStore.containerURL?.appendingPathComponent("MouseAccelerationRecovery.json"),
              let data = try? Data(contentsOf: url) else { return }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let journal = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let boot = (journal["bootTime"] as? NSNumber)?.int64Value, boot == currentBootTime(),
              let entries = journal["entries"] as? [[String: Any]] else { return }
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else { return }
        for entry in entries {
            guard let id = (entry["registryID"] as? NSNumber)?.uint64Value,
                  let key = entry["key"] as? String,
                  let original = entry["original"] as? [String: Any],
                  let raw = (original["rawValue"] as? NSNumber)?.int64Value else { continue }
            let isBool = (original["isBoolean"] as? Bool) ?? false
            let value: CFTypeRef = isBool ? (raw == 0 ? kCFBooleanFalse : kCFBooleanTrue) : raw as CFNumber
            for service in services {
                guard let reg = IOHIDServiceClientGetRegistryID(service) as? NSNumber,
                      reg.uint64Value == id else { continue }
                _ = IOHIDServiceClientSetProperty(service, key as CFString, value)
            }
        }
    }

    /// The Super key feature remapped one key to F18 with hidutil. Remove
    /// only that mapping, leaving any other mapping in place.
    private static func removeSuperKeyMapping(defaults: UserDefaults) {
        guard defaults.bool(forKey: "superKeyMappingApplied") else { return }
        let f18: Int64 = 0x70000006D
        let get = Shell.run("/usr/bin/hidutil", ["property", "--matching", "{\"PrimaryUsagePage\":1,\"PrimaryUsage\":6}",
                                                 "--get", "UserKeyMapping"])
        guard get.status == 0 else { return }
        // hidutil prints the mapping table as a property list fragment;
        // keep every pair whose destination is not F18.
        var pairs: [(Int64, Int64)] = []
        var src: Int64?
        for line in get.output.split(separator: "\n") {
            let digits = line.split(separator: "=").last.map { $0.filter(\.isNumber) } ?? ""
            if line.contains("HIDKeyboardModifierMappingSrc") { src = Int64(digits) }
            if line.contains("HIDKeyboardModifierMappingDst"), let s = src, let d = Int64(digits) {
                pairs.append((s, d)); src = nil
            }
        }
        let kept = pairs.filter { $0.1 != f18 }
        guard kept.count != pairs.count else { return }
        let body = kept.map { "{\"HIDKeyboardModifierMappingSrc\":\($0.0),\"HIDKeyboardModifierMappingDst\":\($0.1)}" }
            .joined(separator: ",")
        _ = Shell.run("/usr/bin/hidutil", ["property", "--matching", "{\"PrimaryUsagePage\":1,\"PrimaryUsage\":6}",
                                           "--set", "{\"UserKeyMapping\":[\(body)]}"])
    }

    /// Fan control registered a privileged helper; take the registration away.
    private static func unregisterFanHelper(defaults: UserDefaults) {
        guard !(defaults.string(forKey: "fanControlHelperVersion") ?? "").isEmpty,
              let id = Bundle.main.bundleIdentifier else { return }
        SMAppService.daemon(plistName: "\(id).fan-control.plist").unregister { _ in }
    }

    private static func currentBootTime() -> Int64? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0, bootTime.tv_sec > 0 else { return nil }
        return Int64(bootTime.tv_sec)
    }
}
