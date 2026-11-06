// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MenuBarAppearanceStrings {
    let label: String
    let values: String
    let caption: String
}

extension FeatureStrings {
    static func menuBarAppearance(_ language: AppLanguage) -> MenuBarAppearanceStrings {
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

extension MenuBarAppearanceStrings {
    static let enUS = MenuBarAppearanceStrings(
        label: "Usage display",
        values: "Values",
        caption: "Bars apply to CPU, GPU, memory and disk usage. Other readings stay numeric.",
)

    static let ptBR = MenuBarAppearanceStrings(
        label: "Exibição de uso",
        values: "Valores",
        caption: "As barras mostram o uso de CPU, GPU, memória e disco. As outras leituras continuam numéricas.",
)

    static let tr = MenuBarAppearanceStrings(
        label: "Kullanım görünümü",
        values: "Değerler",
        caption: "Çubuklar CPU, GPU, bellek ve disk kullanımını gösterir. Diğer ölçümler sayısal kalır.",
)

    static let ru = MenuBarAppearanceStrings(
        label: "Отображение нагрузки",
        values: "Значения",
        caption: "Шкалы показывают загрузку CPU, GPU, памяти и диска. Остальные показатели остаются числовыми.",
)

    static let es = MenuBarAppearanceStrings(
        label: "Vista de uso",
        values: "Valores",
        caption: "Las barras muestran el uso de CPU, GPU, memoria y disco. Las demás lecturas siguen siendo numéricas.",
)

    static let sk = MenuBarAppearanceStrings(
        label: "Zobrazenie vyťaženia",
        values: "Hodnoty",
        caption: "Pruhy platia pre vyťaženie CPU, GPU, pamäte a disku. Ostatné hodnoty zostávajú číselné.",
)

    static let de = MenuBarAppearanceStrings(
        label: "Auslastungsanzeige",
        values: "Werte",
        caption: "Balken zeigen die Auslastung von CPU, GPU, Speicher und Festplatte. Andere Messwerte bleiben numerisch.",
)

    static let fr = MenuBarAppearanceStrings(
        label: "Affichage de l’utilisation",
        values: "Valeurs",
        caption: "Les barres indiquent l’utilisation du CPU, du GPU, de la mémoire et du disque. Les autres mesures restent numériques.",
)

    static let it = MenuBarAppearanceStrings(
        label: "Visualizzazione utilizzo",
        values: "Valori",
        caption: "Le barre mostrano l’utilizzo di CPU, GPU, memoria e disco. Le altre letture restano numeriche.",
)

    static let ja = MenuBarAppearanceStrings(
        label: "使用率の表示",
        values: "数値",
        caption: "CPU、GPU、メモリ、ディスクの使用率をバーで表示します。その他の測定値は数値のままです。",
)

    static let ko = MenuBarAppearanceStrings(
        label: "사용량 표시",
        values: "값",
        caption: "CPU, GPU, 메모리 및 디스크 사용량을 막대로 표시합니다. 다른 측정값은 숫자로 유지됩니다.",
)

    static let zhHans = MenuBarAppearanceStrings(
        label: "使用率显示",
        values: "数值",
        caption: "CPU、GPU、内存和磁盘使用率以条形显示。其他读数保持数字显示。",
)

    static let zhTW = MenuBarAppearanceStrings(
        label: "使用率顯示",
        values: "數值",
        caption: "CPU、GPU、記憶體和磁碟使用率以長條顯示。其他讀數維持數字顯示。",
)

    static let zhHK = MenuBarAppearanceStrings(
        label: "使用率顯示",
        values: "數值",
        caption: "CPU、GPU、記憶體及磁碟使用率以長條顯示。其他讀數維持數字顯示。",
)
    static let uk = MenuBarAppearanceStrings(
        label: "Відображення використання",
        values: "Значення",
        caption: "Смуги застосовуються до використання CPU, GPU, пам’яті та диска. Інші показники залишаються числовими.",
)
}
