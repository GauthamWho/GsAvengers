// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import Foundation

/// G’s Mac's one-screen setup: the Windows habits a Mac lacks, all on, with
/// nothing to choose unless the person wants to. Everything else stays off
/// and out of the way until switched on in Settings.
enum GsMacEssential: String, CaseIterable, Identifiable {
    case switcher, closeQuits, snapping, cutPaste, clipboard, screenshot, recorder, quickRing, lidClosed

    var id: String { rawValue }

    var feature: AppFeature {
        switch self {
        case .switcher: return .switcher
        case .closeQuits: return .autoQuit
        case .snapping: return .windowLayout
        case .cutPaste: return .finderCutPaste
        case .clipboard: return .clipboardHistory
        case .screenshot: return .screenshot
        case .recorder: return .screenRecorder
        case .quickRing: return .quickRing
        case .lidClosed: return .keepAwake
        }
    }

    var symbolName: String {
        switch self {
        case .switcher: return "rectangle.on.rectangle"
        case .closeQuits: return "xmark.app"
        case .snapping: return "rectangle.split.2x1"
        case .cutPaste: return "scissors"
        case .clipboard: return "doc.on.clipboard"
        case .screenshot: return "camera.viewfinder"
        case .recorder: return "record.circle"
        case .quickRing: return "circle.circle"
        case .lidClosed: return "laptopcomputer"
        }
    }

    func title(_ s: GsMacSetupStrings) -> String {
        switch self {
        case .switcher: return s.switcher
        case .closeQuits: return s.closeQuits
        case .snapping: return s.snapping
        case .cutPaste: return s.cutPaste
        case .clipboard: return s.clipboard
        case .screenshot: return s.screenshot
        case .recorder: return s.recorder
        case .quickRing: return s.quickRing
        case .lidClosed: return s.lidClosed
        }
    }

    /// Small helpers that ride along with every setup, with no row of their own.
    static let silentFeatures: Set<AppFeature> = [.quitWindowProtection, .pastePlain]

    /// What a fresh install has before the setup screen is even answered.
    static var defaultFeatures: Set<AppFeature> {
        Set(allCases.map(\.feature)).union(silentFeatures)
    }
}

struct GsMacSetupStrings {
    let title: String
    let subtitle: String
    let start: String
    let changeLater: String
    let switcher: String
    let closeQuits: String
    let snapping: String
    let cutPaste: String
    let clipboard: String
    let screenshot: String
    let recorder: String
    let quickRing: String
    let lidClosed: String
}

