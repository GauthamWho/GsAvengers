// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Carbon.HIToolbox
import Foundation

/// Every UserDefaults key used by the app, in one place.
enum DefaultsKey {
    static let language = "appLanguage"                   // AppLanguage.rawValue
    static let appearance = "appAppearance"               // AppAppearance.rawValue
    static let liquidGlassEnabled = "liquidGlassEnabled"  // Liquid Glass in windows and panels on macOS 26+
    static let clamshellPreferred = "clamshellPreferred"  // apply closed-lid mode to every session
    static let dimScreenOnLidClose = "dimScreenOnLidClose" // dim the built-in display to zero while the lid is closed
    static let defaultDuration = "defaultDurationMinutes" // 0 = indefinite
    static let batteryLimit = "batteryLimitPercent"       // 0 = never
    static let keepAwakeAutoStart = "keepAwakeAutoStart"  // start Keep Awake when the app launches
    static let keepAwakeRightClickToggle = "keepAwakeRightClickToggle"
    static let keepAwakeAllowDisplaySleep = "keepAwakeAllowDisplaySleep"
    static let keepAwakeExternalDisplay = "keepAwakeExternalDisplay"
    static let keepAwakeConnectedToPower = "keepAwakeConnectedToPower"
    static let keepAwakeRunningApps = "keepAwakeRunningApps"
    static let keepAwakeRunningAppBundleIDs = "keepAwakeRunningAppBundleIDs"
    // Match mode over the automation conditions: false is Any (one matching
    // condition starts a session), true is All (every enabled condition has
    // to match, and losing one ends the session). Issue #1587.
    static let keepAwakeAutomationRequireAll = "keepAwakeAutomationRequireAll"
    static let keepAwakePauseWhenLocked = "keepAwakePauseWhenLocked"
    static let keepAwakeSwitchUsesUntil = "keepAwakeSwitchUsesUntil" // panel switch restarts the Until chip
    static let keepAwakeUntilTime = "keepAwakeUntilTime"  // last picked end time; 0 = none yet
    static let keepAwakeMouseJiggleEnabled = "keepAwakeMouseJiggleEnabled"
    static let keepAwakeMouseJiggleInterval = "keepAwakeMouseJiggleIntervalMinutes"
    static let hotkeyEnabled = "hotkeyEnabled"
    static let launchAtLoginWanted = "launchAtLoginWanted"  // the user's choice; the system record can be lost
    static let keepAwakeShortcut = "keepAwakeShortcut"    // GlobalShortcut storage value
    static let keepAwakeIconTint = "keepAwakeIconTint"    // KeepAwakeIconTint.rawValue
    static let keepAwakeActiveIcon = "keepAwakeActiveIcon" // KeepAwakeActiveIcon.rawValue
    static let showCountdown = "showCountdownInMenuBar"
    static let hasOnboarded = "hasOnboarded"
    static let sleepDisabledFlag = "vorssDisabledSleep"   // internal guard for pmset disablesleep
    static let dimmedDisplaySavedBrightness = "vorssDimmedDisplaySavedBrightness" // internal guard for closed-lid screen dimming recovery
    static let superKeyModifiers = "superKeyModifiers"     // GlobalShortcutModifiers storage tokens
    // Machine state, never exported: whether the keyboard mapping is in place
    // and which source to take back after a crash.
    static let superKeyMappingApplied = "superKeyMappingApplied"
    static let switcherEnabled = "switcherEnabled"
    static let switcherTakeOverSystemShortcuts = "switcherTakeOverSystemShortcuts"
    // Machine state, never exported: the system shortcuts this process owns,
    // so a launch after a crash can restore them. The switcher-only key is
    // what builds before the take-over was shared wrote; it is read once,
    // folded into the shared one, and then retired.
    static let switcherNativeHotkeysSuppressed = "switcherNativeHotkeysSuppressed"
    static let systemShortcutsSuppressed = "systemShortcutsSuppressed"
    // Storage keys of shortcuts the user chose to take over from macOS. A
    // preference, exported.
    static let systemShortcutTakeOverKeys = "systemShortcutTakeOverKeys"
    static let switcherShortcut = "switcherShortcut"      // GlobalShortcut storage value
    static let switcherWindowShortcut = "switcherWindowShortcut" // GlobalShortcut storage value
    static let switcherAllWindowsShortcut = "switcherAllWindowsShortcut"
    static let switcherAllWindowsShortcutEnabled = "switcherAllWindowsShortcutEnabled"
    static let switcherIconRowMode = "switcherIconRowMode"
    static let switcherSimpleMode = "switcherSimpleMode"  // app-only row without window captures
    static let switcherMergeTabs = "switcherMergeTabs"     // show one switcher entry per app (collapse all of an app's windows)
    static let switcherWindowlessApps = "switcherWindowlessApps" // SwitcherWindowlessApps raw value
    static let switcherMinimizedPlacement = "switcherMinimizedPlacement"
    static let switcherTreatHiddenAppsLikeMinimized = "switcherTreatHiddenAppsLikeMinimized"
    static let switcherShowFullscreenWindows = "switcherShowFullscreenWindows"
    static let switcherAppRules = "switcherAppRules" // [bundle id: SwitcherAppRule raw value]
    static let switcherCurrentSpaceOnly = "switcherCurrentSpaceOnly" // list only windows on the desktop the user is in (issue #337)
    static let switcherSearchPinEnabled = "switcherSearchPinEnabled" // S pins the search field open, off by default so existing users typing S as a search letter see no change
    static let switcherShowShortcutHints = "switcherShowShortcutHints" // show the shortcut bar under the large-icon switcher
    static let switcherAppearanceDelay = "switcherAppearanceDelay" // milliseconds the shortcut must be held before the panel appears (SwitcherSupport.appearanceDelayMillisecondsRange)
    static let switcherInstantSelection = "switcherInstantSelection" // skip selection and reveal animations while browsing
    static let switcherScreenPlacement = "switcherScreenPlacement" // SwitcherScreenPlacement raw value: which display the panel opens on
    static let switcherCurrentDisplayOnly = "switcherCurrentDisplayOnly" // list only windows on the display under the pointer (issue #1391)
    static let switcherMaxColumns = "switcherMaxColumns" // 0 = Auto, else the most items per row (SwitcherSupport.maxColumnsRange)
    static let minimalWindowPreviews = "minimalWindowPreviews"
    static let dockPreviewEnabled = "dockPreviewEnabled"
    static let dockPreviewKeepDockVisible = "dockPreviewKeepDockVisible"
    static let dockPreviewRestoreAutohide = "dockPreviewRestoreAutohide" // local crash recovery; never backed up
    static let dockPreviewCurrentSpaceOnly = "dockPreviewCurrentSpaceOnly"
    static let dockPreviewBackgroundOpacity = "dockPreviewBackgroundOpacity" // how solid the preview panel's material is drawn (DockPreviewSupport.backgroundOpacityRange)
    static let dockPreviewOpenDelay = "dockPreviewOpenDelay" // milliseconds the cursor must rest on a Dock icon before its panel opens (DockPreviewSupport.openDelayMillisecondsRange)
    static let dockPreviewQuitAppOnClose = "dockPreviewQuitAppOnClose" // the preview card's close button quits the owning app instead of closing one window
    static let dockPreviewOrderByCreation = "dockPreviewOrderByCreation" // order Dock Preview windows by ascending window ID (creation proxy) instead of last use
    static let dockClickHide = "dockClickHide"            // click the active app's Dock icon to hide the app
    static let spacesOrderRestore = "spacesOrderRestore" // local recovery; never backed up: "absent" or "on", the mru-spaces state to put back, or "off" when there was nothing to put back
    static let previewSize = "previewSize"                // dock preview thumbnail size (once shared with the app switcher)
    static let switcherPreviewSize = "switcherPreviewSize" // app switcher thumbnail size
    static let finderCutPasteEnabled = "finderCutPasteEnabled"
    static let finderCutPasteShowHUD = "finderCutPasteShowHUD"
    static let finderPasteImageAsFile = "finderPasteImageAsFile"
    static let autoQuitEnabled = "autoQuitEnabled"
    static let autoQuitExceptions = "autoQuitExceptions"  // [bundle id] kept running
    static let autoQuitDockApps = "autoQuitDockApps"  // [bundle id] menu bar apps explicitly allowed to quit in the Dock
    static let shelfClearOnClose = "shelfClearOnClose"
    static let urlCleanerEnabled = "urlCleanerEnabled"
    static let urlCleanerCustomParameters = "urlCleanerCustomParameters"
    static let urlCleanerSiteParameters = "urlCleanerSiteParameters"       // host|name pairs added to one site
    static let urlCleanerDisabledParameters = "urlCleanerDisabledParameters" // built-in host|name pairs switched off
    static let homebrewGroupDependencies = "homebrewGroupDependencies"

