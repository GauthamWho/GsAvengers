// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct SwitcherAppRulesStrings {
    let addButton: String
    let showWithoutWindows: String
    let windowsOnly: String
    let hidden: String
    let caption: String
}

extension FeatureStrings {
    static func switcherAppRules(_ language: AppLanguage) -> SwitcherAppRulesStrings {
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

extension SwitcherAppRulesStrings {
    static let enUS = SwitcherAppRulesStrings(
        addButton: "Add an app…",
        showWithoutWindows: "Show without windows",
        windowsOnly: "Windows only",
        hidden: "Never show",
        caption: "Choose how each app appears. Apps without a rule use the choice above."
    )

    static let ptBR = SwitcherAppRulesStrings(
        addButton: "Adicionar app…",
        showWithoutWindows: "Mostrar sem janelas",
        windowsOnly: "Só com janelas",
        hidden: "Nunca mostrar",
        caption: "Escolha como cada app aparece. Apps sem regra usam a opção acima."
    )

    static let tr = SwitcherAppRulesStrings(
        addButton: "Uygulama ekle…",
        showWithoutWindows: "Pencere olmadan göster",
        windowsOnly: "Yalnızca pencereler",
        hidden: "Asla gösterme",
        caption: "Her uygulamanın nasıl görüneceğini seçin. Kuralı olmayanlar yukarıdaki seçimi kullanır."
    )

    static let ru = SwitcherAppRulesStrings(
        addButton: "Добавить приложение…",
        showWithoutWindows: "Показывать без окон",
        windowsOnly: "Только с окнами",
        hidden: "Никогда не показывать",
        caption: "Выберите, как показывать каждое приложение. Без правила действует настройка выше."
    )

    static let es = SwitcherAppRulesStrings(
        addButton: "Añadir app…",
        showWithoutWindows: "Mostrar sin ventanas",
        windowsOnly: "Solo con ventanas",
        hidden: "No mostrar nunca",
        caption: "Elige cómo aparece cada app. Las apps sin regla usan la opción anterior."
    )

    static let sk = SwitcherAppRulesStrings(
        addButton: "Pridať aplikáciu…",
        showWithoutWindows: "Zobraziť aj bez okien",
        windowsOnly: "Len s oknami",
        hidden: "Nikdy nezobrazovať",
        caption: "Vyberte, ako sa má zobraziť každá aplikácia. Apky bez pravidla použijú voľbu vyššie."
    )

    static let de = SwitcherAppRulesStrings(
        addButton: "App hinzufügen…",
        showWithoutWindows: "Ohne Fenster anzeigen",
        windowsOnly: "Nur mit Fenstern",
        hidden: "Nie anzeigen",
        caption: "Lege fest, wie jede App erscheint. Apps ohne Regel verwenden die Auswahl darüber."
    )

    static let fr = SwitcherAppRulesStrings(
        addButton: "Ajouter une app…",
        showWithoutWindows: "Afficher sans fenêtre",
        windowsOnly: "Avec fenêtres uniquement",
        hidden: "Ne jamais afficher",
        caption: "Choisissez comment chaque app apparaît. Sans règle, l’app utilise le choix ci-dessus."
    )

    static let it = SwitcherAppRulesStrings(
        addButton: "Aggiungi app…",
        showWithoutWindows: "Mostra senza finestre",
        windowsOnly: "Solo con finestre",
        hidden: "Non mostrare mai",
        caption: "Scegli come appare ogni app. Le app senza regola usano l’opzione qui sopra."
    )

    static let ja = SwitcherAppRulesStrings(
        addButton: "Appを追加…",
        showWithoutWindows: "ウインドウなしでも表示",
        windowsOnly: "ウインドウがある時のみ",
        hidden: "常に非表示",
        caption: "Appごとの表示方法を選びます。ルールのないAppには上の設定が使われます。"
    )

    static let ko = SwitcherAppRulesStrings(
        addButton: "앱 추가…",
        showWithoutWindows: "창 없이도 표시",
        windowsOnly: "창이 있을 때만",
        hidden: "항상 숨기기",
        caption: "각 앱의 표시 방식을 선택합니다. 규칙이 없는 앱은 위의 설정을 사용합니다."
    )

    static let zhHans = SwitcherAppRulesStrings(
        addButton: "添加 App…",
        showWithoutWindows: "无窗口时也显示",
        windowsOnly: "仅有窗口时显示",
        hidden: "始终不显示",
        caption: "选择每个 App 的显示方式。未设置规则的 App 使用上方选项。"
    )

    static let zhTW = SwitcherAppRulesStrings(
        addButton: "加入 App…",
        showWithoutWindows: "沒有視窗時也顯示",
        windowsOnly: "僅有視窗時顯示",
        hidden: "一律不顯示",
        caption: "選擇每個 App 的顯示方式。沒有規則的 App 使用上方選項。"
    )

    static let zhHK = SwitcherAppRulesStrings(
        addButton: "加入 App…",
        showWithoutWindows: "沒有視窗時也顯示",
        windowsOnly: "僅有視窗時顯示",
        hidden: "一律不顯示",
        caption: "選擇每個 App 的顯示方式。沒有規則的 App 使用上方選項。"
    )
    static let uk = SwitcherAppRulesStrings(
        addButton: "Додати програму…",
        showWithoutWindows: "Показувати без вікон",
        windowsOnly: "Лише вікна",
        hidden: "Ніколи не показувати",
        caption: "Виберіть, як кожна програма з’являється. Програми без правила використовують вибір вище."
    )
}
