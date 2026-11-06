// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Mac)

import Foundation

/// Quick Ring: a round glass ring of actions that opens around the pointer.
/// Self-contained, so the ring can move to another app on its own.
struct QuickRingStrings {
    let title: String
    let hubDescription: String
    let triggersCaption: String
    let controlDoubleTap: String
    let tryIt: String
    /// One short word each: they sit at 9 pt under the ring's icons.
    let capture: String
    let record: String
    let stop: String
    let clipboard: String
    let windows: String
}

extension FeatureStrings {
    static func quickRing(_ language: AppLanguage) -> QuickRingStrings {
        switch language {
        case .enUS: return QuickRingStrings(
            title: "Quick Ring",
            hubDescription: "A ring of quick actions that opens right around the mouse pointer.",
            triggersCaption: "Try each way of opening it and keep the ones you like. Esc, a click outside or moving away closes it; 1–4 pick an action.",
            controlDoubleTap: "Double-tap ⌃ Control",
            tryIt: "Show the ring",
            capture: "Capture", record: "Record", stop: "Stop", clipboard: "Clipboard", windows: "Windows")
        case .ptBR: return QuickRingStrings(
            title: "Anel rápido",
            hubDescription: "Um anel de ações rápidas que abre em volta do ponteiro do mouse.",
            triggersCaption: "Experimente cada forma de abrir e fique com as que preferir. Esc, um clique fora ou afastar o ponteiro fecha; 1–4 escolhem uma ação.",
            controlDoubleTap: "Toque duplo em ⌃ Control",
            tryIt: "Mostrar o anel",
            capture: "Capturar", record: "Gravar", stop: "Parar", clipboard: "Copiados", windows: "Janelas")
        case .tr: return QuickRingStrings(
            title: "Hızlı Halka",
            hubDescription: "Fare imlecinin hemen çevresinde açılan hızlı işlem halkası.",
            triggersCaption: "Her açılış yolunu deneyin, beğendiklerinizi tutun. Esc, dışarı tıklama ya da uzaklaşma kapatır; 1–4 bir işlem seçer.",
            controlDoubleTap: "⌃ Control’e iki kez dokun",
            tryIt: "Halkayı göster",
            capture: "Yakala", record: "Kaydet", stop: "Durdur", clipboard: "Pano", windows: "Pencereler")
        case .ru: return QuickRingStrings(
            title: "Быстрое кольцо",
            hubDescription: "Кольцо быстрых действий, которое открывается прямо вокруг указателя.",
            triggersCaption: "Попробуйте каждый способ открытия и оставьте удобные. Esc, щелчок вне кольца или уход указателя закрывают его; 1–4 выбирают действие.",
            controlDoubleTap: "Двойное нажатие ⌃ Control",
            tryIt: "Показать кольцо",
            capture: "Снимок", record: "Запись", stop: "Стоп", clipboard: "Буфер", windows: "Окна")
        case .es: return QuickRingStrings(
            title: "Anillo rápido",
            hubDescription: "Un anillo de acciones rápidas que se abre justo alrededor del puntero.",
            triggersCaption: "Prueba cada forma de abrirlo y quédate con las que te gusten. Esc, un clic fuera o alejar el puntero lo cierra; 1–4 eligen una acción.",
            controlDoubleTap: "Doble toque en ⌃ Control",
            tryIt: "Mostrar el anillo",
            capture: "Capturar", record: "Grabar", stop: "Detener", clipboard: "Copiados", windows: "Ventanas")
        case .sk: return QuickRingStrings(
            title: "Rýchly kruh",
            hubDescription: "Kruh rýchlych akcií, ktorý sa otvorí priamo okolo kurzora myši.",
            triggersCaption: "Vyskúšajte každý spôsob otvorenia a nechajte si tie, ktoré vám vyhovujú. Esc, klik mimo alebo odchod kurzora ho zatvorí; 1–4 vyberú akciu.",
            controlDoubleTap: "Dvojité ťuknutie na ⌃ Control",
            tryIt: "Ukázať kruh",
            capture: "Snímka", record: "Nahrať", stop: "Stop", clipboard: "Schránka", windows: "Okná")
        case .de: return QuickRingStrings(
            title: "Schnellring",
            hubDescription: "Ein Ring mit Schnellaktionen, der sich direkt um den Mauszeiger öffnet.",
            triggersCaption: "Probier jede Art zu öffnen aus und behalte, was dir gefällt. Esc, ein Klick daneben oder Wegbewegen schließt ihn; 1–4 wählen eine Aktion.",
            controlDoubleTap: "⌃ Control doppelt tippen",
            tryIt: "Ring zeigen",
            capture: "Foto", record: "Aufnahme", stop: "Stopp", clipboard: "Ablage", windows: "Fenster")
        case .fr: return QuickRingStrings(
            title: "Anneau rapide",
            hubDescription: "Un anneau d’actions rapides qui s’ouvre tout autour du pointeur.",
            triggersCaption: "Essayez chaque façon de l’ouvrir et gardez celles qui vous plaisent. Échap, un clic à côté ou s’éloigner le ferme ; 1–4 choisissent une action.",
            controlDoubleTap: "Toucher deux fois ⌃ Contrôle",
            tryIt: "Afficher l’anneau",
            capture: "Capture", record: "Filmer", stop: "Arrêter", clipboard: "Copies", windows: "Fenêtres")
        case .it: return QuickRingStrings(
            title: "Anello rapido",
            hubDescription: "Un anello di azioni rapide che si apre proprio intorno al puntatore.",
            triggersCaption: "Prova ogni modo di aprirlo e tieni quelli che preferisci. Esc, un clic fuori o allontanarsi lo chiude; 1–4 scelgono un’azione.",
            controlDoubleTap: "Doppio tocco su ⌃ Control",
            tryIt: "Mostra l’anello",
            capture: "Cattura", record: "Registra", stop: "Ferma", clipboard: "Appunti", windows: "Finestre")
        case .ja: return QuickRingStrings(
            title: "クイックリング",
            hubDescription: "マウスポインタのすぐ周りに開く、クイック操作のリングです。",
            triggersCaption: "それぞれの開き方を試して、気に入ったものを残してください。Esc、外側のクリック、ポインタを離すと閉じます。1〜4 で操作を選べます。",
            controlDoubleTap: "⌃ Control を2回タップ",
            tryIt: "リングを表示",
            capture: "撮影", record: "録画", stop: "停止", clipboard: "クリップ", windows: "ウインドウ")
        case .ko: return QuickRingStrings(
            title: "퀵 링",
            hubDescription: "마우스 포인터 바로 주위에 열리는 빠른 동작 링입니다.",
            triggersCaption: "여는 방법을 하나씩 써 보고 마음에 드는 것만 남기세요. Esc, 바깥 클릭, 포인터를 멀리 옮기면 닫힙니다. 1–4로 동작을 고릅니다.",
            controlDoubleTap: "⌃ Control 두 번 탭",
            tryIt: "링 보기",
            capture: "캡처", record: "녹화", stop: "중지", clipboard: "클립보드", windows: "창")
        case .uk: return QuickRingStrings(
            title: "Швидке кільце",
            hubDescription: "Кільце швидких дій, що відкривається просто навколо вказівника.",
            triggersCaption: "Спробуйте кожен спосіб відкриття і залиште зручні. Esc, клацання поза кільцем або відведення вказівника закривають його; 1–4 вибирають дію.",
            controlDoubleTap: "Подвійне натискання ⌃ Control",
            tryIt: "Показати кільце",
            capture: "Знімок", record: "Запис", stop: "Стоп", clipboard: "Буфер", windows: "Вікна")
        case .zhHans: return QuickRingStrings(
            title: "快捷环",
            hubDescription: "在鼠标指针周围打开的一圈快捷操作。",
            triggersCaption: "逐一试试各种打开方式，留下喜欢的。按 Esc、点击外面或移开指针即可关闭；按 1–4 选择操作。",
            controlDoubleTap: "连按两下 ⌃ Control",
            tryIt: "显示快捷环",
            capture: "截图", record: "录屏", stop: "停止", clipboard: "剪贴板", windows: "窗口")
        case .zhTW: return QuickRingStrings(
            title: "快捷環",
            hubDescription: "在滑鼠指標周圍打開的一圈快捷動作。",
            triggersCaption: "逐一試試各種打開方式，留下喜歡的。按 Esc、按一下外面或移開指標即可關閉；按 1–4 選擇動作。",
            controlDoubleTap: "連按兩下 ⌃ Control",
            tryIt: "顯示快捷環",
            capture: "截圖", record: "錄影", stop: "停止", clipboard: "剪貼簿", windows: "視窗")
        case .zhHK: return QuickRingStrings(
            title: "快捷環",
            hubDescription: "在滑鼠指標周圍打開的一圈快捷動作。",
            triggersCaption: "逐一試試各種打開方式，留下喜歡的。按 Esc、按一下外面或移開指標即可關閉；按 1–4 選擇動作。",
            controlDoubleTap: "連按兩下 ⌃ Control",
            tryIt: "顯示快捷環",
            capture: "截圖", record: "錄影", stop: "停止", clipboard: "剪貼簿", windows: "視窗")
        }
    }
}