    static let fanControlHelperVersion = "fanControlHelperVersion"
    static let windowLayoutWindowGap = "windowLayoutWindowGap" // px between adjacent snapped windows
    static let windowLayoutScreenGap = "windowLayoutScreenGap" // px between a snapped window and the visible frame edge
    static let windowReserveStageManagerSpace = "windowReserveStageManagerSpace"
    static let windowLayoutMarginPercent = "windowLayoutMarginPercent" // per-edge percentage for margin maximize
    static let windowLayoutSideRepeatCyclesThirds = "windowLayoutSideRepeatCyclesThirds" // repeated Left/Right cycles half, 2/3, 1/3 on the same display
    static let windowLayoutIgnoredApps = "windowLayoutIgnoredApps" // apps that temporarily disable window layout while focused

    static let windowPreviewExcludedApps = "windowPreviewExcludedApps" // pause Dock Preview thumbnail capture while these apps are in front (once shared with the app switcher)
    static let switcherPreviewExcludedApps = "switcherPreviewExcludedApps" // pause app switcher thumbnail capture while these apps are in front
    static let screenOCRShortcutEnabled = "screenOCRShortcutEnabled"
    static let screenOCRShortcut = "screenOCRShortcut"
    static let screenOCRRemoveLineBreaks = "screenOCRRemoveLineBreaks"
    static let screenOCRDetectQRCodes = "screenOCRDetectQRCodes" // QR content wins over OCR text
    static let quickRingControlDoubleTap = "quickRingControlDoubleTap"
    /// The embedded clipboard helper (fn V / fn E) runs while this is on.
    static let gsavClipboardHelperEnabled = "gsavClipboardHelperEnabled"
    static let sharingEnabled = "sharingEnabled"
    // Mode chooser visibility for dedicated capture shortcuts.
    static let screenshotShowCaptureMenuOnShortcut = "screenshotShowCaptureMenuOnShortcut"
    static let recorderShowCaptureMenuOnShortcut = "recorderShowCaptureMenuOnShortcut"
    static let screenOCRShowCaptureMenuOnShortcut = "screenOCRShowCaptureMenuOnShortcut"
    // Screenshot capture and editor.
    static let screenshotShortcutEnabled = "screenshotShortcutEnabled"
    static let screenshotShortcut = "screenshotShortcut"
    static let screenshotFullScreenShortcutEnabled = "screenshotFullScreenShortcutEnabled"
    static let screenshotFullScreenShortcut = "screenshotFullScreenShortcut"
    static let screenshotLastCaptureShortcutEnabled = "screenshotLastCaptureShortcutEnabled"
    static let screenshotLastCaptureShortcut = "screenshotLastCaptureShortcut"
    static let recentCapturesShortcutEnabled = "recentCapturesShortcutEnabled"
    static let recentCapturesShortcut = "recentCapturesShortcut"
    static let screenshotClipboardShortcutEnabled = "screenshotClipboardShortcutEnabled"
    static let screenshotClipboardShortcut = "screenshotClipboardShortcut"
    static let screenshotFreeze = "screenshotFreeze"
    static let screenshotHideVorssaintWindows = "screenshotHideVorssaintWindows"
    static let screenshotSaveFolder = "screenshotSaveFolder"
    static let screenshotSaveSubfolder = "screenshotSaveSubfolder"
    static let screenshotFileNamePattern = "screenshotFileNamePattern"
    static let screenshotFileNumberNext = "screenshotFileNumberNext"
    static let screenshotDefaultAction = "screenshotDefaultAction"
    static let screenshotIncludePointer = "screenshotIncludePointer"
    static let screenshotShowLastRegion = "screenshotShowLastRegion"
    static let screenshotHighlightWindows = "screenshotHighlightWindows"
    static let screenshotLoupeStartsOn = "screenshotLoupeStartsOn"
    static let screenshotLoupeRememberZoom = "screenshotLoupeRememberZoom"
    static let screenshotLoupeDefaultZoom = "screenshotLoupeDefaultZoom"
    static let screenshotLoupeLastZoom = "screenshotLoupeLastZoom"
    static let screenshotLoupeSteppedZoomByDefault = "screenshotLoupeSteppedZoomByDefault"
    static let screenshotDownscale = "screenshotDownscale"
    static let screenshotDelay = "screenshotDelay"
    static let screenshotLastTool = "screenshotLastTool"
    static let screenshotLastColor = "screenshotLastColor"
    static let screenshotLastStroke = "screenshotLastStroke"
    static let screenshotLastTextSize = "screenshotLastTextSize"
    static let screenshotLastBlurLevel = "screenshotLastBlurLevel"
    static let screenshotLastBlurStyle = "screenshotLastBlurStyle"
    static let screenshotLastBlurTextOnly = "screenshotLastBlurTextOnly"
    static let screenshotSpotlightDim = "screenshotSpotlightDim"
    static let screenshotLastArrowStyle = "screenshotLastArrowStyle"
    static let screenshotLastSticker = "screenshotLastSticker"
    static let screenshotAnnotationShadows = "screenshotAnnotationShadows"
    static let screenshotToolOrder = "screenshotToolOrder"
    static let screenshotToolShortcuts = "screenshotToolShortcuts"
    static let screenshotToolShortcutsEnabled = "screenshotToolShortcutsEnabled"
    static let screenshotBackdropStyle = "screenshotBackdropStyle"
    static let screenshotBackdropPresets = "screenshotBackdropPresets"
    static let screenshotWatermarkStyle = "screenshotWatermarkStyle"
    static let screenshotWatermarkPresets = "screenshotWatermarkPresets"
    static let screenshotCopyToClipboard = "screenshotCopyToClipboard"
    static let screenshotCopyImageOnly = "screenshotCopyImageOnly"
    static let screenshotPreviewPosition = "screenshotPreviewPosition"
    static let screenshotPreviewTakesFocus = "screenshotPreviewTakesFocus"
    static let screenshotUploadShortcutEnabled = "screenshotUploadShortcutEnabled"
    static let screenshotUploadShortcut = "screenshotUploadShortcut"
    static let screenshotUploadDuration = "screenshotUploadDuration"
    static let screenshotPreviewEnabled = "screenshotPreviewEnabled"
    static let screenshotPreviewDuration = "screenshotPreviewDuration"
    static let screenshotSharingEnabled = "screenshotSharingEnabled"
    // Developer-only endpoint for an isolated test tunnel. The official app
    // ignores it, and settings backups must never carry it to another Mac.
    static let screenshotSharingDeveloperEndpoint = "screenshotSharingDeveloperEndpoint"

