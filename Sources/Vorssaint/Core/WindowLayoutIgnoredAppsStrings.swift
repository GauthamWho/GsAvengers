// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct WindowLayoutIgnoredAppsStrings {
    let addButton: String
    let caption: String
}

extension FeatureStrings {
    static func windowLayoutIgnoredApps(_ language: AppLanguage) -> WindowLayoutIgnoredAppsStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension WindowLayoutIgnoredAppsStrings {
    static let enUS = WindowLayoutIgnoredAppsStrings(addButton: "Add an app…", caption: "Window Layout does not use mouse or keyboard input while one of these apps is focused.")
    static let ptBR = WindowLayoutIgnoredAppsStrings(addButton: "Adicionar app…", caption: "O Layout de janelas não usa entrada do mouse ou teclado enquanto um destes apps está em foco.")
    static let tr = WindowLayoutIgnoredAppsStrings(addButton: "Uygulama ekle…", caption: "Bu uygulamalardan biri odaktayken Pencere yerleşimi fare veya klavye girdisini kullanmaz.")
    static let ru = WindowLayoutIgnoredAppsStrings(addButton: "Добавить приложение…", caption: "Раскладка окон не использует мышь или клавиатуру, пока одно из этих приложений в фокусе.")
    static let es = WindowLayoutIgnoredAppsStrings(addButton: "Añadir app…", caption: "Diseño de ventanas no usa el ratón ni el teclado mientras una de estas apps tiene el foco.")
    static let sk = WindowLayoutIgnoredAppsStrings(addButton: "Pridať aplikáciu…", caption: "Rozloženie okien nepoužíva vstup z myši ani klávesnice, kým je jedna z týchto aplikácií v popredí.")
    static let de = WindowLayoutIgnoredAppsStrings(addButton: "App hinzufügen…", caption: "Fensterlayout verwendet keine Maus- oder Tastatureingaben, solange eine dieser Apps fokussiert ist.")
    static let fr = WindowLayoutIgnoredAppsStrings(addButton: "Ajouter une app…", caption: "Disposition des fenêtres n’utilise ni la souris ni le clavier tant que l’une de ces apps est active.")
    static let it = WindowLayoutIgnoredAppsStrings(addButton: "Aggiungi app…", caption: "Layout finestre non usa mouse o tastiera finché una di queste app è attiva.")
    static let ja = WindowLayoutIgnoredAppsStrings(addButton: "Appを追加…", caption: "これらのAppが前面にある間、ウインドウ配置はマウスやキーボード入力を使いません。")
    static let ko = WindowLayoutIgnoredAppsStrings(addButton: "앱 추가…", caption: "이 앱 중 하나에 포커스가 있을 때 윈도우 정렬은 마우스나 키보드 입력을 사용하지 않습니다.")
    static let uk = WindowLayoutIgnoredAppsStrings(addButton: "Додати програму…", caption: "Розкладка вікон не використовує введення з миші чи клавіатури, поки одна з цих програм у фокусі.")
    static let zhHans = WindowLayoutIgnoredAppsStrings(addButton: "添加 App…", caption: "当这些 App 之一处于焦点时，窗口布局不会使用鼠标或键盘输入。")
    static let zhTW = WindowLayoutIgnoredAppsStrings(addButton: "加入 App…", caption: "當這些 App 之一處於焦點時，視窗排列不會使用滑鼠或鍵盤輸入。")
    static let zhHK = WindowLayoutIgnoredAppsStrings(addButton: "加入 App…", caption: "當這些 App 之一處於焦點時，視窗排列不會使用滑鼠或鍵盤輸入。")
}
