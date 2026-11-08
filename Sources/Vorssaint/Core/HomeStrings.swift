// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

/// Text for the Home page's four groups and the features that had no
/// translated name of their own yet. The other rows reuse the setup names
/// (GsMacSetupStrings), Quick Ring's and the window's own (AvengersStrings).
struct HomeStrings {
    let groupWindows: String
    let groupSharing: String
    let groupCapture: String
    let groupPower: String
    let dockPreview: String
    let sharing: String
    let urlCleaner: String
    let screenOCR: String
    let keepAwake: String
    let keepAwakeNow: String
    let options: String
    let pressKeys: String
    let reset: String

    static let count = 13
}

extension FeatureStrings {
    static func home(_ language: AppLanguage) -> HomeStrings {
        switch language {
        case .enUS: return HomeStrings(
            groupWindows: "Windows habits", groupSharing: "Sharing & clipboard",
            groupCapture: "Screenshot & record", groupPower: "Power",
            dockPreview: "Window previews over the Dock", sharing: "Windows keyboard & mouse",
            urlCleaner: "Clean tracking from copied links", screenOCR: "Copy text from the screen",
            keepAwake: "Keep the Mac awake", keepAwakeNow: "Keep awake now",
            options: "Options", pressKeys: "Press keys…", reset: "Reset")
        case .ptBR: return HomeStrings(
            groupWindows: "Hábitos do Windows", groupSharing: "Compartilhar e área de transferência",
            groupCapture: "Captura", groupPower: "Energia",
            dockPreview: "Pré-visualização de janelas no Dock", sharing: "Teclado e mouse do Windows",
            urlCleaner: "Limpar rastreamento de links copiados", screenOCR: "Copiar texto da tela",
            keepAwake: "Manter o Mac acordado", keepAwakeNow: "Manter acordado agora",
            options: "Opções", pressKeys: "Pressione as teclas…", reset: "Redefinir")
        case .tr: return HomeStrings(
            groupWindows: "Windows alışkanlıkları", groupSharing: "Paylaşım ve pano",
            groupCapture: "Yakalama", groupPower: "Güç",
            dockPreview: "Dock üzerinde pencere önizlemeleri", sharing: "Windows klavye ve faresi",
            urlCleaner: "Kopyalanan bağlantılardan izlemeyi temizle", screenOCR: "Ekrandan metin kopyala",
            keepAwake: "Mac’i uyanık tut", keepAwakeNow: "Şimdi uyanık tut",
            options: "Seçenekler", pressKeys: "Tuşlara basın…", reset: "Sıfırla")
        case .ru: return HomeStrings(
            groupWindows: "Привычки Windows", groupSharing: "Общий доступ и буфер обмена",
            groupCapture: "Снимки и запись", groupPower: "Питание",
            dockPreview: "Превью окон над Dock", sharing: "Клавиатура и мышь Windows",
            urlCleaner: "Убирать отслеживание из скопированных ссылок", screenOCR: "Копировать текст с экрана",
            keepAwake: "Не давать Mac засыпать", keepAwakeNow: "Не засыпать сейчас",
            options: "Параметры", pressKeys: "Нажмите клавиши…", reset: "Сбросить")
        case .es: return HomeStrings(
            groupWindows: "Hábitos de Windows", groupSharing: "Compartir y portapapeles",
            groupCapture: "Captura", groupPower: "Energía",
            dockPreview: "Vista previa de ventanas sobre el Dock", sharing: "Teclado y ratón de Windows",
            urlCleaner: "Quitar el rastreo de los enlaces copiados", screenOCR: "Copiar texto de la pantalla",
            keepAwake: "Mantener el Mac despierto", keepAwakeNow: "Mantener despierto ahora",
            options: "Opciones", pressKeys: "Pulsa las teclas…", reset: "Restablecer")
        case .sk: return HomeStrings(
            groupWindows: "Zvyky z Windows", groupSharing: "Zdieľanie a schránka",
            groupCapture: "Snímanie", groupPower: "Napájanie",
            dockPreview: "Náhľady okien nad Dockom", sharing: "Klávesnica a myš z Windows",
            urlCleaner: "Čistiť sledovanie z kopírovaných odkazov", screenOCR: "Kopírovať text z obrazovky",
            keepAwake: "Udržať Mac zapnutý", keepAwakeNow: "Udržať zapnutý teraz",
            options: "Možnosti", pressKeys: "Stlačte klávesy…", reset: "Obnoviť")
        case .de: return HomeStrings(
            groupWindows: "Windows-Gewohnheiten", groupSharing: "Teilen & Zwischenablage",
            groupCapture: "Aufnahme", groupPower: "Energie",
            dockPreview: "Fenstervorschau über dem Dock", sharing: "Windows-Tastatur & -Maus",
            urlCleaner: "Tracking aus kopierten Links entfernen", screenOCR: "Text vom Bildschirm kopieren",
            keepAwake: "Mac wach halten", keepAwakeNow: "Jetzt wach halten",
            options: "Optionen", pressKeys: "Tasten drücken…", reset: "Zurücksetzen")
        case .fr: return HomeStrings(
            groupWindows: "Habitudes Windows", groupSharing: "Partage et presse-papiers",
            groupCapture: "Capture", groupPower: "Énergie",
            dockPreview: "Aperçu des fenêtres au-dessus du Dock", sharing: "Clavier et souris Windows",
            urlCleaner: "Nettoyer le pistage des liens copiés", screenOCR: "Copier le texte de l’écran",
            keepAwake: "Garder le Mac éveillé", keepAwakeNow: "Garder éveillé maintenant",
            options: "Options", pressKeys: "Appuyez sur les touches…", reset: "Réinitialiser")
        case .it: return HomeStrings(
            groupWindows: "Abitudini di Windows", groupSharing: "Condivisione e appunti",
            groupCapture: "Cattura", groupPower: "Energia",
            dockPreview: "Anteprima finestre sopra il Dock", sharing: "Tastiera e mouse di Windows",
            urlCleaner: "Pulisci il tracciamento dai link copiati", screenOCR: "Copia testo dallo schermo",
            keepAwake: "Tieni sveglio il Mac", keepAwakeNow: "Tieni sveglio ora",
            options: "Opzioni", pressKeys: "Premi i tasti…", reset: "Ripristina")
        case .ja: return HomeStrings(
            groupWindows: "Windowsの習慣", groupSharing: "共有とクリップボード",
            groupCapture: "キャプチャ", groupPower: "電源",
            dockPreview: "Dock上のウインドウプレビュー", sharing: "Windowsのキーボードとマウス",
            urlCleaner: "コピーしたリンクから追跡を削除", screenOCR: "画面のテキストをコピー",
            keepAwake: "Macをスリープさせない", keepAwakeNow: "今すぐスリープを防ぐ",
            options: "オプション", pressKeys: "キーを押してください…", reset: "リセット")
        case .ko: return HomeStrings(
            groupWindows: "Windows 습관", groupSharing: "공유 및 클립보드",
            groupCapture: "캡처", groupPower: "전원",
            dockPreview: "Dock 위 윈도우 미리보기", sharing: "Windows 키보드 및 마우스",
            urlCleaner: "복사한 링크에서 추적 제거", screenOCR: "화면의 텍스트 복사",
            keepAwake: "Mac 깨어 있게 유지", keepAwakeNow: "지금 깨어 있게 유지",
            options: "옵션", pressKeys: "키를 누르세요…", reset: "재설정")
        case .uk: return HomeStrings(
            groupWindows: "Звички Windows", groupSharing: "Спільний доступ і буфер обміну",
            groupCapture: "Знімки й запис", groupPower: "Живлення",
            dockPreview: "Попередній перегляд вікон над Dock", sharing: "Клавіатура й миша Windows",
            urlCleaner: "Прибирати стеження зі скопійованих посилань", screenOCR: "Копіювати текст з екрана",
            keepAwake: "Не давати Mac засинати", keepAwakeNow: "Не засинати зараз",
            options: "Параметри", pressKeys: "Натисніть клавіші…", reset: "Скинути")
        case .zhHans: return HomeStrings(
            groupWindows: "Windows 习惯", groupSharing: "共享与剪贴板",
            groupCapture: "截取", groupPower: "电源",
            dockPreview: "程序坞上方的窗口预览", sharing: "Windows 键盘和鼠标",
            urlCleaner: "清除复制链接中的跟踪参数", screenOCR: "复制屏幕上的文字",
            keepAwake: "让 Mac 保持唤醒", keepAwakeNow: "立即保持唤醒",
            options: "选项", pressKeys: "请按下按键…", reset: "还原")
        case .zhTW: return HomeStrings(
            groupWindows: "Windows 習慣", groupSharing: "共享與剪貼簿",
            groupCapture: "擷取", groupPower: "電源",
            dockPreview: "Dock 上方的視窗預覽", sharing: "Windows 鍵盤和滑鼠",
            urlCleaner: "清除拷貝連結中的追蹤參數", screenOCR: "拷貝螢幕上的文字",
            keepAwake: "讓 Mac 保持喚醒", keepAwakeNow: "立即保持喚醒",
            options: "選項", pressKeys: "請按下按鍵…", reset: "重置")
        case .zhHK: return HomeStrings(
            groupWindows: "Windows 習慣", groupSharing: "共享與剪貼簿",
            groupCapture: "擷取", groupPower: "電源",
            dockPreview: "Dock 上方的視窗預覽", sharing: "Windows 鍵盤和滑鼠",
            urlCleaner: "清除複製連結中的追蹤參數", screenOCR: "複製螢幕上的文字",
            keepAwake: "讓 Mac 保持喚醒", keepAwakeNow: "立即保持喚醒",
            options: "選項", pressKeys: "請按下按鍵…", reset: "重設")
        }
    }
}