    // Screen recorder - records the picked area, keeps the untouched master
    // in Application Support until retention sweeps it.
    static let recorderShortcutEnabled = "recorderShortcutEnabled"
    static let recorderShortcut = "recorderShortcut"
    static let recorderCountdown = "recorderCountdown"
    static let recorderQuality = "recorderQuality"
    static let recorderFrameRate = "recorderFrameRate"
    static let recorderSystemAudio = "recorderSystemAudio"
    static let recorderMicrophone = "recorderMicrophone"
    // Machine state, never exported: whether this Mac's audio system has let
    // a recording hear the Mac's sound through a process tap.
    static let recorderSystemAudioTapVerified = "recorderSystemAudioTapVerified"
    static let recorderSaveFolder = "recorderSaveFolder"
    static let recorderOpenEditor = "recorderOpenEditor"
    static let recorderAutomaticZoom = "recorderAutomaticZoom"
    static let recorderGIFSize = "recorderGIFSize"
    static let recorderGIFFrameRate = "recorderGIFFrameRate"
    static let recorderEditorPresets = "recorderEditorPresets"
    static let recorderSharingEnabled = "recorderSharingEnabled"

    // Window Layout — snapping, global shortcuts and optional pointer gestures.
    static let windowLayoutShortcutsEnabled = "windowLayoutShortcutsEnabled"
    static let windowEdgeSnapEnabled = "windowEdgeSnapEnabled"
    static let windowEdgeSnapDisabledZones = "windowEdgeSnapDisabledZones" // comma-separated visual zone ids
    static let windowEdgeSnapZoneActions = "windowEdgeSnapZoneActions" // zone=action entries, + between split areas
    static let windowLayoutShortcutLeft = "windowLayoutShortcutLeft"
    static let windowLayoutShortcutRight = "windowLayoutShortcutRight"
    static let windowLayoutShortcutTop = "windowLayoutShortcutTop"
    static let windowLayoutShortcutBottom = "windowLayoutShortcutBottom"
    static let windowLayoutShortcutCenterHalf = "windowLayoutShortcutCenterHalf"
    static let windowLayoutShortcutTopLeft = "windowLayoutShortcutTopLeft"
    static let windowLayoutShortcutTopRight = "windowLayoutShortcutTopRight"
    static let windowLayoutShortcutBottomLeft = "windowLayoutShortcutBottomLeft"
    static let windowLayoutShortcutBottomRight = "windowLayoutShortcutBottomRight"
    static let windowLayoutShortcutMaximize = "windowLayoutShortcutMaximize"
    static let windowLayoutShortcutMarginMaximize = "windowLayoutShortcutMarginMaximize"
    static let windowLayoutShortcutCenter = "windowLayoutShortcutCenter"
    static let windowLayoutShortcutRestore = "windowLayoutShortcutRestore"
    static let windowLayoutShortcutLeftThird = "windowLayoutShortcutLeftThird"
    static let windowLayoutShortcutCenterThird = "windowLayoutShortcutCenterThird"
    static let windowLayoutShortcutRightThird = "windowLayoutShortcutRightThird"
    static let windowLayoutShortcutLeftTwoThirds = "windowLayoutShortcutLeftTwoThirds"
    static let windowLayoutShortcutRightTwoThirds = "windowLayoutShortcutRightTwoThirds"
    static let windowLayoutShortcutCenterTwoThirds = "windowLayoutShortcutCenterTwoThirds"
    static let windowLayoutShortcutTopThird = "windowLayoutShortcutTopThird"
    static let windowLayoutShortcutMiddleThird = "windowLayoutShortcutMiddleThird"
    static let windowLayoutShortcutBottomThird = "windowLayoutShortcutBottomThird"
    static let windowLayoutShortcutTopTwoThirds = "windowLayoutShortcutTopTwoThirds"
    static let windowLayoutShortcutBottomTwoThirds = "windowLayoutShortcutBottomTwoThirds"
    static let windowLayoutShortcutTopQuarter = "windowLayoutShortcutTopQuarter"
    static let windowLayoutShortcutUpperMiddleQuarter = "windowLayoutShortcutUpperMiddleQuarter"
    static let windowLayoutShortcutLowerMiddleQuarter = "windowLayoutShortcutLowerMiddleQuarter"
    static let windowLayoutShortcutBottomQuarter = "windowLayoutShortcutBottomQuarter"
    static let windowLayoutShortcutLeftQuarter = "windowLayoutShortcutLeftQuarter"
    static let windowLayoutShortcutLeftMiddleQuarter = "windowLayoutShortcutLeftMiddleQuarter"
    static let windowLayoutShortcutRightMiddleQuarter = "windowLayoutShortcutRightMiddleQuarter"
    static let windowLayoutShortcutRightQuarter = "windowLayoutShortcutRightQuarter"
    static let windowLayoutShortcutPreviousDisplay = "windowLayoutShortcutPreviousDisplay"
    static let windowLayoutShortcutNextDisplay = "windowLayoutShortcutNextDisplay"
    static let windowLayoutShortcutFullScreen = "windowLayoutShortcutFullScreen"
    static let windowLayoutShortcutTopLeftSixth = "windowLayoutShortcutTopLeftSixth"
    static let windowLayoutShortcutTopCenterSixth = "windowLayoutShortcutTopCenterSixth"
    static let windowLayoutShortcutTopRightSixth = "windowLayoutShortcutTopRightSixth"
    static let windowLayoutShortcutBottomLeftSixth = "windowLayoutShortcutBottomLeftSixth"
    static let windowLayoutShortcutBottomCenterSixth = "windowLayoutShortcutBottomCenterSixth"
    static let windowLayoutShortcutBottomRightSixth = "windowLayoutShortcutBottomRightSixth"