extension FeatureStrings {
    static func gsMacSetup(_ language: AppLanguage) -> GsMacSetupStrings {
        switch language {
        case .enUS: return GsMacSetupStrings(
            title: "Your Mac, with the Windows habits you know",
            subtitle: "All on already. Switch off anything you don’t want.",
            start: "Start", changeLater: "You can change these any time in Settings.",
            switcher: "Alt-Tab switcher for apps and windows",
            closeQuits: "Closing the last window quits the app",
            snapping: "Snap windows to halves and corners",
            cutPaste: "Cut and paste files in Finder",
            clipboard: "Clipboard history",
            screenshot: "Screenshots go straight to the clipboard",
            recorder: "Screen recording",
            quickRing: "Quick Ring at the mouse",
            lidClosed: "Keep running with the lid closed")
        case .ptBR: return GsMacSetupStrings(
            title: "Seu Mac, com os hábitos do Windows que você conhece",
            subtitle: "Tudo já está ativado. Desative o que não quiser.",
            start: "Começar", changeLater: "Você pode mudar isso a qualquer momento nos Ajustes.",
            switcher: "Alternador Alt-Tab de apps e janelas",
            closeQuits: "Fechar a última janela encerra o app",
            snapping: "Encaixar janelas em metades e cantos",
            cutPaste: "Recortar e colar arquivos no Finder",
            clipboard: "Histórico da área de transferência",
            screenshot: "Capturas vão direto para a área de transferência",
            recorder: "Gravação de tela",
            quickRing: "Anel rápido no mouse",
            lidClosed: "Continuar funcionando com a tampa fechada")
        case .tr: return GsMacSetupStrings(
            title: "Bildiğiniz Windows alışkanlıklarıyla Mac’iniz",
            subtitle: "Hepsi zaten açık. İstemediğinizi kapatın.",
            start: "Başla", changeLater: "Bunları istediğiniz zaman Ayarlar’dan değiştirebilirsiniz.",
            switcher: "Uygulama ve pencereler için Alt-Tab geçişi",
            closeQuits: "Son pencereyi kapatmak uygulamadan çıkar",
            snapping: "Pencereleri yarımlara ve köşelere yerleştir",
            cutPaste: "Finder’da dosyaları kes ve yapıştır",
            clipboard: "Pano geçmişi",
            screenshot: "Ekran görüntüleri doğrudan panoya gider",
            recorder: "Ekran kaydı",
            quickRing: "Farede Hızlı Halka",
            lidClosed: "Kapak kapalıyken çalışmaya devam et")
        case .ru: return GsMacSetupStrings(
            title: "Ваш Mac с привычками из Windows",
            subtitle: "Всё уже включено. Отключите то, что не нужно.",
            start: "Начать", changeLater: "Это можно изменить в любой момент в Настройках.",
            switcher: "Переключатель Alt-Tab для приложений и окон",
            closeQuits: "Закрытие последнего окна завершает приложение",
            snapping: "Окна по половинам и углам экрана",
            cutPaste: "Вырезать и вставлять файлы в Finder",
            clipboard: "История буфера обмена",
            screenshot: "Снимки экрана сразу в буфер обмена",
            recorder: "Запись экрана",
            quickRing: "Быстрое кольцо у указателя",
            lidClosed: "Работать с закрытой крышкой")
        case .es: return GsMacSetupStrings(
            title: "Tu Mac, con los hábitos de Windows que ya conoces",
            subtitle: "Todo está activado. Desactiva lo que no quieras.",
            start: "Empezar", changeLater: "Puedes cambiarlo cuando quieras en Ajustes.",
            switcher: "Selector Alt-Tab de apps y ventanas",
            closeQuits: "Cerrar la última ventana cierra la app",
            snapping: "Ajustar ventanas a mitades y esquinas",
            cutPaste: "Cortar y pegar archivos en Finder",
            clipboard: "Historial del portapapeles",
            screenshot: "Las capturas van directas al portapapeles",
            recorder: "Grabación de pantalla",
            quickRing: "Anillo rápido en el puntero",
            lidClosed: "Seguir funcionando con la tapa cerrada")
        case .sk: return GsMacSetupStrings(
            title: "Váš Mac so zvykmi z Windows",
            subtitle: "Všetko je už zapnuté. Vypnite, čo nechcete.",
            start: "Začať", changeLater: "Kedykoľvek to môžete zmeniť v Nastaveniach.",
            switcher: "Prepínač Alt-Tab pre apky a okná",
            closeQuits: "Zatvorenie posledného okna ukončí apku",
            snapping: "Prichytávanie okien k polovicám a rohom",
            cutPaste: "Vystrihnúť a vložiť súbory vo Finderi",
            clipboard: "História schránky",
            screenshot: "Snímky obrazovky rovno do schránky",
            recorder: "Nahrávanie obrazovky",
            quickRing: "Rýchly kruh pri myši",
            lidClosed: "Bežať aj so zatvoreným vekom")
        case .de: return GsMacSetupStrings(
            title: "Dein Mac mit den Windows-Gewohnheiten, die du kennst",
            subtitle: "Alles ist schon an. Schalte aus, was du nicht willst.",
            start: "Los geht’s", changeLater: "Du kannst das jederzeit in den Einstellungen ändern.",
            switcher: "Alt-Tab-Umschalter für Apps und Fenster",
            closeQuits: "Letztes Fenster schließen beendet die App",
            snapping: "Fenster an Hälften und Ecken ausrichten",
            cutPaste: "Dateien im Finder ausschneiden und einfügen",
            clipboard: "Zwischenablage-Verlauf",
            screenshot: "Bildschirmfotos direkt in die Zwischenablage",
            recorder: "Bildschirmaufnahme",
            quickRing: "Schnellring am Mauszeiger",
            lidClosed: "Weiterlaufen bei zugeklapptem Deckel")
        case .fr: return GsMacSetupStrings(
            title: "Votre Mac, avec les habitudes de Windows",
            subtitle: "Tout est déjà activé. Désactivez ce que vous ne voulez pas.",
            start: "Commencer", changeLater: "Vous pourrez changer cela à tout moment dans les Réglages.",
            switcher: "Sélecteur Alt-Tab des apps et fenêtres",
            closeQuits: "Fermer la dernière fenêtre quitte l’app",
            snapping: "Aligner les fenêtres en moitiés et en coins",
            cutPaste: "Couper et coller des fichiers dans le Finder",
            clipboard: "Historique du presse-papiers",
            screenshot: "Captures directement dans le presse-papiers",
            recorder: "Enregistrement de l’écran",
            quickRing: "Anneau rapide au pointeur",
            lidClosed: "Continuer à fonctionner capot fermé")
        case .it: return GsMacSetupStrings(
            title: "Il tuo Mac, con le abitudini di Windows che conosci",
            subtitle: "È già tutto attivo. Disattiva ciò che non vuoi.",
            start: "Inizia", changeLater: "Puoi cambiarlo quando vuoi nelle Impostazioni.",
            switcher: "Selettore Alt-Tab per app e finestre",
            closeQuits: "Chiudere l’ultima finestra chiude l’app",
            snapping: "Aggancia le finestre a metà e negli angoli",
            cutPaste: "Taglia e incolla file nel Finder",
            clipboard: "Cronologia degli appunti",
            screenshot: "Gli screenshot vanno subito negli appunti",
            recorder: "Registrazione dello schermo",
            quickRing: "Anello rapido sul puntatore",
            lidClosed: "Continua a funzionare a coperchio chiuso")
        case .ja: return GsMacSetupStrings(
            title: "使い慣れた Windows の操作を Mac に",
            subtitle: "すべてオンになっています。不要なものはオフにしてください。",
            start: "始める", changeLater: "あとから設定でいつでも変更できます。",
            switcher: "アプリとウインドウの Alt-Tab 切り替え",
            closeQuits: "最後のウインドウを閉じるとアプリを終了",
            snapping: "ウインドウを半分や四隅にスナップ",
            cutPaste: "Finder でファイルをカット&ペースト",
            clipboard: "クリップボード履歴",
            screenshot: "スクリーンショットを直接クリップボードへ",
            recorder: "画面収録",
            quickRing: "マウス位置にクイックリング",
            lidClosed: "蓋を閉じても動作を続ける")
        case .ko: return GsMacSetupStrings(
            title: "익숙한 Windows 습관 그대로, 내 Mac",
            subtitle: "모두 켜져 있습니다. 원하지 않는 항목은 끄세요.",
            start: "시작", changeLater: "설정에서 언제든지 변경할 수 있습니다.",
            switcher: "앱과 창을 위한 Alt-Tab 전환기",
            closeQuits: "마지막 창을 닫으면 앱 종료",
            snapping: "창을 절반과 모서리에 맞추기",
            cutPaste: "Finder에서 파일 잘라내기와 붙여넣기",
            clipboard: "클립보드 기록",
            screenshot: "스크린샷을 바로 클립보드로",
            recorder: "화면 녹화",
            quickRing: "마우스 위치에 퀵 링",
            lidClosed: "덮개를 닫아도 계속 실행")
        case .uk: return GsMacSetupStrings(
            title: "Ваш Mac зі звичками з Windows",
            subtitle: "Усе вже ввімкнено. Вимкніть те, що не потрібно.",
            start: "Почати", changeLater: "Це можна змінити будь-коли в Параметрах.",
            switcher: "Перемикач Alt-Tab для програм і вікон",
            closeQuits: "Закриття останнього вікна завершує програму",
            snapping: "Вікна по половинах і кутах екрана",
            cutPaste: "Вирізати й вставляти файли у Finder",
            clipboard: "Історія буфера обміну",
            screenshot: "Знімки екрана одразу в буфер обміну",
            recorder: "Запис екрана",
            quickRing: "Швидке кільце біля вказівника",
            lidClosed: "Працювати із закритою кришкою")
        case .zhHans: return GsMacSetupStrings(
            title: "带着熟悉的 Windows 习惯用 Mac",
            subtitle: "已全部开启。不需要的可以关掉。",
            start: "开始", changeLater: "之后可随时在设置中更改。",
            switcher: "应用和窗口的 Alt-Tab 切换器",
            closeQuits: "关闭最后一个窗口即退出 App",
            snapping: "将窗口贴靠到半屏和四角",
            cutPaste: "在访达中剪切和粘贴文件",
            clipboard: "剪贴板历史",
            screenshot: "截图直接进入剪贴板",
            recorder: "屏幕录制",
            quickRing: "鼠标处的快捷环",
            lidClosed: "合上屏幕也继续运行")
        case .zhTW: return GsMacSetupStrings(
            title: "帶著熟悉的 Windows 習慣用 Mac",
            subtitle: "已全部開啟。不需要的可以關掉。",
            start: "開始", changeLater: "之後可隨時在設定中更改。",
            switcher: "App 與視窗的 Alt-Tab 切換器",
            closeQuits: "關閉最後一個視窗即結束 App",
            snapping: "將視窗貼齊到半邊與四角",
            cutPaste: "在 Finder 中剪下並貼上檔案",
            clipboard: "剪貼簿紀錄",
            screenshot: "截圖直接進入剪貼簿",
            recorder: "螢幕錄影",
            quickRing: "滑鼠處的快捷環",
            lidClosed: "闔上螢幕也繼續執行")
        case .zhHK: return GsMacSetupStrings(
            title: "帶著熟悉的 Windows 習慣用 Mac",
            subtitle: "已全部開啟。不需要的可以關掉。",
            start: "開始", changeLater: "之後可隨時在設定中更改。",
            switcher: "App 與視窗的 Alt-Tab 切換器",
            closeQuits: "關閉最後一個視窗即結束 App",
            snapping: "將視窗貼齊到半邊與四角",
            cutPaste: "在 Finder 中剪下並貼上檔案",
            clipboard: "剪貼簿記錄",
            screenshot: "截圖直接進入剪貼簿",
            recorder: "螢幕錄影",
            quickRing: "滑鼠處的快捷環",
            lidClosed: "合上螢幕也繼續運行")
        }
    }
}
