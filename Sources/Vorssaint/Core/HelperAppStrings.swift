// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 GauthamWho (G’s Avengers)

/// Menu and Settings text for the two built-in helpers: clipboard history
/// (fn V / fn E) and mouse & keyboard sharing with a Windows PC.
struct HelperAppStrings {
    let clipboardTitle: String
    let openClipboard: String
    let openEmoji: String
    let clipboardSettings: String
    let clipboardCaption: String
    let sharingTitle: String
    let statusConnectedFormat: String
    let statusPairing: String
    let statusSearching: String
    let statusPaused: String
    let statusNotRunning: String
    let pauseSharing: String
    let resumeSharing: String
    let pairShowCode: String
    let keyboardRules: String
    let openSharingWindow: String
    let sharingCaption: String

    /// Fields in declaration order; keeps the 15 translations below compact.
    private init(_ t: [String]) {
        precondition(t.count == 17)
        clipboardTitle = t[0]; openClipboard = t[1]; openEmoji = t[2]; clipboardSettings = t[3]
        clipboardCaption = t[4]; sharingTitle = t[5]; statusConnectedFormat = t[6]; statusPairing = t[7]
        statusSearching = t[8]; statusPaused = t[9]; statusNotRunning = t[10]; pauseSharing = t[11]
        resumeSharing = t[12]; pairShowCode = t[13]; keyboardRules = t[14]; openSharingWindow = t[15]
        sharingCaption = t[16]
    }
}