    static let simulateBetaUI = "simulateBetaUI"

    /// Features hub availability layer, one key per AppFeature raw value.
    /// Registered true: unavailable features vanish from every surface and
    /// hold no resources, without ever touching their own enable keys.
    static func featureAvailable(_ id: String) -> String { "featureAvailable.\(id)" }
}

enum KeepAwakeIconTint: String, CaseIterable, Identifiable {
    case orange, green, blue, purple, pink, none

    var id: String { rawValue }

    static var current: KeepAwakeIconTint {
        Defaults.sanitizedKeepAwakeIconTint(
            UserDefaults.standard.string(forKey: DefaultsKey.keepAwakeIconTint)
        )
    }

    func title(_ strings: Strings) -> String {
        switch self {
        case .orange: return strings.keepAwakeIconTintOrange
        case .green: return strings.keepAwakeIconTintGreen
        case .blue: return strings.keepAwakeIconTintBlue
        case .purple: return strings.keepAwakeIconTintPurple
        case .pink: return strings.keepAwakeIconTintPink
        case .none: return strings.keepAwakeIconTintNone
        }
    }
}

enum KeepAwakeActiveIcon: String, CaseIterable, Identifiable {
    case vorssaint, coffee, eye, moon, light

    var id: String { rawValue }

    static var current: KeepAwakeActiveIcon {
        Defaults.sanitizedKeepAwakeActiveIcon(
            UserDefaults.standard.string(forKey: DefaultsKey.keepAwakeActiveIcon)
        )
    }

