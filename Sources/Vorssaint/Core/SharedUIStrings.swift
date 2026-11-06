// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

/// A few words several pages share: the reorder hint under tiles, the way to
/// the Features page, a layout heading and the camera’s retry message.
struct SharedUIStrings {
    let layout: String
    let enableFeatureFormat: String

    /// What an option says while the feature it needs is uninstalled.
    func enableFeature(_ title: String) -> String { String(format: enableFeatureFormat, title) }
}

extension FeatureStrings {
    static func shared(_ language: AppLanguage) -> SharedUIStrings {
        switch language {
        case .enUS: return SharedUIStrings(
            layout: "Layout", 
            enableFeatureFormat: "Enable “%@” in Features.",
)
        case .ptBR: return SharedUIStrings(
            layout: "Layout", 
            enableFeatureFormat: "Ative “%@” em Recursos.",
)
        case .es: return SharedUIStrings(
            layout: "Diseño", 
            enableFeatureFormat: "Activa “%@” en Funciones.",
)
        case .sk: return SharedUIStrings(
            layout: "Rozloženie", 
            enableFeatureFormat: "Zapnite „%@“ vo Funkciách.",
)
        case .de: return SharedUIStrings(
            layout: "Layout", 
            enableFeatureFormat: "Aktiviere „%@“ unter Funktionen.",
)
        case .fr: return SharedUIStrings(
            layout: "Disposition", 
            enableFeatureFormat: "Activez « %@ » dans Fonctionnalités.",
)
        case .it: return SharedUIStrings(
            layout: "Layout", 
            enableFeatureFormat: "Attiva “%@” in Funzioni.",
)
        case .ru: return SharedUIStrings(
            layout: "Макет", 
            enableFeatureFormat: "Включите «%@» в разделе функций.",
)
        case .tr: return SharedUIStrings(
            layout: "Yerleşim", 
            enableFeatureFormat: "Özellikler’de “%@” özelliğini etkinleştirin.",
)
        case .ja: return SharedUIStrings(
            layout: "レイアウト", 
            enableFeatureFormat: "機能で「%@」を有効にしてください。",
)
        case .ko: return SharedUIStrings(
            layout: "레이아웃", 
            enableFeatureFormat: "기능에서 “%@”을(를) 활성화하세요.",
)
        case .zhHans: return SharedUIStrings(
            layout: "布局", 
            enableFeatureFormat: "在功能中启用“%@”。",
)
        case .zhTW: return SharedUIStrings(
            layout: "佈局", 
            enableFeatureFormat: "在功能中啟用「%@」。",
)
        case .zhHK: return SharedUIStrings(
            layout: "佈局", 
            enableFeatureFormat: "在功能中啟用「%@」。",
)
        case .uk: return SharedUIStrings(
            layout: "Розкладка", 
            enableFeatureFormat: "Увімкніть «%@» у Функціях.",
)
        }
    }
}
