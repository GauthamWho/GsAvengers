// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import CoreGraphics
import Foundation

/// The Quick Ring's pure decisions: when a double-tap of ⌃ counts, which
/// actions the ring shows in each state, and where it opens near a screen edge.
enum QuickRingTests {
    static func run(_ suite: TestSuite) {
        suite.run("quick ring double tap") { doubleTap(suite) }
        suite.run("quick ring items") { items(suite) }
        suite.run("quick ring placement") { placement(suite) }
        suite.run("quick ring strings") { strings(suite) }
        suite.run("quick ring click swallowing") { swallowing(suite) }
        suite.run("quick ring trigger migration") { migration(suite) }
    }

    /// Feeds (down?, otherModifiers?, time) and reports whether any step fired.
    private static func fires(_ steps: [(Bool, Bool, TimeInterval)],
                              interruptBefore: Int? = nil) -> Bool {
        var detector = QuickRingDoubleTap()
        var fired = false
        for (index, step) in steps.enumerated() {
            if index == interruptBefore { detector.interrupt() }
            if detector.controlChanged(isDown: step.0, otherModifiers: step.1, at: step.2) { fired = true }
        }
        return fired
    }

    private static func doubleTap(_ suite: TestSuite) {
        let clean: [(Bool, Bool, TimeInterval)] = [(true, false, 10.00), (false, false, 10.08),
                                                   (true, false, 10.20), (false, false, 10.27)]
        suite.expect(fires(clean), "two quick clean taps of Control open the ring")
        suite.expect(!fires(Array(clean.prefix(3))), "the ring opens on the second release, not the press")
        suite.expect(!fires([(true, false, 10.00), (false, false, 10.08)]), "one tap does nothing")

        suite.expect(!fires([(true, false, 10.00), (false, false, 10.08),
                             (true, false, 10.45), (false, false, 10.50)]),
                     "a gap over 300 ms is two separate taps")
        suite.expect(fires([(true, false, 10.00), (false, false, 10.08),
                            (true, false, 10.37), (false, false, 10.42)]),
                     "a gap just under 300 ms still counts")

        suite.expect(!fires([(true, false, 10.00), (false, false, 10.40),
                             (true, false, 10.50), (false, false, 10.55)]),
                     "a held first Control is not a tap")
        suite.expect(!fires([(true, false, 10.00), (false, false, 10.08),
                             (true, false, 10.20), (false, false, 10.60)]),
                     "a held second Control (⌃-drag) is not a tap")

        suite.expect(!fires(clean, interruptBefore: 2),
                     "a key typed between the taps starts over")
        suite.expect(!fires(clean, interruptBefore: 1),
                     "a key typed or a click while Control is down (⌃-typing, ⌃-click) is not a tap")
        suite.expect(!fires([(true, false, 10.00), (false, false, 10.08),
                             (true, true, 10.20), (false, false, 10.27)]),
                     "Control with ⌘, ⌥, ⇧ or Fn is a chord, not a tap")

        // Three quick taps open once, not twice: the pair is used up.
        var detector = QuickRingDoubleTap()
        var count = 0
        for (down, time) in [(true, 1.00), (false, 1.06), (true, 1.15), (false, 1.21),
                             (true, 1.30), (false, 1.36)] as [(Bool, TimeInterval)] {
            if detector.controlChanged(isDown: down, otherModifiers: false, at: time) { count += 1 }
        }
        suite.expect(count == 1, "a third tap does not open a second ring")
        // A ⌃-chord the system takes before any tap hears its key (⌃→ to the
        // next Space) still moves the window server's press count.
        var chord = QuickRingDoubleTap()
        _ = chord.controlChanged(isDown: true, otherModifiers: false, at: 1.00)
        _ = chord.controlChanged(isDown: false, otherModifiers: false, interrupted: true, at: 1.08)
        _ = chord.controlChanged(isDown: true, otherModifiers: false, at: 1.20)
        suite.expect(!chord.controlChanged(isDown: false, otherModifiers: false, at: 1.27),
                     "a ⌃-shortcut swallowed by the system is not the first tap")
        var second = QuickRingDoubleTap()
        _ = second.controlChanged(isDown: true, otherModifiers: false, at: 1.00)
        _ = second.controlChanged(isDown: false, otherModifiers: false, at: 1.08)
        _ = second.controlChanged(isDown: true, otherModifiers: false, at: 1.20)
        suite.expect(!second.controlChanged(isDown: false, otherModifiers: false, interrupted: true, at: 1.27),
                     "nor the second")
        suite.expect(fires([(false, false, 9.0), (true, false, 10.00), (false, false, 10.08),
                            (true, false, 10.20), (false, false, 10.27)]),
                     "a stray release with no press first is ignored")
        suite.expect(QuickRingTrigger.isControlClick(control: true, command: false, option: false, shift: false)
                     && !QuickRingTrigger.isControlClick(control: true, command: true, option: false, shift: false)
                     && !QuickRingTrigger.isControlClick(control: false, command: false, option: false, shift: false),
                     "only Control alone makes a Control-click; ⌃⌘ stays the window drag")
    }

