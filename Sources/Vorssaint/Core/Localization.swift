// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The way a language agrees a noun with the number in front of it.
enum CountAgreement {
    /// One form for exactly one, another for every other count.
    case oneAndMany
    /// Russian and Ukrainian: the number's last digits decide. 21 takes the
    /// first form and 22 the middle one, while 11 through 14 fall back to the last.
    case byLastDigits
    /// Slovak: the whole number decides. Only one itself takes the first form
    /// and only two through four the middle one, so 21 and 22 read
    /// "21 súborov" and "22 súborov" the same way 25 does.
    case byWholeNumber
}

/// Languages the interface can use. The first launch defaults to the system
/// language; the onboarding and Settings let the user override it at any time.
enum AppLanguage: String, CaseIterable, Identifiable {
    case enUS = "en-US"
    case ptBR = "pt-BR"
    case tr = "tr"
    case ru = "ru"
    case es = "es"
    case sk = "sk"
    case de = "de"
    case fr = "fr"
    case it = "it"
    case ja = "ja"
    case ko = "ko"
    case uk = "uk"
    case zhHans = "zh-Hans"
    case zhTW = "zh-TW"
    case zhHK = "zh-HK"

    var id: String { rawValue }

    /// How this language agrees a counted noun with the number in front of
    /// it. Three of the fifteen put a distinct form between one and many, and
    /// they disagree on which numbers take it, so the count itself is not
    /// enough to pick a form without knowing the language's rule.
    var countAgreement: CountAgreement {
        switch self {
        case .ru, .uk: return .byLastDigits
        case .sk: return .byWholeNumber
        default: return .oneAndMany
        }
    }

    /// The language's own name, shown in its own script, the way macOS lists them.
    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .ptBR: return "Português (Brasil)"
        case .tr: return "Türkçe"
        case .ru: return "Русский"
        case .es: return "Español"
        case .sk: return "Slovenčina"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        case .zhHK: return "繁體中文（香港）"
        case .zhTW: return "繁體中文（台灣）"
        case .uk: return "Українська"
        }
    }

    /// Dates and times in this language, arranged the way System Settings
    /// asks: region, 12- or 24-hour clock and first day of the week. A locale
    /// made from the language alone would bring that language's own clock.
    func formattingLocale(system: Locale = .autoupdatingCurrent) -> Locale {
        var components = Locale.Components(identifier: rawValue)
        components.region = system.region
        components.hourCycle = system.hourCycle
        components.firstDayOfWeek = system.firstDayOfWeek
        return Locale(components: components)
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let p = preferred.lowercased()

        if p.hasPrefix("zh-hk") || p.hasPrefix("zh-hant-hk") {
            return .zhHK
        }

        if p.hasPrefix("zh-tw") || p.hasPrefix("zh-hant-tw") || p.hasPrefix("zh-hant") {
            return .zhTW
        }

        let matches: [(String, AppLanguage)] = [
            ("pt", .ptBR), ("tr", .tr), ("ru", .ru), ("es", .es), ("sk", .sk), ("de", .de),
            ("fr", .fr), ("it", .it), ("ja", .ja), ("ko", .ko), ("uk", .uk), ("zh", .zhHans),
        ]
        for (prefix, language) in matches where preferred.hasPrefix(prefix) { return language }
        return .enUS
    }
}

/// Source of every user-facing string. Views observe this object so the whole
/// interface re-renders immediately when the language changes.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: DefaultsKey.language) }
    }

    var s: Strings { Strings.localized(language) }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.language),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .systemDefault
        }
    }
}

extension Strings {
    /// The catalog for a language other than the current one, as the
    /// feature string tables offer theirs.
    static func localized(_ language: AppLanguage) -> Strings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhHK: return .zhHK
        case .zhTW: return .zhTW
        case .uk: return .uk
        }
    }
}

/// Flat, compiler-checked catalog of UI strings. Adding a field here forces
/// both translations to be provided.
struct Strings {
    // MARK: Menu bar & context menu
    let menuAbout: String
    let menuQuit: String
    // Standard application menu bar (App / Edit / Window) shown while one of the
    // app's own windows is focused. Without it, an accessory app has no main menu
    // and the standard shortcuts (Cmd+H/M/W/Q, Cmd+C/V/X/A) do nothing.
    let menuHide: String
    let menuEdit: String
    let menuUndo: String
    let menuRedo: String
    /// Named actions an icon-only control borrows so it can say what it
    /// does. No feature owns these, because half a dozen already share them.
    let menuCut: String
    let menuCopy: String
    let menuPaste: String
    let menuSelectAll: String
    let menuWindow: String
    let menuMinimize: String
    let menuClose: String

    // MARK: Durations

    // MARK: Panel — header & footer
    let panelQuit: String

    // MARK: Panel — keep awake card
    let keepAwakeTitle: String
    let keepAwakeMouseJiggleInterval: String
    let keepAwakeActiveIconVorssaint: String
    let keepAwakeActiveIconCoffee: String
    let keepAwakeActiveIconEye: String
    let keepAwakeActiveIconMoon: String
    let keepAwakeActiveIconLight: String
    let keepAwakeIconTintOrange: String
    let keepAwakeIconTintGreen: String
    let keepAwakeIconTintBlue: String
    let keepAwakeIconTintPurple: String
    let keepAwakeIconTintPink: String
    let keepAwakeIconTintNone: String
    let clamshellNeedsPassword: String

    // MARK: Panel — system monitor
    let memoryCompressed: String
    let memoryCachedFiles: String

    // MARK: Notifications

    // MARK: Administrator prompts (shown by macOS password dialogs)
    let adminPromptClamshellOff: String
    let adminPromptRecover: String
    let adminPromptSudoersInstall: String
    let adminPromptSudoersRemove: String

    // MARK: Settings — window & tabs
    let settingsTitle: String
    let minimalWindowPreviews: String
    let minimalWindowPreviewsCaption: String

    // MARK: Settings — advanced

    // MARK: Settings — general
    let launchAtLogin: String
    let languageLabel: String
    let showCountdown: String

    // MARK: Settings — energy
    let keepAwakeAutoStart: String
    let dimScreenOnLidCloseTitle: String

    // MARK: Settings — mouse
    let smoothScrollStepLabel: String
    let quickToolsTab: String
    let ocrName: String
    let ocrCaption: String
    let ocrCopied: String
    let ocrNoText: String
    let micMuteCaption: String
    let micMutedHUD: String
    let micUnmutedHUD: String
    let launcherName: String