    var systemSymbolName: String? {
        switch self {
        case .vorssaint: return nil
        case .coffee: return "cup.and.saucer.fill"
        case .eye: return "eye.fill"
        case .moon: return "moon.fill"
        case .light: return "lightbulb.fill"
        }
    }

    /// Nudge down the menu bar canvas, in points. Symbols carrying their mass
    /// above the shape's middle — steam over a cup, a bulb over its base — read
    /// as sitting high when their ink is centered geometrically.
    var menuBarDrop: CGFloat {
        switch self {
        case .coffee: return 1
        case .light: return 0.5
        case .vorssaint, .eye, .moon: return 0
        }
    }

    func title(_ strings: Strings) -> String {
        switch self {
        case .vorssaint: return strings.keepAwakeActiveIconVorssaint
        case .coffee: return strings.keepAwakeActiveIconCoffee
        case .eye: return strings.keepAwakeActiveIconEye
        case .moon: return strings.keepAwakeActiveIconMoon
        case .light: return strings.keepAwakeActiveIconLight
        }
    }
}

/// Thumbnail size for Dock Preview and, separately, the app switcher. Captures
/// scale by the same factor, so larger previews stay sharp.
enum PreviewSizing {
    static func sanitized(_ value: String) -> String {
        Defaults.allowedPreviewSizes.contains(value) ? value : "normal"
    }

    static func scale(for value: String) -> CGFloat {
        switch sanitized(value) {
        case "small": return 0.75
        case "large": return 1.4
        case "xlarge": return 1.8
        default: return 1.0
        }
    }

    static var scale: CGFloat {
        scale(for: UserDefaults.standard.string(forKey: DefaultsKey.previewSize) ?? "normal")
    }

    static var switcherScale: CGFloat {
        scale(for: UserDefaults.standard.string(forKey: DefaultsKey.switcherPreviewSize) ?? "normal")
    }
}

enum Defaults {
    static let finderBundleIdentifier = "com.apple.finder"
    /// Continuity / Calls on Mac. Quitting Phone when its UI flickers window-less
    /// during an incoming relay disconnects the call (issue #1534). Kept in the
    /// mandatory exception list even when Phone.app is absent; the settings UI
    /// hides the row until the app is installed.
    static let phoneBundleIdentifier = "com.apple.mobilephone"
    static let mandatoryAutoQuitExceptionBundleIDs = [
        finderBundleIdentifier,
        phoneBundleIdentifier,
    ]

    static let allowedDurations = [0, 15, 30, 60, 120, 240, 480]
    static let allowedKeepAwakeMouseJiggleIntervals = [1, 2, 5, 10, 15]
    static let allowedBatteryLimits = [0, 5, 10, 15, 20]
    static let allowedPreviewSizes = ["small", "normal", "large", "xlarge"]

