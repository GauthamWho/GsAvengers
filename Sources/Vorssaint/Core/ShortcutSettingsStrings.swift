// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ShortcutSettingsStrings {
    let active: String
}

extension FeatureStrings {
    static func shortcuts(_ language: AppLanguage) -> ShortcutSettingsStrings {
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
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension ShortcutSettingsStrings {
    static let enUS = ShortcutSettingsStrings(
        active: "Active",
)

    static let ptBR = ShortcutSettingsStrings(
        active: "Ativo",
)

    static let tr = ShortcutSettingsStrings(
        active: "Etkin",
)

    static let ru = ShortcutSettingsStrings(
        active: "Активно",
)

    static let es = ShortcutSettingsStrings(
        active: "Activo",
)

    static let sk = ShortcutSettingsStrings(
        active: "Aktívna",
)

    static let de = ShortcutSettingsStrings(
        active: "Aktiv",
)

    static let fr = ShortcutSettingsStrings(
        active: "Actif",
)

    static let it = ShortcutSettingsStrings(
        active: "Attiva",
)

    static let ja = ShortcutSettingsStrings(
        active: "有効",
)

    static let ko = ShortcutSettingsStrings(
        active: "활성",
)

    static let zhHans = ShortcutSettingsStrings(
        active: "已启用",
)

    static let zhTW = ShortcutSettingsStrings(
        active: "已啟用",
)

    static let zhHK = ShortcutSettingsStrings(
        active: "已啟用",
)
    static let uk = ShortcutSettingsStrings(
        active: "Активно",
)
}