    // MARK: Settings — switcher
    let switcherSection: String
    let switcherNoWindows: String
    let switcherIconRowMode: String
    let switcherIconRowModeCaption: String
    let switcherSimpleModeCaption: String
    let switcherShortcutHintApps: String
    let switcherShortcutHintWindows: String
    let switcherTakeOverSystemShortcuts: String
    let switcherAppearanceDelay: String
    let switcherAppearanceDelayCaption: String
    let switcherMaxColumns: String
    let switcherMaxColumnsCaption: String
    let switcherMaxColumnsAuto: String
    let switcherInstantSelection: String
    let switcherMergeTabs: String
    let switcherWindowlessApps: String
    let switcherWindowlessAppsCaption: String
    let switcherWindowlessAppsOff: String
    let switcherWindowlessAppsFinder: String
    let switcherWindowlessAppsAll: String
    let switcherWindowlessAppsLockedFormat: String
    let switcherNoOpenWindow: String
    let switcherOtherDesktop: String
    let dockPreviewCurrentSpaceOnlyCaption: String
    let dockPreviewBackgroundOpacity: String
    let dockPreviewBackgroundOpacityCaption: String
    let dockPreviewBackgroundOpacityGlassCaption: String
    let dockPreviewOpenDelay: String
    let dockPreviewOpenDelayCaption: String
    let dockPreviewQuitAppOnClose: String
    let dockPreviewQuitAppOnCloseCaption: String
    let dockPreviewKeepDockVisible: String
    let dockPreviewOrderByCreation: String
    let dockPreviewOpenWindow: String
    let dockPreviewCloseWindow: String
    let dockPreviewMinimizeWindow: String
    let dockPreviewRestoreWindow: String
    let dockPreviewPinPanel: String
    let dockPreviewUnpinPanel: String
    let dockPreviewPinned: String
    let dockPreviewClosePanel: String
    let dockPreviewPreviousWindow: String
    let dockPreviewNextWindow: String

    // MARK: Feature — cut & paste in Finder
    let cutReadyTitle: String
    let cutReadyHint: String
    let cutCancel: String
    let cutDoneTitle: String
    let cutMovedSingular: String
    let cutMovedPluralFormat: String      // + count
    let cutSomeFailed: String
    let cutMovingTitle: String
    let cutMovingCountFormat: String      // + position, total

    // MARK: Feature — quit on last window close

    // MARK: Feature — complete app uninstaller
    let uninstallerSelectedFormat: String   // + selected, total
    let uninstallerCancel: String
    let uninstallerFreedFormat: String      // + size string
    let uninstallerRefusedNotApp: String
    let uninstallerRefusedSystemFormat: String        // + app name
    let uninstallerRefusedSharedFormat: String        // + app name
    let uninstallerRefusedNestedFormat: String        // + app name
    let uninstallerRefusedSelfFormat: String          // + Advanced tab name
    let uninstallerRefusedLinkFormat: String          // + app name
    let uninstallerRefusedUnidentifiedFormat: String  // + app name
    let uninstallerPickerHiddenNote: String

    // MARK: Feature — URL cleaner

    // MARK: Feature — Homebrew manager
    let homebrewGroupDependencies: String
    let homebrewUpgradeAll: String
    let homebrewUpdateHomebrew: String
    let homebrewPopularityFormat: String
    let homebrewConfirmInstallBodyFormat: String
    let homebrewConfirmUninstallBodyFormat: String
    let homebrewConfirmUpgradeBodyFormat: String
    let homebrewConfirmUpgradeAllTitle: String
    let homebrewConfirmUpgradeAllBody: String
    let homebrewConfirmUpdateHomebrewTitle: String
    let homebrewConfirmUpdateHomebrewBody: String
    let homebrewOperationInstallFormat: String
    let homebrewOperationUninstallFormat: String
    let homebrewOperationUpgradeFormat: String
    let homebrewOperationUpgradeAll: String
    let homebrewOperationUpdateHomebrew: String
    let homebrewOperationInstalledFormat: String
    let homebrewOperationUninstalledFormat: String
    let homebrewOperationUpgradedFormat: String
    let homebrewOperationUpgradedAll: String
    let homebrewOperationUpdatedHomebrew: String
    let homebrewOperationFailedFormat: String
    let homebrewOperationPreparing: String
    let homebrewOperationDownloading: String
    let homebrewOperationInstalling: String
    let homebrewOperationUninstalling: String
    let homebrewOperationUpgrading: String
    let homebrewOperationFinalizing: String
    let homebrewOperationRefreshing: String
    let homebrewOperationElapsedFormat: String

    // MARK: Feature — local media tools
    let mediaCancelled: String

    // MARK: Feature — temporary shelf
    let shelfSelectedFormat: String      // + count
    // Three forms, not two: Russian and Ukrainian agree a noun with the number
    // in front of it as one, as two through four, and as five or more. Every other
    // language here needs only the first and the last, and repeats the last
    // in the middle slot. A pile always holds two or more, so the items count
    // has no singular of its own.

    // MARK: Panel — per-app breakdown

    // MARK: Panel — volume mixer
    let mixerInputErrorFormat: String

    // MARK: Panel — audio device priority

    // MARK: Settings — updates

    // MARK: Permissions (shared by Settings & onboarding)
    let permissionRequest: String

    // MARK: Secure input
    let secureInputTitle: String
    let secureInputHeldFormat: String
    let secureInputUnattributed: String
    let secureInputUnidentified: String
    let secureInputRevealFormat: String
    // The switcher page's captions: there secure input costs the switcher its
    // keys rather than typing, and ⌘Tab reaches the macOS switcher until it ends.
    let secureInputSwitcherHeldFormat: String
    let secureInputSwitcherUnattributed: String
    let secureInputSwitcherUnidentified: String

    // MARK: About
    let aboutDescription: String
    let reviewIntro: String

    // MARK: Onboarding

    // MARK: Settings — monitor / menu bar metrics

    // MARK: Panel — network
    let networkApps: String
    let networkAppsIdle: String

    // MARK: Panel — disk
    let diskMenuBarStyleLabel: String
    let diskMenuBarUsedPercentage: String
    let diskMenuBarAvailableSpace: String
    let diskMenuBarUsedSpace: String
    let diskAvailable: String
    let diskPurgeable: String

    // MARK: Panel — power
    let powerAdapterMaxFormat: String   // + rated watts, e.g. "30 W max"

    // MARK: Update notification + onboarding menu bar setup
    // MARK: System uptime, battery health, speed test
    let systemUptime: String

    // MARK: Per-item panel config (Settings + onboarding)
    let disclosureExpanded: String
    let disclosureCollapsed: String
    let panelHiddenItem: String

    // MARK: Cleaning mode
    let cleaningPanelCaption: String
    let cleaningOverlayTitle: String
    let cleaningOverlaySubtitle: String
    let cleaningOverlayUnlock: String
    let cleaningOverlayMouseHint: String
    let cleaningKeepScreenVisibleToggle: String
    let cleaningKeepScreenVisibleCaption: String
    let cleaningStartNow: String

    // MARK: Support / donate
    let donateHeading: String
    let donateMessage: String
    let donateButton: String
    let supportIntroTitle: String
    let supportIntroMessage: String
    let supportIntroStarButton: String
    let supportIntroStarMessage: String
    /// A quiet line under the donation button inviting a GitHub star instead.
    let supportIntroCoffeeButton: String
    let supportIntroDoneButton: String
    let discordIntroTitle: String
    let discordIntroMessage: String
    let discordIntroJoinButton: String
    let communityIntroTitle: String
    let communityIntroMessage: String
    let communityIntroFollowButton: String
    let homebrewOfficialIntroTitle: String
    let homebrewOfficialIntroMessage: String
    let homebrewOfficialIntroInstallLabel: String
    let homebrewOfficialIntroMigrationTitle: String
    let homebrewOfficialIntroMigrationMessage: String
    let homebrewOfficialIntroCopyButton: String
    let updateShowcaseTitle: String
    let updateShowcaseMessage: String
    let updateShowcaseUnavailable: String
    let updateShowcaseRestart: String