    private static func context(recording: Bool = false, screenshot: Bool = true, recorder: Bool = true,
                                clipboard: Bool = true) -> QuickRingContext {
        QuickRingContext(recording: recording, screenshotAvailable: screenshot, recorderAvailable: recorder,
                         clipboardAvailable: clipboard)
    }

    private static func items(_ suite: TestSuite) {
        let full = QuickRingSupport.entries(for: context())
        suite.expect(full.map(\.item) == [.capture, .record, .clipboard, .windows],
                     "the ring holds capture, record, clipboard and windows")
        suite.expect(full.count <= QuickRingSupport.maxItems && QuickRingSupport.maxItems == 4,
                     "never more actions than number keys")
        suite.expect(full.allSatisfy { !$0.isCurrent }, "nothing is lit without a recording")

        let recording = QuickRingSupport.entries(for: context(recording: true))
        suite.expect(recording.map(\.item).contains(.stopRecording) && !recording.map(\.item).contains(.record),
                     "while recording, Record becomes Stop")
        suite.expect(recording.firstIndex { $0.item == .stopRecording } == full.firstIndex { $0.item == .record },
                     "Stop sits where Record was")

        let bare = QuickRingSupport.entries(for: context(screenshot: false, recorder: false, clipboard: false))
        suite.expect(bare.map(\.item) == [.windows], "uninstalled tools leave no dead buttons")
        suite.expect(QuickRingItem.capture.waitsForRingToLeave && QuickRingItem.record.waitsForRingToLeave
                     && !QuickRingItem.clipboard.waitsForRingToLeave,
                     "capture and recording wait for the ring to be gone")
    }

    private static func placement(_ suite: TestSuite) {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let reach = QuickRingLayout.outerRadius + QuickRingLayout.edgeMargin
        let middle = CGPoint(x: 700, y: 500)
        suite.expect(QuickRingPlacement.center(pointer: middle, visibleFrame: screen) == middle,
                     "away from the edges the ring is centred on the pointer")

        let corner = QuickRingPlacement.center(pointer: CGPoint(x: 3, y: 2), visibleFrame: screen)
        suite.expect(corner == CGPoint(x: reach, y: reach), "in the bottom-left corner it shifts inward on both axes")
        let topRight = QuickRingPlacement.center(pointer: CGPoint(x: 1510, y: 940), visibleFrame: screen)
        suite.expect(topRight == CGPoint(x: 1512 - reach, y: 944 - reach), "and in the top-right corner too")
        let leftEdge = QuickRingPlacement.center(pointer: CGPoint(x: 20, y: 500), visibleFrame: screen)
        suite.expect(leftEdge == CGPoint(x: reach, y: 500), "at one edge only that axis moves")

        // A second display to the left, below the main one's origin.
        let side = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let onSide = QuickRingPlacement.center(pointer: CGPoint(x: -5, y: -190), visibleFrame: side)
        suite.expect(onSide == CGPoint(x: -reach, y: -200 + reach),
                     "on a display left of the main one the ring stays on that display")
        let ring = CGRect(x: onSide.x - QuickRingLayout.outerRadius, y: onSide.y - QuickRingLayout.outerRadius,
                          width: QuickRingLayout.outerRadius * 2, height: QuickRingLayout.outerRadius * 2)
        suite.expect(side.contains(ring), "the whole ring is on screen")

        let tiny = CGRect(x: 0, y: 0, width: 200, height: 900)
        suite.expect(QuickRingPlacement.center(pointer: CGPoint(x: 10, y: 450), visibleFrame: tiny).x == 100,
                     "a screen narrower than the ring centres it")

        let center = CGPoint(x: 500, y: 500)
        suite.expect(QuickRingPlacement.highlightedIndex(pointer: center, center: center, itemCount: 8) == nil,
                     "the pointer in the hole picks nothing")
        suite.expect(QuickRingPlacement.highlightedIndex(
            pointer: CGPoint(x: 500, y: 500 + QuickRingLayout.itemRadius), center: center, itemCount: 8) == 0,
                     "straight up is the first action")
        suite.expect(QuickRingPlacement.highlightedIndex(
            pointer: CGPoint(x: 500 + QuickRingLayout.itemRadius, y: 500), center: center, itemCount: 8) == 2,
                     "to the right is the third of eight, clockwise")
        suite.expect(QuickRingPlacement.highlightedIndex(
            pointer: CGPoint(x: 500, y: 500 + QuickRingLayout.outerRadius + 40), center: center, itemCount: 8) == nil,
                     "past the ring picks nothing")
        suite.expect(QuickRingLayout.dismissDistance > QuickRingLayout.outerRadius + 100,
                     "moving away closes it only well past the ring")
        // Eight buttons round the ring never overlap.
        let chord = 2 * QuickRingLayout.itemRadius * sin(.pi / CGFloat(QuickRingSupport.maxItems))
        suite.expect(chord > QuickRingLayout.itemDiameter, "eight buttons fit round the ring without touching")
    }