    static let registeredDefaults: [String: Any] = [
        DefaultsKey.appearance: AppAppearance.fallback.rawValue,
        DefaultsKey.liquidGlassEnabled: false,
        DefaultsKey.clamshellPreferred: false,
        DefaultsKey.dimScreenOnLidClose: false,
        DefaultsKey.defaultDuration: 0,
        DefaultsKey.batteryLimit: 10,
        DefaultsKey.keepAwakeAutoStart: false,
        DefaultsKey.keepAwakeAllowDisplaySleep: false,
        DefaultsKey.keepAwakeExternalDisplay: false,
        DefaultsKey.keepAwakeConnectedToPower: false,
        DefaultsKey.keepAwakeRunningApps: false,
        DefaultsKey.keepAwakeRunningAppBundleIDs: [String](),
        DefaultsKey.keepAwakeAutomationRequireAll: false,
        DefaultsKey.keepAwakePauseWhenLocked: false,
        DefaultsKey.keepAwakeSwitchUsesUntil: false,
        DefaultsKey.keepAwakeUntilTime: 0.0,
        DefaultsKey.keepAwakeMouseJiggleEnabled: false,
        DefaultsKey.keepAwakeMouseJiggleInterval: 5,
        DefaultsKey.hotkeyEnabled: true,
        DefaultsKey.launchAtLoginWanted: false,
        DefaultsKey.keepAwakeShortcut: "control+option+command:40",
        DefaultsKey.switcherEnabled: true,
        DefaultsKey.switcherTakeOverSystemShortcuts: false,
        DefaultsKey.switcherShortcut: "command:48",
        DefaultsKey.switcherWindowShortcut: GlobalShortcut.switcherWindowDefault.storageValue,
        DefaultsKey.switcherAllWindowsShortcut: GlobalShortcut.switcherAllWindowsDefault.storageValue,
        DefaultsKey.switcherAllWindowsShortcutEnabled: false,
        DefaultsKey.switcherIconRowMode: false,
        DefaultsKey.switcherSimpleMode: false,
        DefaultsKey.switcherMergeTabs: false,
        DefaultsKey.switcherWindowlessApps: SwitcherWindowlessApps.fallback.rawValue,
        DefaultsKey.switcherMinimizedPlacement: WindowSwitchMinimizedPlacement.normal.rawValue,
        DefaultsKey.switcherTreatHiddenAppsLikeMinimized: true,
        DefaultsKey.switcherShowFullscreenWindows: true,
        DefaultsKey.switcherAppRules: [String: String](),
        DefaultsKey.switcherCurrentSpaceOnly: false,
        DefaultsKey.switcherSearchPinEnabled: false,
        DefaultsKey.switcherShowShortcutHints: true,
        DefaultsKey.switcherAppearanceDelay: SwitcherSupport.defaultAppearanceDelayMilliseconds,
        DefaultsKey.switcherInstantSelection: false,
        DefaultsKey.switcherScreenPlacement: SwitcherScreenPlacement.fallback.rawValue,
        DefaultsKey.switcherCurrentDisplayOnly: false,
        DefaultsKey.switcherMaxColumns: 0,
        DefaultsKey.minimalWindowPreviews: false,
        DefaultsKey.dockPreviewEnabled: false,
        DefaultsKey.dockPreviewCurrentSpaceOnly: false,
        DefaultsKey.dockPreviewKeepDockVisible: false,
        DefaultsKey.dockPreviewBackgroundOpacity: 1.0,
        DefaultsKey.dockPreviewOpenDelay: DockPreviewSupport.defaultOpenDelayMilliseconds,
        DefaultsKey.dockPreviewQuitAppOnClose: false,
        DefaultsKey.dockPreviewOrderByCreation: false,
        DefaultsKey.switcherPreviewSize: "normal",
        // The feature itself ships uninstalled. On first install both halves
        // work immediately; an explicit off choice is persisted and wins over
        // these registered defaults on later launches or reinstalls.
        // Finder never benefits from being "quit" (it just relaunches), so
        // it's excepted out of the box.
        DefaultsKey.autoQuitExceptions: mandatoryAutoQuitExceptionBundleIDs,
        DefaultsKey.autoQuitDockApps: [String](),
        // When the shelf is on, the shake gesture is on too (still toggleable).
        // On by default (owner's call): it costs nothing until the shelf itself
        // is on, and then the shelf lives handily under the menu bar icon.
        // New Shelf behavior stays opt-in for existing users.
        // Closing after a drop is new behavior, so it arrives OFF for people
        // who already rely on the panel staying put; removing after a drop
        // keeps the value shipped releases always had.
        DefaultsKey.urlCleanerEnabled: false,
        DefaultsKey.urlCleanerCustomParameters: "",
        DefaultsKey.urlCleanerSiteParameters: "",
        DefaultsKey.urlCleanerDisabledParameters: "",
        // The list itself costs nothing until it is opened; only the
        // background check keeps a timer, so it starts off.
        // Menu bar metrics start off (the icon stays clean) and are opt-in.
        // The panel shows every monitoring block by default; users hide what
        // they don't want.
        DefaultsKey.windowLayoutWindowGap: 0,
        DefaultsKey.windowLayoutScreenGap: 0,
        DefaultsKey.windowReserveStageManagerSpace: false,
        DefaultsKey.windowLayoutMarginPercent: 5.0,
        DefaultsKey.windowLayoutSideRepeatCyclesThirds: false,
        // Every per-item block shows by default; users hide what they don't want.
        DefaultsKey.windowLayoutIgnoredApps: [String](),
        DefaultsKey.finderCutPasteShowHUD: true,
        DefaultsKey.finderPasteImageAsFile: false,
        DefaultsKey.windowPreviewExcludedApps: [String](),
        DefaultsKey.switcherPreviewExcludedApps: [String](),
        DefaultsKey.screenOCRShortcutEnabled: false,
        DefaultsKey.screenOCRShortcut: GlobalShortcut.screenOCRDefault.storageValue,
        DefaultsKey.screenOCRRemoveLineBreaks: false,
        DefaultsKey.screenOCRDetectQRCodes: true,
        DefaultsKey.quickRingControlDoubleTap: true,
        // Off on a fresh install: each takes a click away from the apps.
        DefaultsKey.gsavClipboardHelperEnabled: true,
        DefaultsKey.recorderShortcutEnabled: false,
        DefaultsKey.recorderShortcut: GlobalShortcut.screenRecorderDefault.storageValue,
        DefaultsKey.recorderCountdown: 3,
        DefaultsKey.recorderQuality: RecorderSupport.Quality.balanced.rawValue,
        DefaultsKey.recorderFrameRate: 60,
        DefaultsKey.recorderSystemAudio: true,
        DefaultsKey.recorderMicrophone: false,
        DefaultsKey.recorderSaveFolder: "",
        DefaultsKey.recorderOpenEditor: true,
        DefaultsKey.recorderAutomaticZoom: true,
        DefaultsKey.recorderGIFSize: RecorderSupport.GIFSize.medium.rawValue,
        DefaultsKey.recorderGIFFrameRate: 12,
        DefaultsKey.recorderEditorPresets: Data(),
        DefaultsKey.recorderSharingEnabled: true,
        DefaultsKey.screenshotShowCaptureMenuOnShortcut: true,
        DefaultsKey.recorderShowCaptureMenuOnShortcut: true,
        DefaultsKey.screenOCRShowCaptureMenuOnShortcut: true,
        DefaultsKey.screenshotShortcutEnabled: false,
        DefaultsKey.screenshotShortcut: GlobalShortcut.screenshotDefault.storageValue,
        DefaultsKey.screenshotFullScreenShortcutEnabled: false,
        DefaultsKey.screenshotFullScreenShortcut: GlobalShortcut.screenshotFullScreenDefault.storageValue,
        DefaultsKey.screenshotLastCaptureShortcutEnabled: false,
        DefaultsKey.screenshotLastCaptureShortcut: GlobalShortcut.screenshotLastCaptureDefault.storageValue,
        DefaultsKey.recentCapturesShortcutEnabled: false,
        DefaultsKey.recentCapturesShortcut: GlobalShortcut.recentCapturesDefault.storageValue,
        DefaultsKey.screenshotClipboardShortcutEnabled: false,
        DefaultsKey.screenshotClipboardShortcut: GlobalShortcut.screenshotClipboardDefault.storageValue,
        DefaultsKey.screenshotFreeze: true,
        DefaultsKey.screenshotHideVorssaintWindows: true,
        DefaultsKey.screenshotSaveFolder: "",
        DefaultsKey.screenshotSaveSubfolder: "",
        DefaultsKey.screenshotFileNamePattern: "",
        DefaultsKey.screenshotFileNumberNext: 1,
        DefaultsKey.screenshotDefaultAction: "copy", // G’s Mac: a capture lands on the clipboard
        DefaultsKey.screenshotIncludePointer: false,
        DefaultsKey.screenshotShowLastRegion: true,
        DefaultsKey.screenshotHighlightWindows: true,
        DefaultsKey.screenshotLoupeStartsOn: false,
        DefaultsKey.screenshotLoupeRememberZoom: false,
        DefaultsKey.screenshotLoupeDefaultZoom: 1.0,
        DefaultsKey.screenshotLoupeLastZoom: 1.0,
        DefaultsKey.screenshotLoupeSteppedZoomByDefault: false,
        DefaultsKey.screenshotDownscale: false,
        DefaultsKey.screenshotDelay: 0,
        DefaultsKey.screenshotLastTool: "arrow",
        DefaultsKey.screenshotLastColor: "red",
        DefaultsKey.screenshotLastStroke: "medium",
        DefaultsKey.screenshotLastTextSize: ScreenshotSupport.defaultTextSize,
        DefaultsKey.screenshotLastBlurLevel: ScreenshotSupport.BlurStrength.defaultLevel,
        DefaultsKey.screenshotLastBlurStyle: "pixelate",
        DefaultsKey.screenshotLastBlurTextOnly: false,
        DefaultsKey.screenshotSpotlightDim: Double(ScreenshotSupport.defaultSpotlightDim),
        DefaultsKey.screenshotLastArrowStyle: "filled",
        DefaultsKey.screenshotLastSticker: "check",
        DefaultsKey.screenshotAnnotationShadows: false,
        DefaultsKey.screenshotToolOrder: ScreenshotSupport.Tool.defaultOrderStorage,
        DefaultsKey.screenshotToolShortcutsEnabled: true,
        DefaultsKey.screenshotToolShortcuts: "",
        DefaultsKey.screenshotBackdropStyle: "",
        DefaultsKey.screenshotBackdropPresets: "[]",
        DefaultsKey.screenshotWatermarkStyle: "",
        DefaultsKey.screenshotWatermarkPresets: "[]",
        DefaultsKey.screenshotCopyToClipboard: false,
        DefaultsKey.screenshotCopyImageOnly: false,
        DefaultsKey.screenshotPreviewPosition: ScreenshotSupport.QuickPreviewPosition.automatic.rawValue,
        DefaultsKey.screenshotPreviewTakesFocus: true,
        DefaultsKey.screenshotUploadShortcutEnabled: false,
        DefaultsKey.screenshotUploadShortcut: GlobalShortcut.screenshotUploadDefault.storageValue,
        DefaultsKey.screenshotUploadDuration: ScreenshotShareDuration.oneHour.rawValue,
        DefaultsKey.screenshotPreviewEnabled: true,
        DefaultsKey.screenshotPreviewDuration: ScreenshotSupport.defaultConfirmationPreviewDuration,
        DefaultsKey.screenshotSharingEnabled: true,
        DefaultsKey.windowLayoutShortcutsEnabled: false,
        DefaultsKey.windowEdgeSnapEnabled: false,
        DefaultsKey.windowEdgeSnapDisabledZones: "",
        DefaultsKey.windowEdgeSnapZoneActions: "",
        DefaultsKey.windowLayoutShortcutLeft: GlobalShortcut.windowLayoutLeftDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRight: GlobalShortcut.windowLayoutRightDefault.storageValue,
        DefaultsKey.windowLayoutShortcutTop: GlobalShortcut.windowLayoutTopDefault.storageValue,
        DefaultsKey.windowLayoutShortcutBottom: GlobalShortcut.windowLayoutBottomDefault.storageValue,
        DefaultsKey.windowLayoutShortcutCenterHalf: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutTopLeft: GlobalShortcut.windowLayoutTopLeftDefault.storageValue,
        DefaultsKey.windowLayoutShortcutTopRight: GlobalShortcut.windowLayoutTopRightDefault.storageValue,
        DefaultsKey.windowLayoutShortcutBottomLeft: GlobalShortcut.windowLayoutBottomLeftDefault.storageValue,
        DefaultsKey.windowLayoutShortcutBottomRight: GlobalShortcut.windowLayoutBottomRightDefault.storageValue,
        DefaultsKey.windowLayoutShortcutMaximize: GlobalShortcut.windowLayoutMaximizeDefault.storageValue,
        DefaultsKey.windowLayoutShortcutMarginMaximize: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutCenter: GlobalShortcut.windowLayoutCenterDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRestore: GlobalShortcut.windowLayoutRestoreDefault.storageValue,
        DefaultsKey.windowLayoutShortcutLeftThird: GlobalShortcut.windowLayoutLeftThirdDefault.storageValue,
        DefaultsKey.windowLayoutShortcutCenterThird: GlobalShortcut.windowLayoutCenterThirdDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRightThird: GlobalShortcut.windowLayoutRightThirdDefault.storageValue,
        DefaultsKey.windowLayoutShortcutLeftTwoThirds: GlobalShortcut.windowLayoutLeftTwoThirdsDefault.storageValue,
        DefaultsKey.windowLayoutShortcutRightTwoThirds: GlobalShortcut.windowLayoutRightTwoThirdsDefault.storageValue,
        DefaultsKey.windowLayoutShortcutCenterTwoThirds: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutTopThird: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutMiddleThird: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutBottomThird: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutTopTwoThirds: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutBottomTwoThirds: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutTopQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutUpperMiddleQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutLowerMiddleQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutBottomQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutLeftQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutLeftMiddleQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutRightMiddleQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutRightQuarter: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutPreviousDisplay: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutNextDisplay: GlobalShortcut.windowLayoutNextDisplayDefault.storageValue,
        DefaultsKey.windowLayoutShortcutTopLeftSixth: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutTopCenterSixth: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutTopRightSixth: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutBottomLeftSixth: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutBottomCenterSixth: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutBottomRightSixth: WindowLayoutAction.clearedShortcutStorageValue,
        DefaultsKey.windowLayoutShortcutFullScreen: WindowLayoutAction.clearedShortcutStorageValue,
    ]