    // MARK: Configurable shortcuts
    let shortcutRecording: String
    let shortcutReset: String
    let shortcutNone: String
    let shortcutInvalid: String
    let shortcutPressKeys: String
    let shortcutEscapeHint: String
    let shortcutDeleteHint: String
    let shortcutNotCaptured: String
    let shortcutConflictFormat: String
    let shortcutTakeOverOffer: String
    let shortcutTakeOverAction: String
    let shortcutTakeOverCaption: String
    let shortcutTakeOverDismiss: String

    // MARK: Media keys

    // MARK: Cleaner
    let cleanerRevealInFinder: String
    let launchAtLoginNeedsApplications: String
    let launchAtLoginNeedsApproval: String
    let ocrRemoveLineBreaksToggle: String
    let ocrRemoveLineBreaksCaption: String
    let ocrQRToggle: String
    let ocrQRCaption: String
    let ocrQRCopied: String
    let qrResultTitle: String
    let qrResultCopy: String
    let qrResultOpen: String
    let highlightsTitleClipboardRedesign: String
    let highlightsCaptionDockPreview: String
    let highlightsCaptionScreenshot: String
    let highlightsCaptionSnippetLibrary: String
    let highlightsCaptionCapturePalette: String
    let highlightsCaptionClipboardRedesign: String
    let highlightsConfigure: String
    let highlightsTry: String
    let highlightsSeeAll: String
    let switcherCurrentSpaceOnly: String
    let switcherCurrentSpaceOnlyCaption: String
    let mixerSoundEffectsOutputTitle: String
    let mixerSoundEffectsOutputTooltip: String
    let monitorOpenActivityMonitor: String
    let dockClickHide: String
    let dockClickHideCaption: String
    let keepAwakeRightClickToggle: String
    let keepAwakeRightClickToggleCaption: String
    let switcherSearchPin: String
    let switcherSearchPinCaption: String
    let zoomControlNote: String
    let switcherShowShortcutHints: String
    let switcherShowShortcutHintsCaption: String
    let switcherMinimizedPlacementLabel: String
    let switcherTreatHiddenAppsLikeMinimized: String
    let switcherShowFullscreenWindows: String
    let switcherScreenPlacementLabel: String
    let switcherScreenPlacementPointer: String
    let switcherScreenPlacementMenuBar: String
    let switcherScreenPlacementActiveWindow: String
    let switcherScreenPlacementCaption: String
    let switcherCurrentDisplayOnly: String
    let switcherCurrentDisplayOnlyCaption: String
    let smoothScrollResponseLabel: String
    let smoothScrollCoastLabel: String
    let shelfClearOnClose: String
    let shelfClearOnCloseCaption: String
}

// MARK: - Português (Brasil)

