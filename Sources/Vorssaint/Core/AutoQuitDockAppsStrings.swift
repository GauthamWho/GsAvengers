// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct AutoQuitDockAppsStrings {
    let caption: String
    let addButton: String
}

extension FeatureStrings {
    static func autoQuitDockApps(_ language: AppLanguage) -> AutoQuitDockAppsStrings {
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

extension AutoQuitDockAppsStrings {
    static let enUS = AutoQuitDockAppsStrings(
        caption: "Menu bar apps stay open by default. Apps you select here can quit after their last window closes while they are in the Dock. Exceptions still keep them open.",
        addButton: "Add an app…",
)

    static let ptBR = AutoQuitDockAppsStrings(
        caption: "Apps da barra de menus continuam abertos por padrão. Os selecionados aqui podem ser encerrados após fechar a última janela enquanto aparecem no Dock. As exceções continuam mantendo os apps abertos.",
        addButton: "Adicionar app…",
)

    static let tr = AutoQuitDockAppsStrings(
        caption: "Menü çubuğu uygulamaları varsayılan olarak açık kalır. Burada seçtiğiniz uygulamalardan, son pencereleri kapandıktan sonra Dock’ta görünüyorlarsa çıkılabilir. İstisnalar yine açık tutulur.",
        addButton: "Uygulama ekle…",
)

    static let ru = AutoQuitDockAppsStrings(
        caption: "По умолчанию приложения строки меню остаются открытыми. Выбранные здесь приложения могут завершаться после закрытия последнего окна, если они отображаются в Dock. Приложения из списка исключений остаются открытыми.",
        addButton: "Добавить приложение…",
)

    static let es = AutoQuitDockAppsStrings(
        caption: "Las apps de la barra de menús permanecen abiertas por defecto. Las apps que selecciones aquí pueden cerrarse al cerrar su última ventana si aparecen en el Dock. Las excepciones siguen manteniéndolas abiertas.",
        addButton: "Añadir app…",
)

    static let sk = AutoQuitDockAppsStrings(
        caption: "Aplikácie v lište s ponukami predvolene zostávajú otvorené. Vybrané aplikácie sa môžu ukončiť po zatvorení posledného okna, ak sa zobrazujú v Docku. Aplikácie v zozname výnimiek zostávajú otvorené.",
        addButton: "Pridať aplikáciu…",
)

    static let de = AutoQuitDockAppsStrings(
        caption: "Menüleisten-Apps bleiben standardmäßig geöffnet. Hier ausgewählte Apps können nach dem Schließen ihres letzten Fensters beendet werden, wenn sie im Dock erscheinen. Ausnahmen bleiben weiterhin geöffnet.",
        addButton: "App hinzufügen…",
)

    static let fr = AutoQuitDockAppsStrings(
        caption: "Les apps de la barre des menus restent ouvertes par défaut. Les apps sélectionnées ici peuvent quitter après la fermeture de leur dernière fenêtre si elles apparaissent dans le Dock. Les exceptions restent ouvertes.",
        addButton: "Ajouter une app…",
)

    static let it = AutoQuitDockAppsStrings(
        caption: "Le app della barra dei menu restano aperte per impostazione predefinita. Le app selezionate qui possono essere chiuse dopo la chiusura dell’ultima finestra se compaiono nel Dock. Le eccezioni restano aperte.",
        addButton: "Aggiungi app…",
)

    static let ja = AutoQuitDockAppsStrings(
        caption: "メニューバーAppは標準では起動したままになります。ここで選択したAppは、最後のウインドウを閉じた後もDockに表示されている場合、終了できます。例外リストのAppは起動したままになります。",
        addButton: "Appを追加…",
)

    static let ko = AutoQuitDockAppsStrings(
        caption: "메뉴 막대 앱은 기본적으로 계속 실행됩니다. 여기서 선택한 앱은 마지막 창을 닫은 뒤에도 Dock에 표시되어 있으면 종료될 수 있습니다. 예외 목록의 앱은 계속 실행됩니다.",
        addButton: "앱 추가…",
)

    static let uk = AutoQuitDockAppsStrings(
        caption: "Типово програми смуги меню залишаються відкритими. Вибрані тут програми можуть завершуватися після закриття останнього вікна, якщо вони відображаються в Dock. Програми зі списку винятків залишаються відкритими.",
        addButton: "Додати програму…",
)

    static let zhHans = AutoQuitDockAppsStrings(
        caption: "菜单栏 App 默认保持运行。在此选择的 App 关闭最后一个窗口后，如果仍显示在程序坞中，则可以退出。例外列表中的 App 仍会保持运行。",
        addButton: "添加 App…",
)

    static let zhTW = AutoQuitDockAppsStrings(
        caption: "選單列 App 預設會保持執行。在此選取的 App 關閉最後一個視窗後，如果仍顯示在 Dock 中，即可結束。例外清單中的 App 仍會保持執行。",
        addButton: "加入 App…",
)

    static let zhHK = AutoQuitDockAppsStrings(
        caption: "選單列 App 預設會保持執行。在此選取的 App 關閉最後一個視窗後，如果仍顯示在 Dock 中，即可結束。例外清單中的 App 仍會保持執行。",
        addButton: "加入 App…",
)
}