extension FeatureStrings {
    static func helperApps(_ language: AppLanguage) -> HelperAppStrings {
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

extension HelperAppStrings {
    static let enUS = HelperAppStrings([
        "Clipboard", "Open Clipboard", "Open Emoji", "Clipboard Settings…",
        "fn V opens your clipboard history and fn E opens emoji. Shortcuts, history size and cleanup are set in the clipboard settings.",
        "Sharing (Windows)", "Connected to %@", "Pairing: confirm the code", "Looking for your Windows PC…",
        "Sharing paused", "Not running", "Pause Sharing", "Resume Sharing", "Pair / Show Code…",
        "Keyboard Rules…", "Open Sharing Window…",
        "Pairing, where the Windows PC sits (left, right, above, below) and the Windows keyboard rules are set in the sharing window.",
    ])
    static let ptBR = HelperAppStrings([
        "Área de transferência", "Abrir área de transferência", "Abrir emojis", "Ajustes da área de transferência…",
        "fn V abre o histórico e fn E abre os emojis. Atalhos, tamanho do histórico e limpeza ficam nos ajustes da área de transferência.",
        "Compartilhamento (Windows)", "Conectado a %@", "Pareamento: confirme o código", "Procurando seu PC Windows…",
        "Compartilhamento pausado", "Não está em execução", "Pausar compartilhamento", "Retomar compartilhamento", "Parear / mostrar código…",
        "Regras do teclado…", "Abrir janela de compartilhamento…",
        "Pareamento, posição do PC Windows (esquerda, direita, acima, abaixo) e regras do teclado Windows ficam na janela de compartilhamento.",
    ])
    static let tr = HelperAppStrings([
        "Pano", "Panoyu Aç", "Emojileri Aç", "Pano Ayarları…",
        "fn V pano geçmişini, fn E emojileri açar. Kısayollar, geçmiş boyutu ve temizlik pano ayarlarındadır.",
        "Paylaşım (Windows)", "%@ ile bağlı", "Eşleştirme: kodu onaylayın", "Windows PC’niz aranıyor…",
        "Paylaşım duraklatıldı", "Çalışmıyor", "Paylaşımı Duraklat", "Paylaşımı Sürdür", "Eşleştir / Kodu Göster…",
        "Klavye Kuralları…", "Paylaşım Penceresini Aç…",
        "Eşleştirme, Windows PC’nin konumu (sol, sağ, üst, alt) ve Windows klavye kuralları paylaşım penceresindedir.",
    ])
    static let ru = HelperAppStrings([
        "Буфер обмена", "Открыть буфер обмена", "Открыть эмодзи", "Настройки буфера обмена…",
        "fn V открывает историю буфера, а fn E открывает эмодзи. Сочетания, размер истории и очистка находятся в настройках буфера обмена.",
        "Общий доступ (Windows)", "Подключено к %@", "Сопряжение: подтвердите код", "Поиск вашего ПК с Windows…",
        "Общий доступ приостановлен", "Не запущено", "Приостановить", "Возобновить", "Сопряжение / показать код…",
        "Правила клавиатуры…", "Открыть окно общего доступа…",
        "Сопряжение, положение ПК с Windows (слева, справа, сверху, снизу) и правила клавиатуры Windows находятся в окне общего доступа.",
    ])
    static let es = HelperAppStrings([
        "Portapapeles", "Abrir portapapeles", "Abrir emojis", "Ajustes del portapapeles…",
        "fn V abre el historial y fn E abre los emojis. Atajos, tamaño del historial y limpieza están en los ajustes del portapapeles.",
        "Compartir (Windows)", "Conectado a %@", "Emparejamiento: confirma el código", "Buscando tu PC con Windows…",
        "Compartir en pausa", "No se está ejecutando", "Pausar", "Reanudar", "Emparejar / mostrar código…",
        "Reglas del teclado…", "Abrir ventana de compartir…",
        "El emparejamiento, la posición del PC con Windows (izquierda, derecha, arriba, abajo) y las reglas del teclado de Windows están en la ventana de compartir.",
    ])
    static let sk = HelperAppStrings([
        "Schránka", "Otvoriť schránku", "Otvoriť emoji", "Nastavenia schránky…",
        "fn V otvorí históriu schránky, fn E otvorí emoji. Skratky, veľkosť histórie a čistenie sú v nastaveniach schránky.",
        "Zdieľanie (Windows)", "Pripojené k %@", "Párovanie: potvrďte kód", "Hľadá sa váš počítač s Windows…",
        "Zdieľanie pozastavené", "Nespustené", "Pozastaviť zdieľanie", "Obnoviť zdieľanie", "Spárovať / zobraziť kód…",
        "Pravidlá klávesnice…", "Otvoriť okno zdieľania…",
        "Párovanie, poloha počítača s Windows (vľavo, vpravo, hore, dole) a pravidlá klávesnice Windows sú v okne zdieľania.",
    ])
    static let de = HelperAppStrings([
        "Zwischenablage", "Zwischenablage öffnen", "Emoji öffnen", "Einstellungen der Zwischenablage…",
        "fn V öffnet den Verlauf, fn E die Emoji. Kurzbefehle, Verlaufsgröße und Aufräumen stehen in den Einstellungen der Zwischenablage.",
        "Teilen (Windows)", "Verbunden mit %@", "Kopplung: Code bestätigen", "Suche deinen Windows-PC…",
        "Teilen pausiert", "Läuft nicht", "Teilen pausieren", "Teilen fortsetzen", "Koppeln / Code zeigen…",
        "Tastaturregeln…", "Fenster „Teilen“ öffnen…",
        "Kopplung, Lage des Windows-PCs (links, rechts, oben, unten) und die Windows-Tastaturregeln stehen im Fenster „Teilen“.",
    ])
    static let fr = HelperAppStrings([
        "Presse-papiers", "Ouvrir le presse-papiers", "Ouvrir les emoji", "Réglages du presse-papiers…",
        "fn V ouvre l’historique et fn E les emoji. Raccourcis, taille de l’historique et nettoyage sont dans les réglages du presse-papiers.",
        "Partage (Windows)", "Connecté à %@", "Jumelage : confirmez le code", "Recherche de votre PC Windows…",
        "Partage en pause", "Non lancé", "Mettre le partage en pause", "Reprendre le partage", "Jumeler / afficher le code…",
        "Règles du clavier…", "Ouvrir la fenêtre de partage…",
        "Le jumelage, la position du PC Windows (gauche, droite, haut, bas) et les règles du clavier Windows sont dans la fenêtre de partage.",
    ])
    static let it = HelperAppStrings([
        "Appunti", "Apri appunti", "Apri emoji", "Impostazioni appunti…",
        "fn V apre la cronologia, fn E le emoji. Scorciatoie, dimensione della cronologia e pulizia sono nelle impostazioni degli appunti.",
        "Condivisione (Windows)", "Connesso a %@", "Abbinamento: conferma il codice", "Ricerca del PC Windows…",
        "Condivisione in pausa", "Non in esecuzione", "Metti in pausa", "Riprendi", "Abbina / mostra codice…",
        "Regole tastiera…", "Apri finestra di condivisione…",
        "Abbinamento, posizione del PC Windows (sinistra, destra, sopra, sotto) e regole della tastiera Windows sono nella finestra di condivisione.",
    ])
    static let ja = HelperAppStrings([
        "クリップボード", "クリップボードを開く", "絵文字を開く", "クリップボード設定…",
        "fn V で履歴、fn E で絵文字を開きます。ショートカット、履歴の件数、整理はクリップボード設定で変更できます。",
        "共有 (Windows)", "%@ に接続中", "ペアリング: コードを確認", "Windows PC を検索中…",
        "共有を一時停止中", "実行されていません", "共有を一時停止", "共有を再開", "ペアリング / コードを表示…",
        "キーボードのルール…", "共有ウインドウを開く…",
        "ペアリング、Windows PC の位置 (左・右・上・下)、Windows キーボードのルールは共有ウインドウで設定します。",
    ])
    static let ko = HelperAppStrings([
        "클립보드", "클립보드 열기", "이모지 열기", "클립보드 설정…",
        "fn V는 클립보드 기록, fn E는 이모지를 엽니다. 단축키, 기록 크기, 정리는 클립보드 설정에서 바꿉니다.",
        "공유 (Windows)", "%@에 연결됨", "페어링: 코드를 확인하세요", "Windows PC 찾는 중…",
        "공유 일시 정지됨", "실행 중 아님", "공유 일시 정지", "공유 재개", "페어링 / 코드 보기…",
        "키보드 규칙…", "공유 창 열기…",
        "페어링, Windows PC 위치(왼쪽, 오른쪽, 위, 아래), Windows 키보드 규칙은 공유 창에서 설정합니다.",
    ])
    static let uk = HelperAppStrings([
        "Буфер обміну", "Відкрити буфер обміну", "Відкрити емодзі", "Налаштування буфера обміну…",
        "fn V відкриває історію буфера, а fn E відкриває емодзі. Скорочення, розмір історії та очищення є в налаштуваннях буфера обміну.",
        "Спільний доступ (Windows)", "Підключено до %@", "Спарювання: підтвердьте код", "Пошук вашого ПК з Windows…",
        "Спільний доступ призупинено", "Не запущено", "Призупинити", "Відновити", "Спарувати / показати код…",
        "Правила клавіатури…", "Відкрити вікно спільного доступу…",
        "Спарювання, положення ПК з Windows (ліворуч, праворуч, згори, знизу) і правила клавіатури Windows є у вікні спільного доступу.",
    ])
    static let zhHans = HelperAppStrings([
        "剪贴板", "打开剪贴板", "打开表情", "剪贴板设置…",
        "fn V 打开剪贴板历史，fn E 打开表情。快捷键、历史数量和清理在剪贴板设置中更改。",
        "共享 (Windows)", "已连接到 %@", "配对：请确认代码", "正在查找你的 Windows 电脑…",
        "共享已暂停", "未运行", "暂停共享", "恢复共享", "配对 / 显示代码…",
        "键盘规则…", "打开共享窗口…",
        "配对、Windows 电脑的位置（左、右、上、下）和 Windows 键盘规则在共享窗口中设置。",
    ])
    static let zhTW = HelperAppStrings([
        "剪貼簿", "打開剪貼簿", "打開表情符號", "剪貼簿設定…",
        "fn V 打開剪貼簿記錄，fn E 打開表情符號。快速鍵、記錄數量與清理在剪貼簿設定中更改。",
        "共享 (Windows)", "已連線到 %@", "配對：請確認代碼", "正在尋找你的 Windows 電腦…",
        "共享已暫停", "未執行", "暫停共享", "繼續共享", "配對 / 顯示代碼…",
        "鍵盤規則…", "打開共享視窗…",
        "配對、Windows 電腦的位置（左、右、上、下）與 Windows 鍵盤規則在共享視窗中設定。",
    ])
    static let zhHK = HelperAppStrings([
        "剪貼簿", "打開剪貼簿", "打開表情符號", "剪貼簿設定…",
        "fn V 打開剪貼簿記錄，fn E 打開表情符號。快捷鍵、記錄數量與清理在剪貼簿設定中更改。",
        "共享 (Windows)", "已連線到 %@", "配對：請確認代碼", "正在尋找你的 Windows 電腦…",
        "共享已暫停", "未執行", "暫停共享", "繼續共享", "配對 / 顯示代碼…",
        "鍵盤規則…", "打開共享視窗…",
        "配對、Windows 電腦的位置（左、右、上、下）與 Windows 鍵盤規則在共享視窗中設定。",
    ])
}