extension Strings {
    static let ptBR = Strings(
        menuAbout: "Sobre o G’s Mac",
        menuQuit: "Sair do G’s Mac",
        menuHide: "Ocultar o G’s Mac",
        menuEdit: "Editar",
        menuUndo: "Desfazer",
        menuRedo: "Refazer",
        menuCut: "Recortar",
        menuCopy: "Copiar",
        menuPaste: "Colar",
        menuSelectAll: "Selecionar Tudo",
        menuWindow: "Janela",
        menuMinimize: "Minimizar",
        menuClose: "Fechar",

        panelQuit: "Sair",

        keepAwakeTitle: "Manter acordado",
        keepAwakeMouseJiggleInterval: "Intervalo",
        keepAwakeActiveIconVorssaint: "G’s Mac",
        keepAwakeActiveIconCoffee: "Café",
        keepAwakeActiveIconEye: "Olho",
        keepAwakeActiveIconMoon: "Lua",
        keepAwakeActiveIconLight: "Lâmpada",
        keepAwakeIconTintOrange: "Laranja",
        keepAwakeIconTintGreen: "Verde",
        keepAwakeIconTintBlue: "Azul",
        keepAwakeIconTintPurple: "Roxo",
        keepAwakeIconTintPink: "Rosa",
        keepAwakeIconTintNone: "Sem cor",
        clamshellNeedsPassword: "Pedirá a senha de administrador uma vez",

        memoryCompressed: "Comprimida",
        memoryCachedFiles: "Arquivos em cache",

        adminPromptClamshellOff: "O G’s Mac precisa da sua senha para reativar a suspensão normal do Mac.",
        adminPromptRecover: "O G’s Mac foi encerrado com a suspensão do Mac desativada. Digite a senha para restaurar a suspensão normal.",
        adminPromptSudoersInstall: "O G’s Mac vai criar uma regra restrita (somente pmset disablesleep) para alternar a tampa fechada sem pedir senha. Esta é a única vez que a senha será necessária.",
        adminPromptSudoersRemove: "O G’s Mac vai remover a regra de tampa fechada sem senha.",

        settingsTitle: "Ajustes do G’s Mac",
        minimalWindowPreviews: "Prévias minimalistas",
        minimalWindowPreviewsCaption: "Oculta títulos, botões e detalhes decorativos nas prévias do Dock e do alternador. A seleção continua visível.",

        launchAtLogin: "Iniciar junto com o Mac",
        languageLabel: "Idioma",
        showCountdown: "Mostrar tempo restante ao lado do ícone",

        keepAwakeAutoStart: "Manter acordado ao abrir o G’s Mac",
        dimScreenOnLidCloseTitle: "Escurecer a tela completamente",

        smoothScrollStepLabel: "Velocidade da rolagem",
        quickToolsTab: "Painel rápido",
        ocrName: "Copiar texto da tela",
        ocrCaption: "Selecione uma área da tela e o texto reconhecido é copiado, pronto para colar.",
        ocrCopied: "Texto copiado",
        ocrNoText: "Nenhum texto encontrado",
        micMuteCaption: "Usa os controles de silenciamento ou volume de entrada de cada microfone. A Siri e alguns apps ainda podem ouvir você. Não bloqueia todo acesso ao microfone.",
        micMutedHUD: "Silenciamento ativado",
        micUnmutedHUD: "Silenciamento desativado",
        launcherName: "Painel rápido",

        switcherSection: "Alternador de janelas",
        switcherNoWindows: "Nenhuma janela aberta",
        switcherIconRowMode: "Mostrar %@ com ícones grandes",
        switcherIconRowModeCaption: "Mostra um ícone por app com os previews das janelas do app acima.",
        switcherSimpleModeCaption: "Mostra ícones de apps e títulos das janelas, sem previews nem captura da tela pelo alternador.",
        switcherShortcutHintApps: "Apps",
        switcherShortcutHintWindows: "Janelas",
        switcherTakeOverSystemShortcuts: "Substituir ⌘Tab e ⌘` do macOS",
        switcherAppearanceDelay: "Atraso de exibição",
        switcherAppearanceDelayCaption: "Quanto tempo o atalho precisa ficar pressionado antes de o alternador aparecer.",
        switcherMaxColumns: "Máximo de colunas",
        switcherMaxColumnsCaption: "Quebra para mais linhas depois desse número de itens. Útil em monitores ultrawide.",
        switcherMaxColumnsAuto: "Automático",
        switcherInstantSelection: "Seleção instantânea",
        switcherMergeTabs: "Mostrar uma entrada por app",
        switcherWindowlessApps: "Apps sem janela aberta",
        switcherWindowlessAppsCaption: "Escolhe quais apps que estão abertos sem nenhuma janela aparecem no alternador.",
        switcherWindowlessAppsOff: "Não mostrar",
        switcherWindowlessAppsFinder: "Só o Finder",
        switcherWindowlessAppsAll: "Todos os apps",
        switcherWindowlessAppsLockedFormat: "Todos os apps abertos continuam acessíveis enquanto “%@” estiver ativado. Desative para escolher.",
        switcherNoOpenWindow: "Sem janela aberta",
        switcherOtherDesktop: "Outra Mesa",
        dockPreviewCurrentSpaceOnlyCaption: "Quando desligado, mostra janelas de todas as mesas. Escolher uma janela em outra mesa leva você até ela.",
        dockPreviewBackgroundOpacity: "Fundo do painel",
        dockPreviewBackgroundOpacityCaption: "Diminua para ver mais do que está atrás do painel.",
        dockPreviewBackgroundOpacityGlassCaption: "Com o Liquid Glass ligado, a transparência do painel é definida em Ajustes do Sistema > Aparência.",
        dockPreviewOpenDelay: "Atraso de abertura",
        dockPreviewOpenDelayCaption: "Quanto tempo o ponteiro precisa ficar sobre um ícone antes de o painel abrir.",
        dockPreviewQuitAppOnClose: "Encerrar o app com o botão ×",
        dockPreviewQuitAppOnCloseCaption: "No Dock Preview, × encerra o app inteiro em vez de fechar apenas aquela janela.",
        dockPreviewKeepDockVisible: "Manter Dock visível (experimental)",
        dockPreviewOrderByCreation: "Ordenar janelas por criação",
        dockPreviewOpenWindow: "Abrir janela",
        dockPreviewCloseWindow: "Fechar janela",
        dockPreviewMinimizeWindow: "Minimizar janela",
        dockPreviewRestoreWindow: "Restaurar janela",
        dockPreviewPinPanel: "Fixar prévia",
        dockPreviewUnpinPanel: "Desfixar prévia",
        dockPreviewPinned: "Fixado",
        dockPreviewClosePanel: "Fechar prévia",
        dockPreviewPreviousWindow: "Janela anterior",
        dockPreviewNextWindow: "Próxima janela",

        cutReadyTitle: "Recortado",
        cutReadyHint: "na pasta de destino para mover",
        cutCancel: "Cancelar recorte",
        cutDoneTitle: "Movido!",
        cutMovedSingular: "1 item movido",
        cutMovedPluralFormat: "%d itens movidos",
        cutSomeFailed: "Alguns itens não puderam ser movidos",
        cutMovingTitle: "Movendo…",
        cutMovingCountFormat: "%d de %d",

        uninstallerSelectedFormat: "%d de %d selecionados",
        uninstallerCancel: "Cancelar",
        uninstallerFreedFormat: "%@ removidos",
        uninstallerRefusedNotApp: "Só é possível desinstalar apps.",
        uninstallerRefusedSystemFormat: "%@ não pode ser desinstalado porque faz parte do macOS.",
        uninstallerRefusedSharedFormat: "%@ não pode ser desinstalado aqui porque compartilha arquivos com o macOS ou com outros apps.",
        uninstallerRefusedNestedFormat: "%@ não pode ser desinstalado sozinho porque faz parte de outro app.",
        uninstallerRefusedSelfFormat: "O G’s Mac não pode se desinstalar por aqui. Use Ajustes › %@.",
        uninstallerRefusedLinkFormat: "%@ não pode ser desinstalado porque é um link para um app guardado em outro lugar.",
        uninstallerRefusedUnidentifiedFormat: "%@ não pode ser desinstalado porque não foi possível identificá-lo como app.",
        uninstallerPickerHiddenNote: "Apps que fazem parte do macOS ou são da Apple não aparecem na lista.",

        homebrewGroupDependencies: "Agrupar dependências",
        homebrewUpgradeAll: "Atualizar tudo",
        homebrewUpdateHomebrew: "Atualizar Homebrew",
        homebrewPopularityFormat: "%@ instalações em %@ dias",
        homebrewConfirmInstallBodyFormat: "O Homebrew vai baixar e instalar %@. Dependências também podem ser instaladas.",
        homebrewConfirmUninstallBodyFormat: "O Homebrew vai desinstalar %@. Arquivos de configuração podem permanecer no sistema.",
        homebrewConfirmUpgradeBodyFormat: "O Homebrew vai baixar e aplicar a versão mais recente de %@. Dependências também podem ser atualizadas.",
        homebrewConfirmUpgradeAllTitle: "Atualizar todos pelo Homebrew?",
        homebrewConfirmUpgradeAllBody: "O Homebrew vai baixar e aplicar as versões mais recentes dos pacotes com atualização disponível. Dependências também podem ser atualizadas.",
        homebrewConfirmUpdateHomebrewTitle: "Atualizar Homebrew?",
        homebrewConfirmUpdateHomebrewBody: "O Homebrew vai buscar as informações mais recentes e depois recarregar seus pacotes.",
        homebrewOperationInstallFormat: "Instalando %@",
        homebrewOperationUninstallFormat: "Desinstalando %@",
        homebrewOperationUpgradeFormat: "Atualizando %@",
        homebrewOperationUpgradeAll: "Atualizando pacotes",
        homebrewOperationUpdateHomebrew: "Atualizando Homebrew",
        homebrewOperationInstalledFormat: "%@ instalado.",
        homebrewOperationUninstalledFormat: "%@ desinstalado.",
        homebrewOperationUpgradedFormat: "%@ atualizado.",
        homebrewOperationUpgradedAll: "Pacotes atualizados.",
        homebrewOperationUpdatedHomebrew: "Homebrew atualizado.",
        homebrewOperationFailedFormat: "Não foi possível concluir %@.",
        homebrewOperationPreparing: "Preparando…",
        homebrewOperationDownloading: "Baixando arquivos…",
        homebrewOperationInstalling: "Instalando arquivos…",
        homebrewOperationUninstalling: "Removendo arquivos…",
        homebrewOperationUpgrading: "Atualizando arquivos…",
        homebrewOperationFinalizing: "Finalizando…",
        homebrewOperationRefreshing: "Atualizando lista…",
        homebrewOperationElapsedFormat: "%@ decorridos",

        mediaCancelled: "Cancelado.",

        shelfSelectedFormat: "%d selecionados",

        mixerInputErrorFormat: "Não foi possível trocar: %@",

        permissionRequest: "Conceder acesso",
        secureInputTitle: "A entrada segura está ativa",
        secureInputHeldFormat: "%@ era o app em primeiro plano quando ela foi ligada e pode estar mantendo-a ativa, então o G’s Mac não consegue digitar por você. Saia do campo de senha do app, ou encerre-o, para liberá-la.",
        secureInputUnattributed: "Não é possível dizer qual app a está mantendo ativa, então o G’s Mac não consegue digitar por você. Saia de qualquer campo de senha aberto, ou encerre a sessão e entre novamente, para limpá-la.",
        secureInputUnidentified: "Não foi possível identificar o app que a está mantendo ativa, então o G’s Mac não consegue digitar por você.",
        secureInputRevealFormat: "Mostrar %@",
        secureInputSwitcherHeldFormat: "%@ era o app em primeiro plano quando ela foi ligada e pode estar mantendo-a ativa. Até ela ser desativada, o macOS esconde do alternador as teclas que você pressiona e o ⌘Tab abre o alternador do macOS. Saia do campo de senha do app, ou encerre-o, para liberá-la.",
        secureInputSwitcherUnattributed: "Não é possível dizer qual app a está mantendo ativa. Até ela ser desativada, o macOS esconde do alternador as teclas que você pressiona e o ⌘Tab abre o alternador do macOS. Saia de qualquer campo de senha aberto, ou encerre a sessão e entre novamente, para limpá-la.",
        secureInputSwitcherUnidentified: "Não foi possível identificar o app que a está mantendo ativa. Até ela ser desativada, o macOS esconde do alternador as teclas que você pressiona e o ⌘Tab abre o alternador do macOS.",

        aboutDescription: "Central de utilidades para o seu Mac.\nEnergia, monitor do sistema, rolagem e alternador de janelas, direto na barra de menus.",
        reviewIntro: "Rever introdução",

        networkApps: "Apps usando rede",
        networkAppsIdle: "Nenhum app usando rede agora",

        diskMenuBarStyleLabel: "Exibição do disco",
        diskMenuBarUsedPercentage: "Porcentagem usada",
        diskMenuBarAvailableSpace: "Espaço disponível",
        diskMenuBarUsedSpace: "Espaço usado",
        diskAvailable: "disponível",
        diskPurgeable: "purgável",

        powerAdapterMaxFormat: "%@ máx.",

        systemUptime: "Ativo há",

        disclosureExpanded: "Expandido",
        disclosureCollapsed: "Recolhido",
        panelHiddenItem: "Oculto",

        cleaningPanelCaption: "Bloqueia o teclado para limpar com segurança.",
        cleaningOverlayTitle: "Teclado bloqueado para limpeza",
        cleaningOverlaySubtitle: "Pressione Esc 5 vezes para desbloquear",
        cleaningOverlayUnlock: "Desbloquear",
        cleaningOverlayMouseHint: "O mouse e o trackpad continuam funcionando",
        cleaningKeepScreenVisibleToggle: "Manter a tela visível",
        cleaningKeepScreenVisibleCaption: "Exibe um indicador discreto no canto da tela em vez de escurecer o conteúdo.",
        cleaningStartNow: "Bloquear teclado agora",

        donateHeading: "Ajude o G’s Mac a continuar crescendo",
        donateMessage: "O G’s Mac continua de graça, local e sem anúncios ou coleta de dados de uso. Se ele te ajuda, o Buy Me a Coffee é a única forma de apoiar seu desenvolvimento financeiramente.",
        donateButton: "Apoiar no Buy Me a Coffee",
        supportIntroTitle: "Ajude o G’s Mac a continuar crescendo",
        supportIntroMessage: "O G’s Mac continua de graça, local e sem anúncios ou coleta de dados de uso. Se ele te ajuda, o Buy Me a Coffee é a única forma de apoiar seu desenvolvimento financeiramente.",
        supportIntroStarButton: "Dar uma estrela no GitHub",
        supportIntroStarMessage: "Apoio financeiro nunca é esperado. Dar uma estrela no GitHub ajuda mais pessoas a encontrar o G’s Mac e faz uma diferença enorme no desenvolvimento.",
        supportIntroCoffeeButton: "Apoiar no Buy Me a Coffee",
        supportIntroDoneButton: "Concluir",
        discordIntroTitle: "A comunidade do G’s Mac no Discord está começando",
        discordIntroMessage: "A comunidade do G’s Mac é nova e ainda está em desenvolvimento. Entre desde o começo para conhecer outros usuários e ajudar a construir um espaço acolhedor em torno do app.",
        discordIntroJoinButton: "Entrar na comunidade no Discord",
        communityIntroTitle: "Vem ver antes de todo mundo",
        communityIntroMessage: "Quem já me seguia no X viu várias novidades desta atualização antes de todo mundo. Lá eu posto prévias do que vem depois e mostro como funciona, para você já saber o básico antes mesmo da atualização sair. Segue lá e veja o que vem depois!",
        communityIntroFollowButton: "Seguir @vorssaint no X",
        homebrewOfficialIntroTitle: "Agora no catálogo oficial do Homebrew",
        homebrewOfficialIntroMessage: "O G’s Mac agora pode ser instalado direto do catálogo oficial do Homebrew.",
        homebrewOfficialIntroInstallLabel: "Nova instalação",
        homebrewOfficialIntroMigrationTitle: "Usava o tap antigo?",
        homebrewOfficialIntroMigrationMessage: "Remova o tap uma vez. O app e seus ajustes continuam no lugar.",
        homebrewOfficialIntroCopyButton: "Copiar comando",
        updateShowcaseTitle: "Novidades da 3.1.4",
        updateShowcaseMessage: "Veja uma prévia rápida das principais melhorias desta atualização.",
        updateShowcaseUnavailable: "Não foi possível carregar o vídeo agora. Você ainda pode continuar.",
        updateShowcaseRestart: "Voltar ao início",
        shortcutRecording: "Pressione o novo atalho",
        shortcutReset: "Redefinir",
        shortcutNone: "Nenhum",
        shortcutInvalid: "Use pelo menos Control, Option ou Command junto com uma tecla.",
        shortcutPressKeys: "Pressione",
        shortcutEscapeHint: "Esc cancela.",
        shortcutDeleteHint: "Delete remove.",
        shortcutNotCaptured: "Nada foi capturado. O macOS ou outro app já usa essa combinação. Tente outra.",
        shortcutConflictFormat: "Este atalho já está em uso por %@.",
        shortcutTakeOverOffer: "O macOS usa %@ em um atalho próprio.",
        shortcutTakeOverAction: "Assumir enquanto o G’s Mac estiver aberto",
        shortcutTakeOverCaption: "O macOS recupera a tecla sempre que o G’s Mac não estiver aberto ou este recurso estiver desligado.",
        shortcutTakeOverDismiss: "Não assumir",
        cleanerRevealInFinder: "Mostrar no Finder",
        launchAtLoginNeedsApplications: "O app está rodando de um lugar que não permite abrir no login. Arraste o G’s Mac para a pasta Aplicativos, abra de lá e ligue de novo.",
        launchAtLoginNeedsApproval: "O item de login está registrado, mas o macOS ainda precisa da sua aprovação. Nos Ajustes do Sistema, permita que o G’s Mac abra no login e funcione em segundo plano.",
        ocrRemoveLineBreaksToggle: "Remover quebras de linha",
        ocrRemoveLineBreaksCaption: "Remove as quebras de linha para que o texto copiado seja colado como um único parágrafo.",
        ocrQRToggle: "Ler QR codes",
        ocrQRCaption: "Se a área tiver um QR code, o conteúdo dele aparece para copiar ou abrir.",
        ocrQRCopied: "QR code copiado",
        qrResultTitle: "QR code",
        qrResultCopy: "Copiar",
        qrResultOpen: "Abrir link",
        highlightsTitleClipboardRedesign: "Novo visual da área de transferência",
        highlightsCaptionDockPreview: "O Dock Preview agora funciona com a ampliação do Dock ligada",
        highlightsCaptionScreenshot: "A captura de tela ganhou uma lupa de pixels e leitura de QR codes",
        highlightsCaptionSnippetLibrary: "Um menu de snippets com busca digita qualquer snippet direto no cursor",
        highlightsCaptionCapturePalette: "Um único atalho agora abre uma paleta flutuante para capturas, gravações, texto na tela e cores com ajustes por perto.",
        highlightsCaptionClipboardRedesign: "O histórico agora abre como uma paleta compacta, com linhas limpas e prévia sob demanda para ler ou editar o item completo.",
        highlightsConfigure: "Configurar",
        highlightsTry: "Experimentar",
        highlightsSeeAll: "Ver todas as mudanças",
        switcherCurrentSpaceOnly: "Mostrar só a Mesa atual",
        switcherCurrentSpaceOnlyCaption: "Mostra as janelas da Mesa atual. Janelas em tela cheia de outras Mesas também aparecem enquanto “Mostrar janelas em tela cheia” estiver ativo.",
        mixerSoundEffectsOutputTitle: "Sons do sistema",
        mixerSoundEffectsOutputTooltip: "Escolher onde alertas e efeitos sonoros tocam",
        monitorOpenActivityMonitor: "Abrir o Monitor de Atividade",
        dockClickHide: "Clicar no Dock oculta o app",
        dockClickHideCaption: "O app ativo é ocultado ao clicar no ícone dele no Dock. Clique de novo para trazê-lo de volta.",
        keepAwakeRightClickToggle: "Clique com o botão direito no ícone da barra de menus para alternar “Manter acordado”",
        keepAwakeRightClickToggleCaption: "Substitui o menu de contexto do clique com o botão direito.",
        switcherSearchPin: "Fixar busca com S",
        switcherSearchPinCaption: "S inicia uma busca e fixa o alternador aberto, assim digitar não produz mais caracteres especiais quando o atalho usa ⌥, e uma busca que comece com Q ou W não fecha a janela nem encerra o app por engano.",
        zoomControlNote: "Control + rolagem amplia o conteúdo do app em vez da tela do macOS.",
        switcherShowShortcutHints: "Mostrar dicas de atalhos",
        switcherShowShortcutHintsCaption: "Exibe os atalhos de apps e janelas abaixo dos ícones.",
        switcherMinimizedPlacementLabel: "Janelas minimizadas",
        switcherTreatHiddenAppsLikeMinimized: "Tratar apps ocultos como janelas minimizadas",
        switcherShowFullscreenWindows: "Mostrar janelas em tela cheia",
        switcherScreenPlacementLabel: "Mostrar em",
        switcherScreenPlacementPointer: "Tela com o ponteiro",
        switcherScreenPlacementMenuBar: "Tela com a barra de menus",
        switcherScreenPlacementActiveWindow: "Tela com a janela ativa",
        switcherScreenPlacementCaption: "Em qual tela o alternador abre quando há mais de uma conectada.",
        switcherCurrentDisplayOnly: "Mostrar só a tela atual",
        switcherCurrentDisplayOnlyCaption: "Mostra apenas as janelas da tela sob o cursor. Se essa tela não tiver janelas, o alternador não abre.",
        smoothScrollResponseLabel: "Resposta",
        smoothScrollCoastLabel: "Inércia",
        shelfClearOnClose: "Limpar ao fechar",
        shelfClearOnCloseCaption: "Esvazia a área somente quando você clica no botão de fechar. Ocultar automaticamente e encolher preservam os itens.",
)
}

