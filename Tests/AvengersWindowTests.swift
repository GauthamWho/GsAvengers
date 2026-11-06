// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

/// The G’s Avengers window shows no switch that is not wired to the real
/// thing: each of this app's switches writes the very keys its feature runs
/// on, and the helpers' state and commands survive the trip over the wire
/// (the same HelperWire file is compiled into both helpers).
enum AvengersWindowTests {
    static func run(_ suite: TestSuite) {
        suite.run("avengers switches write the real keys") { switches(suite) }
        suite.run("avengers sharing round-trips over the wire") { sharingWire(suite) }
        suite.run("avengers clipboard round-trips over the wire") { clipboardWire(suite) }
        suite.run("avengers strings") { strings(suite) }
    }

    private static func fresh() -> UserDefaults {
        // No register(defaults:) here: the registration domain is shared by
        // the whole test process. Every key a check reads is set explicitly.
        let name = "com.vorssaint.tests.avengers.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func switches(_ suite: TestSuite) {
        let expected: [AvengersSwitch: [String]] = [
            .quickRing: [DefaultsKey.quickRingControlDoubleTap],
            .ringDoubleTap: [DefaultsKey.quickRingControlDoubleTap],
            .ringControlClick: [DefaultsKey.quickRingControlClick],
            .ringMiddleClick: [DefaultsKey.quickRingMiddleClick],
            .switcher: [DefaultsKey.switcherEnabled],
            .closeQuits: [DefaultsKey.autoQuitEnabled],
            .snapping: [DefaultsKey.windowEdgeSnapEnabled, DefaultsKey.windowLayoutShortcutsEnabled],
            .cutPaste: [DefaultsKey.finderCutPasteEnabled],
            .screenshot: [],
            .recorder: [],
            .lidClosed: [DefaultsKey.clamshellPreferred, DefaultsKey.keepAwakeAutoStart],
            .dimOnLidClose: [DefaultsKey.dimScreenOnLidClose],
            .clipboardHelper: [DefaultsKey.gsavClipboardHelperEnabled],
        ]
        suite.expect(Set(expected.keys) == Set(AvengersSwitch.allCases), "every switch has its keys checked")
        for item in AvengersSwitch.allCases {
            let defaults = fresh()
            let keys = expected[item] ?? []
            if let feature = item.feature { defaults.set(false, forKey: feature.availabilityKey) }
            for key in keys { defaults.set(false, forKey: key) }
            for key in item.keys { defaults.set(false, forKey: key) }
            suite.expect(!item.isOn(in: defaults), "\(item) reads off when its keys are off")

            item.write(true, in: defaults)
            suite.expect(keys.allSatisfy { defaults.bool(forKey: $0) }, "\(item) on sets \(keys)")
            if let feature = item.feature {
                suite.expect(item.keys.isEmpty || !item.isOn(in: defaults),
                             "\(item) never reads on while \(feature) is uninstalled")
                // Installing goes through FeatureRuntime.setAvailable (the hub's hardware gate).
                defaults.set(true, forKey: feature.availabilityKey)
            }
            suite.expect(item.isOn(in: defaults), "\(item) reads back on")

            item.write(false, in: defaults)
            suite.expect(keys.allSatisfy { !defaults.bool(forKey: $0) }, "\(item) off clears \(keys)")
            if item.keys.isEmpty, let feature = item.feature {
                // Its switch is the install itself; the model uninstalls through FeatureRuntime.
                defaults.set(false, forKey: feature.availabilityKey)
            }
            suite.expect(!item.isOn(in: defaults), "\(item) reads back off")
        }

        // Each switch reads the same keys its feature's own Settings and panel use.
        for item in AvengersSwitch.allCases {
            guard let feature = item.feature, !feature.enabledKeys.isEmpty else { continue }
            suite.expect(item.keys.allSatisfy(feature.enabledKeys.contains) || item == .lidClosed || item == .dimOnLidClose,
                         "\(item) uses \(feature)'s own enable keys")
        }
        let defaults = fresh()
        defaults.set(true, forKey: AppFeature.quickRing.availabilityKey)
        defaults.set(false, forKey: DefaultsKey.quickRingControlDoubleTap)
        defaults.set(true, forKey: DefaultsKey.quickRingMiddleClick)
        suite.expect(AvengersSwitch.quickRing.isOn(in: defaults), "the Quick Ring reads on while any trigger is on")
        AvengersSwitch.quickRing.write(false, in: defaults)
        suite.expect(AppFeature.quickRing.enabledKeys.allSatisfy { !defaults.bool(forKey: $0) },
                     "switching the Quick Ring off turns every trigger off")
        defaults.set(false, forKey: AppFeature.switcher.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.switcherEnabled)
        suite.expect(!AvengersSwitch.switcher.isOn(in: defaults), "an uninstalled feature never reads on")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.gsavClipboardHelperEnabled] as? Bool == true,
                     "the clipboard helper runs on a fresh install")
    }

    private static func sharingWire(_ suite: TestSuite) {
        let state = HelperWire.ShareState(
            connected: true, paused: true, active: false, trusted: true, peer: "LAPTOP-1", peerId: "abc",
            lastSeen: "", paired: true, pairCode: "123456", pairConfirmed: false, side: 2, shareClipboard: false,
            mouseSpeed: 1.7, scrollSpeed: 0.6, reverseScroll: true,
            rules: [HelperWire.ShareRule(id: "ctrl.cmd", group: "Main keys", windows: "Ctrl", mac: "⌘", on: false)])
        // Through a real plist round trip, as a distributed notification carries it.
        let info = HelperWire.userInfo(state: state)
        let data = try? PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
        let carried = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]
        suite.expect(HelperWire.state(HelperWire.ShareState.self, from: carried) == state,
                     "the sharing state arrives exactly as the helper sent it")
        suite.expect(HelperWire.state(HelperWire.ShareState.self, from: ["json": "{}"]) == nil
                     && HelperWire.state(HelperWire.ShareState.self, from: nil) == nil,
                     "a broken or missing state is ignored, never half-read")

        let commands: [HelperWire.ShareCommand] = [
            .show, .state, .pause, .resume, .confirmPair, .rule("win.fn", true), .rule("ctrl.cmd", false),
            .side(0), .side(3), .mouseSpeed(1.5), .scrollSpeed(0.25), .reverseScroll(true), .shareClipboard(false),
        ]
        for command in commands {
            suite.expect(HelperWire.shareCommand(from: HelperWire.userInfo(command)) == command,
                         "\(command) reaches the sharing helper unchanged")
        }
        suite.expect(HelperWire.shareCommand(from: ["cmd": "side", "value": "7"]) == nil, "an unknown side is refused")
        suite.expect(HelperWire.shareCommand(from: ["cmd": "mouseSpeed", "value": "99"]) == .mouseSpeed(2.5),
                     "the pointer speed stays inside the window's slider range")
        suite.expect(HelperWire.shareCommand(from: ["cmd": "rule", "value": "1"]) == nil, "a rule needs its id")
        suite.expect(HelperWire.shareCommand(from: ["cmd": "nope"]) == nil, "unknown commands do nothing")
    }

    private static func clipboardWire(_ suite: TestSuite) {
        let state = HelperWire.ClipboardState(pasteAfterPick: false, smartCleanup: true, maxItems: 500,
                                              shortcut: "⌃⇧V", emojiShortcut: "fn E")
        suite.expect(HelperWire.state(HelperWire.ClipboardState.self, from: HelperWire.userInfo(state: state)) == state,
                     "the clipboard settings arrive exactly as the helper sent them")
        let commands: [HelperWire.ClipboardCommand] = [
            .show, .emoji, .settings, .about, .state, .pasteAfterPick(false), .smartCleanup(true), .maxItems(0), .maxItems(1000),
        ]
        for command in commands {
            suite.expect(HelperWire.clipboardCommand(from: HelperWire.userInfo(command)) == command,
                         "\(command) reaches the clipboard helper unchanged")
        }
        suite.expect(HelperWire.clipboardCommand(from: ["cmd": "maxItems", "value": "-1"]) == nil,
                     "a negative history size is refused")
    }

    private static func strings(_ suite: TestSuite) {
        let english = FeatureStrings.avengers(.enUS).all
        suite.expect(english.count == AvengersStrings.count, "every field is listed")
        for language in AppLanguage.allCases {
            let all = FeatureStrings.avengers(language).all
            suite.expect(all.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                         "every window string is translated for \(language.rawValue)")
            for (index, value) in all.enumerated() {
                let placeholders = { (text: String) in
                    text.components(separatedBy: "%").dropFirst().map { $0.prefix(3).filter { "@d$12".contains($0) } }.sorted()
                }
                suite.expect(placeholders(value) == placeholders(english[index]),
                             "\(language.rawValue) string \(index) keeps the English placeholders")
            }
            let s = FeatureStrings.avengers(language)
            suite.expect([s.home, s.sharing, s.keyboard, s.windowsApps, s.capture, s.lidClosed, s.more].allSatisfy { $0.count <= 24 },
                         "the sidebar names fit the sidebar in \(language.rawValue)")
        }
    }
}
