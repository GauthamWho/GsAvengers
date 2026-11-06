// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import CoreGraphics
import Foundation

/// The thirteen features and the Home page's switches: every switch writes
/// the very keys its service reads, nothing else is left in the catalog, the
/// one-time migration removes the deleted features' settings, and every new
/// string exists in all fifteen languages.
enum AvengersFeatureTests {
    static func run(_ suite: TestSuite) {
        suite.run("thirteen features, four groups") { catalog(suite) }
        suite.run("every Home switch writes the real setting") { switches(suite) }
        suite.run("lean migration removes deleted settings") { migration(suite) }
        suite.run("home strings in every language") { strings(suite) }
        suite.run("taps never ask for pointer movement at rest") { tapMasks(suite) }
    }

    private static func fresh() -> (UserDefaults, String) {
        let name = "com.vorssaint.tests.avengers.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private static func catalog(_ suite: TestSuite) {
        let names = Set(AppFeature.allCases.map(\.rawValue))
        suite.expect(names == ["switcher", "autoQuit", "windowLayout", "dockPreview", "finderCutPaste",
                               "sharing", "clipboardHistory", "urlCleaner", "screenshot", "screenRecorder",
                               "screenOCR", "quickRing", "keepAwake"],
                     "exactly the thirteen kept features: \(names.sorted())")
        suite.expect(FeatureGroup.allCases.count == 4, "four Home groups")
        for group in FeatureGroup.allCases {
            suite.expect(!AppFeature.features(in: group).isEmpty, "group \(group.rawValue) is not empty")
        }
        let defaults = AppFeature.availabilityDefaults
        suite.expect(defaults.count == 13 && defaults.values.allSatisfy { ($0 as? Bool) == true },
                     "every feature is installed on a new Mac")
    }

    /// The services read `isOn` (availability plus enable keys). Switching on
    /// sets them all; switching off clears them all; nothing else is written.
    private static func switches(_ suite: TestSuite) {
        let expectedKeys: [AppFeature: [String]] = [
            .switcher: [DefaultsKey.switcherEnabled],
            .autoQuit: [DefaultsKey.autoQuitEnabled],
            .windowLayout: [DefaultsKey.windowEdgeSnapEnabled, DefaultsKey.windowLayoutShortcutsEnabled],
            .dockPreview: [DefaultsKey.dockPreviewEnabled],
            .finderCutPaste: [DefaultsKey.finderCutPasteEnabled],
            .sharing: [DefaultsKey.sharingEnabled],
            .clipboardHistory: [DefaultsKey.gsavClipboardHelperEnabled],
            .urlCleaner: [DefaultsKey.urlCleanerEnabled],
            .quickRing: [DefaultsKey.quickRingControlDoubleTap],
            .screenshot: [], .screenRecorder: [], .screenOCR: [], .keepAwake: [],
        ]
        for feature in AppFeature.allCases {
            let (defaults, name) = fresh()
            suite.expect(feature.enabledKeys == expectedKeys[feature], "\(feature.rawValue) enable keys")
            suite.expect(!feature.isOn(in: defaults), "\(feature.rawValue) starts off in an empty domain")
            feature.write(true, in: defaults)
            suite.expect(feature.isOn(in: defaults), "\(feature.rawValue) on after switching on")
            suite.expect(defaults.bool(forKey: feature.availabilityKey), "\(feature.rawValue) availability written")
            for key in feature.enabledKeys {
                suite.expect(defaults.bool(forKey: key), "\(feature.rawValue) wrote \(key) on")
            }
            let written = Set(defaults.persistentDomain(forName: name)?.keys.map { $0 } ?? [])
            suite.expect(written == Set([feature.availabilityKey] + feature.enabledKeys),
                         "\(feature.rawValue) writes only its own keys: \(written.sorted())")
            feature.write(false, in: defaults)
            suite.expect(!feature.isOn(in: defaults), "\(feature.rawValue) off after switching off")
            for key in feature.enabledKeys {
                suite.expect(!defaults.bool(forKey: key), "\(feature.rawValue) wrote \(key) off")
            }
            // One enable key on is enough for a feature with several (snapping).
            if feature.enabledKeys.count > 1 {
                defaults.set(true, forKey: feature.availabilityKey)
                defaults.set(true, forKey: feature.enabledKeys[1])
                suite.expect(feature.isOn(in: defaults), "\(feature.rawValue) on with any of its keys")
            }
            defaults.removePersistentDomain(forName: name)
        }
    }

    private static func migration(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(true, forKey: "featureAvailable.mixer")
        defaults.set(true, forKey: "featureAvailable.switcher")
        for key in LeanMigrationKeys.removed.prefix(20) { defaults.set(true, forKey: key) }
        defaults.set(true, forKey: DefaultsKey.switcherEnabled)
        LeanMigration.removeDeletedSettings(in: defaults)
        suite.expect(defaults.object(forKey: "featureAvailable.mixer") == nil, "a deleted feature's switch is removed")
        suite.expect(defaults.bool(forKey: "featureAvailable.switcher"), "a kept feature's switch stays")
        suite.expect(defaults.bool(forKey: DefaultsKey.switcherEnabled), "a kept feature's setting stays")
        for key in LeanMigrationKeys.removed.prefix(20) {
            suite.expect(defaults.object(forKey: key) == nil, "deleted setting \(key) removed")
        }
        let kept = Set(Mirror(reflecting: DefaultsKey.self).children.compactMap { $0.value as? String })
        suite.expect(LeanMigrationKeys.removed.allSatisfy { !kept.contains($0) }, "no kept key is in the removal list")
        suite.expect(!LeanMigrationKeys.removed.contains(DefaultsKey.switcherEnabled)
                     && !LeanMigrationKeys.removed.contains(DefaultsKey.sharingEnabled),
                     "kept keys are never removed")
        defaults.removePersistentDomain(forName: name)
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let home = FeatureStrings.home(language)
            let values = [home.groupWindows, home.groupSharing, home.groupCapture, home.groupPower,
                          home.dockPreview, home.sharing, home.urlCleaner, home.screenOCR, home.keepAwake,
                          home.keepAwakeNow, home.options, home.pressKeys, home.reset]
            suite.expect(values.count == HomeStrings.count, "home string count")
            suite.expect(values.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                         "\(language.rawValue) has every Home string")
        }
        let english = FeatureStrings.home(.enUS)
        for language in AppLanguage.allCases where language != .enUS {
            suite.expect(FeatureStrings.home(language).groupWindows != english.groupWindows
                         || language == .fr, "\(language.rawValue) group title is translated")
        }
    }

    private static func tapMasks(_ suite: TestSuite) {
        let pointer: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]
        let watcher = LocalInputWatcher.eventMask
        suite.expect(pointer.contains { watcher & (CGEventMask(1) << $0.rawValue) != 0 },
                     "only the take-back watcher (installed while Windows has control) hears the pointer")
    }
}