// MARK: - English (US)

extension Strings {
    static let enUS = Strings(
        menuAbout: "About G’s Mac",
        menuQuit: "Quit G’s Mac",
        menuHide: "Hide G’s Mac",
        menuEdit: "Edit",
        menuUndo: "Undo",
        menuRedo: "Redo",
        menuCut: "Cut",
        menuCopy: "Copy",
        menuPaste: "Paste",
        menuSelectAll: "Select All",
        menuWindow: "Window",
        menuMinimize: "Minimize",
        menuClose: "Close",

        panelQuit: "Quit",

        keepAwakeTitle: "Keep awake",
        keepAwakeMouseJiggleInterval: "Interval",
        keepAwakeActiveIconVorssaint: "G’s Mac",
        keepAwakeActiveIconCoffee: "Coffee",
        keepAwakeActiveIconEye: "Eye",
        keepAwakeActiveIconMoon: "Moon",
        keepAwakeActiveIconLight: "Lightbulb",
        keepAwakeIconTintOrange: "Orange",
        keepAwakeIconTintGreen: "Green",
        keepAwakeIconTintBlue: "Blue",
        keepAwakeIconTintPurple: "Purple",
        keepAwakeIconTintPink: "Pink",
        keepAwakeIconTintNone: "No color",
        clamshellNeedsPassword: "Will ask for the administrator password once",

        memoryCompressed: "Compressed",
        memoryCachedFiles: "Cached files",

        adminPromptClamshellOff: "G’s Mac needs your password to restore the Mac’s normal sleep.",
        adminPromptRecover: "G’s Mac quit while the Mac’s sleep was disabled. Enter the password to restore normal sleep.",
        adminPromptSudoersInstall: "G’s Mac will create a restricted rule (pmset disablesleep only) to toggle closed-lid mode without asking for a password. This is the only time the password is needed.",
        adminPromptSudoersRemove: "G’s Mac will remove the password-free closed-lid rule.",

        settingsTitle: "G’s Mac Settings",
        minimalWindowPreviews: "Minimal previews",
        minimalWindowPreviewsCaption: "Hide titles, buttons and decorative details in Dock and switcher previews. The selection stays visible.",

        launchAtLogin: "Launch at login",
        languageLabel: "Language",
        showCountdown: "Show remaining time next to the icon",

        keepAwakeAutoStart: "Keep Awake when G’s Mac opens",
        dimScreenOnLidCloseTitle: "Dim the display to zero",

        smoothScrollStepLabel: "Scrolling speed",
        quickToolsTab: "Quick panel",
        ocrName: "Copy text from screen",
        ocrCaption: "Select an area of the screen and the recognized text is copied, ready to paste.",
        ocrCopied: "Text copied",
        ocrNoText: "No text found",
        micMuteCaption: "Uses each microphone’s mute or input-volume controls. Siri and some apps may still hear you. This is not a privacy lock.",
        micMutedHUD: "Mic Mute on",
        micUnmutedHUD: "Mic Mute off",
        launcherName: "Quick panel",

        switcherSection: "Window switcher",
        switcherNoWindows: "No open windows",
        switcherIconRowMode: "Show %@ with large icons",
        switcherIconRowModeCaption: "Shows one icon per app with that app’s window previews above it.",
        switcherSimpleModeCaption: "Shows app icons and window titles, without previews or screen capture by the switcher.",
        switcherShortcutHintApps: "Apps",
        switcherShortcutHintWindows: "Windows",
        switcherTakeOverSystemShortcuts: "Replace macOS ⌘Tab and ⌘`",
        switcherAppearanceDelay: "Appearance delay",
        switcherAppearanceDelayCaption: "How long the shortcut must be held before the switcher appears.",
        switcherMaxColumns: "Maximum columns",
        switcherMaxColumnsCaption: "Wraps onto more rows after this many items. Useful on ultrawide displays.",
        switcherMaxColumnsAuto: "Auto",
        switcherInstantSelection: "Instant selection",
        switcherMergeTabs: "Show one entry per app",
        switcherWindowlessApps: "Apps with no open window",
        switcherWindowlessAppsCaption: "Chooses which running apps with no window at all show up in the switcher.",
        switcherWindowlessAppsOff: "Do not show",
        switcherWindowlessAppsFinder: "Finder only",
        switcherWindowlessAppsAll: "All apps",
        switcherWindowlessAppsLockedFormat: "All running apps stay reachable while “%@” is on. Turn it off to choose.",
        switcherNoOpenWindow: "No open window",
        switcherOtherDesktop: "Other desktop",
        dockPreviewCurrentSpaceOnlyCaption: "When off, shows windows from all desktops. Choosing a window on another desktop takes you there.",
        dockPreviewBackgroundOpacity: "Panel background",
        dockPreviewBackgroundOpacityCaption: "Turn it down to see more of what sits behind the panel.",
        dockPreviewBackgroundOpacityGlassCaption: "Liquid Glass is on, so the panel’s transparency is set in System Settings > Appearance.",
        dockPreviewOpenDelay: "Open delay",
        dockPreviewOpenDelayCaption: "How long the pointer has to rest on an icon before its panel opens.",
        dockPreviewQuitAppOnClose: "Quit the app with the × button",
        dockPreviewQuitAppOnCloseCaption: "In Dock Preview, × quits the whole app instead of closing only that window.",
        dockPreviewKeepDockVisible: "Keep Dock visible (experimental)",
        dockPreviewOrderByCreation: "Order windows by creation time",
        dockPreviewOpenWindow: "Open window",
        dockPreviewCloseWindow: "Close window",
        dockPreviewMinimizeWindow: "Minimize window",
        dockPreviewRestoreWindow: "Restore window",
        dockPreviewPinPanel: "Pin preview",
        dockPreviewUnpinPanel: "Unpin preview",
        dockPreviewPinned: "Pinned",
        dockPreviewClosePanel: "Close preview",
        dockPreviewPreviousWindow: "Previous window",
        dockPreviewNextWindow: "Next window",

        cutReadyTitle: "Cut",
        cutReadyHint: "in the destination folder to move",
        cutCancel: "Cancel cut",
        cutDoneTitle: "Moved!",
        cutMovedSingular: "1 item moved",
        cutMovedPluralFormat: "%d items moved",
        cutSomeFailed: "Some items couldn’t be moved",
        cutMovingTitle: "Moving…",
        cutMovingCountFormat: "%d of %d",

        uninstallerSelectedFormat: "%d of %d selected",
        uninstallerCancel: "Cancel",
        uninstallerFreedFormat: "%@ removed",
        uninstallerRefusedNotApp: "Only apps can be uninstalled.",
        uninstallerRefusedSystemFormat: "%@ can’t be uninstalled because it’s part of macOS.",
        uninstallerRefusedSharedFormat: "%@ can’t be uninstalled here because it shares files with macOS or other apps.",
        uninstallerRefusedNestedFormat: "%@ can’t be uninstalled on its own because it’s part of another app.",
        uninstallerRefusedSelfFormat: "G’s Mac can’t uninstall itself here. Use Settings › %@ instead.",
        uninstallerRefusedLinkFormat: "%@ can’t be uninstalled because it’s a link to an app stored elsewhere.",
        uninstallerRefusedUnidentifiedFormat: "%@ can’t be uninstalled because it can’t be identified as an app.",
        uninstallerPickerHiddenNote: "Apps that are part of macOS or made by Apple aren’t listed.",

        homebrewGroupDependencies: "Group dependencies",
        homebrewUpgradeAll: "Update all",
        homebrewUpdateHomebrew: "Update Homebrew",
        homebrewPopularityFormat: "%@ installs in %@ days",
        homebrewConfirmInstallBodyFormat: "Homebrew will download and install %@. Dependencies may also be installed.",
        homebrewConfirmUninstallBodyFormat: "Homebrew will uninstall %@. Configuration files may remain on the system.",
        homebrewConfirmUpgradeBodyFormat: "Homebrew will download and apply the latest version of %@. Dependencies may also be updated.",
        homebrewConfirmUpgradeAllTitle: "Update all with Homebrew?",
        homebrewConfirmUpgradeAllBody: "Homebrew will download and apply the latest versions for packages with updates available. Dependencies may also be updated.",
        homebrewConfirmUpdateHomebrewTitle: "Update Homebrew?",
        homebrewConfirmUpdateHomebrewBody: "Homebrew will fetch the latest information and then reload your packages.",
        homebrewOperationInstallFormat: "Installing %@",
        homebrewOperationUninstallFormat: "Uninstalling %@",
        homebrewOperationUpgradeFormat: "Updating %@",
        homebrewOperationUpgradeAll: "Updating packages",
        homebrewOperationUpdateHomebrew: "Updating Homebrew",
        homebrewOperationInstalledFormat: "%@ installed.",
        homebrewOperationUninstalledFormat: "%@ uninstalled.",
        homebrewOperationUpgradedFormat: "%@ updated.",
        homebrewOperationUpgradedAll: "Packages updated.",
        homebrewOperationUpdatedHomebrew: "Homebrew updated.",
        homebrewOperationFailedFormat: "Could not finish %@.",
        homebrewOperationPreparing: "Preparing…",
        homebrewOperationDownloading: "Downloading files…",
        homebrewOperationInstalling: "Installing files…",
        homebrewOperationUninstalling: "Removing files…",
        homebrewOperationUpgrading: "Updating files…",
        homebrewOperationFinalizing: "Finishing…",
        homebrewOperationRefreshing: "Refreshing list…",
        homebrewOperationElapsedFormat: "%@ elapsed",

        mediaCancelled: "Cancelled.",

        shelfSelectedFormat: "%d selected",

        mixerInputErrorFormat: "Could not switch: %@",

        permissionRequest: "Grant access",
        secureInputTitle: "Secure input is on",
        secureInputHeldFormat: "%@ was the active app when it turned on and may be holding it, so G’s Mac cannot type for you. Dismiss its password field, or quit it, to release it.",
        secureInputUnattributed: "The app holding it cannot be named, so G’s Mac cannot type for you. Dismiss any open password field, or log out and back in, to clear it.",
        secureInputUnidentified: "The app holding it could not be identified, so G’s Mac cannot type for you.",
        secureInputRevealFormat: "Show %@",
        secureInputSwitcherHeldFormat: "%@ was the active app when it turned on and may be holding it. Until it turns off, macOS hides your keystrokes from the switcher and ⌘Tab opens the macOS switcher instead. Dismiss its password field, or quit it, to release it.",
        secureInputSwitcherUnattributed: "The app holding it cannot be named. Until it turns off, macOS hides your keystrokes from the switcher and ⌘Tab opens the macOS switcher instead. Dismiss any open password field, or log out and back in, to clear it.",
        secureInputSwitcherUnidentified: "The app holding it could not be identified. Until it turns off, macOS hides your keystrokes from the switcher and ⌘Tab opens the macOS switcher instead.",

        aboutDescription: "A utility hub for your Mac.\nEnergy, system monitor, scrolling and a window switcher, right in the menu bar.",
        reviewIntro: "Review introduction",

        networkApps: "Apps using network",
        networkAppsIdle: "No apps using network now",

        diskMenuBarStyleLabel: "Disk display",
        diskMenuBarUsedPercentage: "Used percentage",
        diskMenuBarAvailableSpace: "Available space",
        diskMenuBarUsedSpace: "Used space",
        diskAvailable: "available",
        diskPurgeable: "purgeable",

        powerAdapterMaxFormat: "%@ max",

        systemUptime: "Up for",

        disclosureExpanded: "Expanded",
        disclosureCollapsed: "Collapsed",
        panelHiddenItem: "Hidden",

        cleaningPanelCaption: "Locks the keyboard so you can clean safely.",
        cleaningOverlayTitle: "Keyboard locked for cleaning",
        cleaningOverlaySubtitle: "Press Escape 5 times to unlock",
        cleaningOverlayUnlock: "Unlock",
        cleaningOverlayMouseHint: "Your mouse and trackpad still work",
        cleaningKeepScreenVisibleToggle: "Keep screen visible",
        cleaningKeepScreenVisibleCaption: "Shows a discreet indicator in the corner of the screen instead of blacking out content.",
        cleaningStartNow: "Lock keyboard now",

        donateHeading: "Help G’s Mac keep growing",
        donateMessage: "G’s Mac stays free and local, with no ads or usage tracking. If it helps you, Buy Me a Coffee is the only way to help fund its development.",
        donateButton: "Support on Buy Me a Coffee",
        supportIntroTitle: "Help G’s Mac keep growing",
        supportIntroMessage: "G’s Mac stays free and local, with no ads or usage tracking. If it helps you, Buy Me a Coffee is the only way to help fund its development.",
        supportIntroStarButton: "Star G’s Mac on GitHub",
        supportIntroStarMessage: "Financial support is never expected. A star on GitHub helps more people discover G’s Mac and makes a real difference to its development.",
        supportIntroCoffeeButton: "Support on Buy Me a Coffee",
        supportIntroDoneButton: "Done",
        discordIntroTitle: "The G’s Mac Discord community is just getting started",
        discordIntroMessage: "The G’s Mac community is new and still being built. Join early to meet other users and help build a welcoming space around the app.",
        discordIntroJoinButton: "Join the Discord community",
        communityIntroTitle: "See it before everyone else",
        communityIntroMessage: "People who already followed me on X saw several changes in this update before anyone else. I post previews of what is coming and show how it works, so you already know the basics before the update ships. Follow along and see what comes next!",
        communityIntroFollowButton: "Follow @vorssaint on X",
        homebrewOfficialIntroTitle: "Now in the official Homebrew catalog",
        homebrewOfficialIntroMessage: "G’s Mac can now be installed directly from the official Homebrew catalog.",
        homebrewOfficialIntroInstallLabel: "New installation",
        homebrewOfficialIntroMigrationTitle: "Used the old tap?",
        homebrewOfficialIntroMigrationMessage: "Remove the tap once. The app and your settings stay in place.",
        homebrewOfficialIntroCopyButton: "Copy command",
        updateShowcaseTitle: "What’s new in 3.1.4",
        updateShowcaseMessage: "Take a quick look at the main improvements in this update.",
        updateShowcaseUnavailable: "The video could not load right now. You can still continue.",
        updateShowcaseRestart: "Restart",
        shortcutRecording: "Press the new shortcut",
        shortcutReset: "Reset",
        shortcutNone: "None",
        shortcutInvalid: "Use at least Control, Option or Command with a key.",
        shortcutPressKeys: "Press keys",
        shortcutEscapeHint: "Escape cancels.",
        shortcutDeleteHint: "Delete clears.",
        shortcutNotCaptured: "Nothing was captured. macOS or another app already uses that combination. Try another one.",
        shortcutConflictFormat: "This shortcut is already used by %@.",
        shortcutTakeOverOffer: "macOS uses %@ for one of its own shortcuts.",
        shortcutTakeOverAction: "Take over while G’s Mac runs",
        shortcutTakeOverCaption: "macOS gets the key back whenever G’s Mac is not running or this feature is off.",
        shortcutTakeOverDismiss: "Don’t take over",
        cleanerRevealInFinder: "Reveal in Finder",
        launchAtLoginNeedsApplications: "The app is running from a place that cannot open at login. Drag G’s Mac to the Applications folder, open it from there and turn this on again.",
        launchAtLoginNeedsApproval: "The login item is registered, but macOS still needs your approval. In System Settings, allow G’s Mac to open at login and to run in the background.",
        ocrRemoveLineBreaksToggle: "Remove line breaks",
        ocrRemoveLineBreaksCaption: "Removes line breaks so copied text pastes as one paragraph.",
        ocrQRToggle: "Read QR codes",
        ocrQRCaption: "If the area has a QR code, its content is shown to copy or open.",
        ocrQRCopied: "QR code copied",
        qrResultTitle: "QR code",
        qrResultCopy: "Copy",
        qrResultOpen: "Open link",
        highlightsTitleClipboardRedesign: "Redesigned clipboard",
        highlightsCaptionDockPreview: "Dock Preview now works with Dock magnification turned on",
        highlightsCaptionScreenshot: "The screenshot tool gained a pixel loupe and QR code reading",
        highlightsCaptionSnippetLibrary: "A searchable snippet menu types any snippet right at your cursor",
        highlightsCaptionCapturePalette: "One shortcut now opens a floating palette for screenshots, recordings, screen text and colors with nearby controls.",
        highlightsCaptionClipboardRedesign: "Clipboard history now opens as a compact palette with uncluttered rows and an on-demand preview for reading or editing the full item.",
        highlightsConfigure: "Set up",
        highlightsTry: "Try it",
        highlightsSeeAll: "See all changes",
        switcherCurrentSpaceOnly: "Show only the current desktop",
        switcherCurrentSpaceOnlyCaption: "Lists windows from the current desktop. Fullscreen windows from other desktops also appear while “Show fullscreen windows” is on.",
        mixerSoundEffectsOutputTitle: "System sounds",
        mixerSoundEffectsOutputTooltip: "Choose where alerts and sound effects play",
        monitorOpenActivityMonitor: "Open Activity Monitor",
        dockClickHide: "Click the Dock icon to hide the app",
        dockClickHideCaption: "The active app hides when you click its Dock icon. Click again to bring it back.",
        keepAwakeRightClickToggle: "Right-click the menu bar icon to toggle Keep Awake",
        keepAwakeRightClickToggleCaption: "Replaces the right-click context menu.",
        switcherSearchPin: "Pin search with S",
        switcherSearchPinCaption: "S starts a search and pins the switcher open, so typing no longer produces special characters when your shortcut uses ⌥, and a search starting with Q or W no longer closes the window or quits the app by mistake.",
        zoomControlNote: "Control + scroll performs app zoom instead of macOS screen zoom.",
        switcherShowShortcutHints: "Show shortcut hints",
        switcherShowShortcutHintsCaption: "Shows the app and window shortcuts below the icons.",
        switcherMinimizedPlacementLabel: "Minimized windows",
        switcherTreatHiddenAppsLikeMinimized: "Treat hidden apps like minimized windows",
        switcherShowFullscreenWindows: "Show fullscreen windows",
        switcherScreenPlacementLabel: "Show on",
        switcherScreenPlacementPointer: "Display with the pointer",
        switcherScreenPlacementMenuBar: "Display with the menu bar",
        switcherScreenPlacementActiveWindow: "Display with the active window",
        switcherScreenPlacementCaption: "Which display the switcher opens on when more than one is connected.",
        switcherCurrentDisplayOnly: "Show only the current display",
        switcherCurrentDisplayOnlyCaption: "Lists only windows on the display under the pointer. If that display has no windows, the switcher does not open.",
        smoothScrollResponseLabel: "Response",
        smoothScrollCoastLabel: "Coast",
        shelfClearOnClose: "Clear when closed",
        shelfClearOnCloseCaption: "Empties the shelf only when you click its close button. Automatic hiding and collapsing keep the items.",
)
}