    private static func swallowing(_ suite: TestSuite) {
        var swallow = QuickRingClickSwallow()
        swallow.claim(2)
        suite.expect(!swallow.takesRest(isPress: false, isRelease: true, button: 0),
                     "another button's release is never taken")
        suite.expect(swallow.takesRest(isPress: false, isRelease: true, button: 2),
                     "the release of the opening click is the ring's")
        suite.expect(!swallow.takesRest(isPress: false, isRelease: true, button: 2),
                     "and only that one release")

        // The release went missing (the tap was paused): the next press of the
        // same button clears the stale claim instead of eating a later release.
        swallow.claim(0)
        suite.expect(!swallow.takesRest(isPress: true, isRelease: false, button: 0) && swallow.button == nil,
                     "a new press drops a stale claim")
        suite.expect(!swallow.takesRest(isPress: false, isRelease: true, button: 0),
                     "so the ordinary click's release reaches the app")
        swallow.claim(2)
        swallow.reset()
        suite.expect(swallow.button == nil, "a paused tap or switching off forgets the claim")
    }

    private static func migration(_ suite: TestSuite) {
        for (saved, expected) in [(true, true), (false, false)] {
            let name = "vorss.tests.quickRingMigration"
            guard let defaults = UserDefaults(suiteName: name) else { continue }
            defaults.removePersistentDomain(forName: name)
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(saved, forKey: DefaultsKey.quickRingOptionDoubleTapLegacy)
            Defaults.migrateQuickRingDoubleTapToControl(in: defaults)
            suite.expect(defaults.object(forKey: DefaultsKey.quickRingControlDoubleTap) as? Bool == expected,
                         "the ⌥⌥ choice (\(saved)) carries over to ⌃⌃")
            suite.expect(defaults.object(forKey: DefaultsKey.quickRingOptionDoubleTapLegacy) == nil,
                         "the old ⌥⌥ key is removed")
            defaults.set(!expected, forKey: DefaultsKey.quickRingControlDoubleTap)
            Defaults.migrateQuickRingDoubleTapToControl(in: defaults)
            suite.expect(defaults.bool(forKey: DefaultsKey.quickRingControlDoubleTap) == !expected,
                         "a later ⌃⌃ choice is never overwritten")
        }
        suite.expect(!SettingsBackupSupport.exportKeys().contains(DefaultsKey.quickRingOptionDoubleTapLegacy)
                     && SettingsBackupSupport.exportKeys().contains(DefaultsKey.quickRingControlDoubleTap),
                     "backups carry the ⌃⌃ switch, not the old one")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let s = FeatureStrings.quickRing(language)
            let all = [s.title, s.hubDescription, s.triggersCaption, s.controlDoubleTap, s.controlClick,
                       s.controlClickCaption, s.middleClick, s.middleClickCaption, s.tryIt,
                       s.capture, s.record, s.stop, s.clipboard, s.windows]
            suite.expect(all.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                         "every Quick Ring string is translated for \(language.rawValue)")
            let labels = [s.capture, s.record, s.stop, s.clipboard, s.windows]
            suite.expect(labels.allSatisfy { $0.count <= 10 },
                         "the ring's labels stay short enough for a 52 pt button in \(language.rawValue)")
            let setup = FeatureStrings.gsMacSetup(language)
            suite.expect(!setup.quickRing.isEmpty, "the setup row is translated for \(language.rawValue)")
        }
        suite.expect(GsMacEssential.allCases.contains(.quickRing)
                     && GsMacEssential.defaultFeatures.contains(.quickRing),
                     "the Quick Ring is one of G’s Mac's essentials")
        suite.expect(Set(QuickRingTrigger.allCases.map(\.defaultsKey)) == Set(AppFeature.quickRing.enabledKeys),
                     "each trigger is one of the feature's own switches")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.quickRingControlDoubleTap] as? Bool == true
                     && registered[DefaultsKey.quickRingControlClick] as? Bool == false
                     && registered[DefaultsKey.quickRingMiddleClick] as? Bool == false,
                     "a fresh install opens the ring by ⌃⌃ only; the click triggers take clicks, so they start off")
    }
}