    static func register() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: registeredDefaults)
        defaults.register(defaults: AppFeature.availabilityDefaults)
    }

    static func sanitizedDefaultDuration(_ minutes: Int) -> Int {
        allowedDurations.contains(minutes) ? minutes : 0
    }

    static func sanitizedBatteryLimit(_ percent: Int) -> Int {
        allowedBatteryLimits.contains(percent) ? percent : 10
    }

    static func sanitizedKeepAwakeMouseJiggleInterval(_ minutes: Int) -> Int {
        allowedKeepAwakeMouseJiggleIntervals.contains(minutes) ? minutes : 5
    }

    static func sanitizedKeepAwakeIconTint(_ rawValue: String?) -> KeepAwakeIconTint {
        guard let rawValue,
              let tint = KeepAwakeIconTint(rawValue: rawValue) else {
            return .orange
        }
        return tint
    }

    static func sanitizedKeepAwakeActiveIcon(_ rawValue: String?) -> KeepAwakeActiveIcon {
        guard let rawValue,
              let icon = KeepAwakeActiveIcon(rawValue: rawValue) else {
            return .vorssaint
        }
        return icon
    }

    static func sanitizedPercent(_ value: Int, fallback: Int, range: ClosedRange<Int>) -> Int {
        range.contains(value) ? value : fallback
    }

    static func sanitizedBundleIdentifierList(_ bundleIDs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in bundleIDs {
            let bundleID = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleID.isEmpty, !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)
            result.append(bundleID)
        }
        return result
    }

    static func sanitizedAutoQuitExceptions(_ bundleIDs: [String]) -> [String] {
        sanitizedBundleIdentifierList(mandatoryAutoQuitExceptionBundleIDs + bundleIDs)
    }

    static func sanitizedAutoQuitDockApps(_ bundleIDs: [String]) -> [String] {
        sanitizedBundleIdentifierList(bundleIDs).filter {
            !mandatoryAutoQuitExceptionBundleIDs.contains($0)
        }
    }

}
