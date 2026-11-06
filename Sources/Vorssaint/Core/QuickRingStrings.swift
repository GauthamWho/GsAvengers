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
    let controlClick: String
    let controlClickCaption: String
    let middleClick: String
    let middleClickCaption: String
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
            controlClick: "⌃ Control-click",
            controlClickCaption: "Control-click no longer acts as a right-click while this is on. Two-finger clicks still do.",
            middleClick: "Middle mouse button",
            middleClickCaption: "Apps no longer receive the middle click while this is on.",
            tryIt: "Show the ring",
            capture: "Capture", record: "Record", stop: "Stop", clipboard: "Clipboard", windows: "Windows")
        case .ptBR: return QuickRingStrings(
            title: "Anel rápido",
            hubDescription: "Um anel de ações rápidas que abre em volta do ponteiro do mouse.",
            triggersCaption: "Experimente cada forma de abrir e fique com as que preferir. Esc, um clique fora ou afastar o ponteiro fecha; 1–4 escolhem uma ação.",
            controlDoubleTap: "Toque duplo em ⌃ Control",
            controlClick: "⌃ Control + clique",
            controlClickCaption: "Com isto ativado, Control + clique deixa de funcionar como clique direito. O clique com dois dedos continua.",
            middleClick: "Botão do meio do mouse",
            middleClickCaption: "Com isto ativado, os apps deixam de receber o clique do meio.",
            tryIt: "Mostrar o anel",
            capture: "Capturar", record: "Gravar", stop: "Parar", clipboard: "Copiados", windows: "Janelas")
        case .tr: return QuickRingStrings(
            title: "Hızlı Halka",
            hubDescription: "Fare imlecinin hemen çevresinde açılan hızlı işlem halkası.",
            triggersCaption: "Her açılış yolunu deneyin, beğendiklerinizi tutun. Esc, dışarı tıklama ya da uzaklaşma kapatır; 1–4 bir işlem seçer.",
            controlDoubleTap: "⌃ Control’e iki kez dokun",
            controlClick: "⌃ Control + tıklama",
            controlClickCaption: "Bu açıkken Control + tıklama sağ tıklama yerine geçmez. İki parmakla tıklama çalışmaya devam eder.",
            middleClick: "Farenin orta düğmesi",
            middleClickCaption: "Bu açıkken uygulamalar orta tıklamayı almaz.",
            tryIt: "Halkayı göster",
            capture: "Yakala", record: "Kaydet", stop: "Durdur", clipboard: "Pano", windows: "Pencereler")
        case .ru: return QuickRingStrings(
            title: "Быстрое кольцо",
            hubDescription: "Кольцо быстрых действий, которое открывается прямо вокруг указателя.",
            triggersCaption: "Попробуйте каждый способ открытия и оставьте удобные. Esc, щелчок вне кольца или уход указателя закрывают его; 1–4 выбирают действие.",
            controlDoubleTap: "Двойное нажатие ⌃ Control",
            controlClick: "⌃ Control + щелчок",
            controlClickCaption: "Пока это включено, Control + щелчок не работает как правый щелчок. Щелчок двумя пальцами работает.",
            middleClick: "Средняя кнопка мыши",
            middleClickCaption: "Пока это включено, приложения не получают средний щелчок.",
            tryIt: "Показать кольцо",
            capture: "Снимок", record: "Запись", stop: "Стоп", clipboard: "Буфер", windows: "Окна")
        case .es: return QuickRingStrings(
            title: "Anillo rápido",
            hubDescription: "Un anillo de acciones rápidas que se abre justo alrededor del puntero.",
            triggersCaption: "Prueba cada forma de abrirlo y quédate con las que te gusten. Esc, un clic fuera o alejar el puntero lo cierra; 1–4 eligen una acción.",
            controlDoubleTap: "Doble toque en ⌃ Control",
            controlClick: "⌃ Control + clic",
            controlClickCaption: "Con esto activado, Control + clic deja de hacer clic derecho. El clic con dos dedos sigue funcionando.",
            middleClick: "Botón central del ratón",
            middleClickCaption: "Con esto activado, las apps dejan de recibir el clic central.",
            tryIt: "Mostrar el anillo",
            capture: "Capturar", record: "Grabar", stop: "Detener", clipboard: "Copiados", windows: "Ventanas")
        case .sk: return QuickRingStrings(
            title: "Rýchly kruh",
            hubDescription: "Kruh rýchlych akcií, ktorý sa otvorí priamo okolo kurzora myši.",
            triggersCaption: "Vyskúšajte každý spôsob otvorenia a nechajte si tie, ktoré vám vyhovujú. Esc, klik mimo alebo odchod kurzora ho zatvorí; 1–4 vyberú akciu.",
            controlDoubleTap: "Dvojité ťuknutie na ⌃ Control",
            controlClick: "⌃ Control + klik",
            controlClickCaption: "Keď je toto zapnuté, Control + klik už nefunguje ako pravý klik. Klik dvoma prstami áno.",
            middleClick: "Stredné tlačidlo myši",
            middleClickCaption: "Keď je toto zapnuté, apky stredný klik nedostanú.",
            tryIt: "Ukázať kruh",
            capture: "Snímka", record: "Nahrať", stop: "Stop", clipboard: "Schránka", windows: "Okná")
        case .de: return QuickRingStrings(
            title: "Schnellring",
            hubDescription: "Ein Ring mit Schnellaktionen, der sich direkt um den Mauszeiger öffnet.",
            triggersCaption: "Probier jede Art zu öffnen aus und behalte, was dir gefällt. Esc, ein Klick daneben oder Wegbewegen schließt ihn; 1–4 wählen eine Aktion.",
            controlDoubleTap: "⌃ Control doppelt tippen",
            controlClick: "⌃ Control-Klick",
            controlClickCaption: "Solange das an ist, wirkt Control-Klick nicht mehr als Rechtsklick. Zwei-Finger-Klicks schon.",
            middleClick: "Mittlere Maustaste",
            middleClickCaption: "Solange das an ist, bekommen Apps den Mittelklick nicht mehr.",
            tryIt: "Ring zeigen",
            capture: "Foto", record: "Aufnahme", stop: "Stopp", clipboard: "Ablage", windows: "Fenster")
        case .fr: return QuickRingStrings(
            title: "Anneau rapide",
            hubDescription: "Un anneau d’actions rapides qui s’ouvre tout autour du pointeur.",
            triggersCaption: "Essayez chaque façon de l’ouvrir et gardez celles qui vous plaisent. Échap, un clic à côté ou s’éloigner le ferme ; 1–4 choisissent une action.",
            controlDoubleTap: "Toucher deux fois ⌃ Contrôle",
            controlClick: "⌃ Contrôle + clic",
            controlClickCaption: "Tant que c’est activé, Contrôle + clic ne fait plus de clic droit. Le clic à deux doigts, si.",
            middleClick: "Bouton central de la souris",
            middleClickCaption: "Tant que c’est activé, les apps ne reçoivent plus le clic central.",
            tryIt: "Afficher l’anneau",
            capture: "Capture", record: "Filmer", stop: "Arrêter", clipboard: "Copies", windows: "Fenêtres")
        case .it: return QuickRingStrings(
            title: "Anello rapido",
            hubDescription: "Un anello di azioni rapide che si apre proprio intorno al puntatore.",
            triggersCaption: "Prova ogni modo di aprirlo e tieni quelli che preferisci. Esc, un clic fuori o allontanarsi lo chiude; 1–4 scelgono un’azione.",
            controlDoubleTap: "Doppio tocco su ⌃ Control",
            controlClick: "⌃ Control + clic",
            controlClickCaption: "Con questa opzione attiva, Control + clic non fa più il clic destro. Il clic a due dita sì.",
            middleClick: "Tasto centrale del mouse",
            middleClickCaption: "Con questa opzione attiva, le app non ricevono più il clic centrale.",
            tryIt: "Mostra l’anello",
            capture: "Cattura", record: "Registra", stop: "Ferma", clipboard: "Appunti", windows: "Finestre")
        case .ja: return QuickRingStrings(
            title: "クイックリング",
            hubDescription: "マウスポインタのすぐ周りに開く、クイック操作のリングです。",
            triggersCaption: "それぞれの開き方を試して、気に入ったものを残してください。Esc、外側のクリック、ポインタを離すと閉じます。1〜4 で操作を選べます。",
            controlDoubleTap: "⌃ Control を2回タップ",
            controlClick: "⌃ Control + クリック",
            controlClickCaption: "オンの間、Control + クリックは右クリックとして働きません。2本指クリックは使えます。",
            middleClick: "マウスの中ボタン",
            middleClickCaption: "オンの間、アプリは中クリックを受け取りません。",
            tryIt: "リングを表示",
            capture: "撮影", record: "録画", stop: "停止", clipboard: "クリップ", windows: "ウインドウ")
        case .ko: return QuickRingStrings(
            title: "퀵 링",
            hubDescription: "마우스 포인터 바로 주위에 열리는 빠른 동작 링입니다.",
            triggersCaption: "여는 방법을 하나씩 써 보고 마음에 드는 것만 남기세요. Esc, 바깥 클릭, 포인터를 멀리 옮기면 닫힙니다. 1–4로 동작을 고릅니다.",
            controlDoubleTap: "⌃ Control 두 번 탭",
            controlClick: "⌃ Control + 클릭",
            controlClickCaption: "켜져 있는 동안 Control + 클릭은 오른쪽 클릭으로 동작하지 않습니다. 두 손가락 클릭은 그대로입니다.",
            middleClick: "마우스 가운데 버튼",
            middleClickCaption: "켜져 있는 동안 앱은 가운데 클릭을 받지 않습니다.",
            tryIt: "링 보기",
            capture: "캡처", record: "녹화", stop: "중지", clipboard: "클립보드", windows: "창")
        case .uk: return QuickRingStrings(
            title: "Швидке кільце",
            hubDescription: "Кільце швидких дій, що відкривається просто навколо вказівника.",
            triggersCaption: "Спробуйте кожен спосіб відкриття і залиште зручні. Esc, клацання поза кільцем або відведення вказівника закривають його; 1–4 вибирають дію.",
            controlDoubleTap: "Подвійне натискання ⌃ Control",
            controlClick: "⌃ Control + клацання",
            controlClickCaption: "Поки це ввімкнено, Control + клацання не працює як правий клік. Клацання двома пальцями працює.",
            middleClick: "Середня кнопка миші",
            middleClickCaption: "Поки це ввімкнено, програми не отримують середнє клацання.",
            tryIt: "Показати кільце",
            capture: "Знімок", record: "Запис", stop: "Стоп", clipboard: "Буфер", windows: "Вікна")
        case .zhHans: return QuickRingStrings(
            title: "快捷环",
            hubDescription: "在鼠标指针周围打开的一圈快捷操作。",
            triggersCaption: "逐一试试各种打开方式，留下喜欢的。按 Esc、点击外面或移开指针即可关闭；按 1–4 选择操作。",
            controlDoubleTap: "连按两下 ⌃ Control",
            controlClick: "⌃ Control + 点按",
            controlClickCaption: "开启后，Control + 点按不再作为右键点按。双指点按仍然可用。",
            middleClick: "鼠标中键",
            middleClickCaption: "开启后，App 将不再收到中键点按。",
            tryIt: "显示快捷环",
            capture: "截图", record: "录屏", stop: "停止", clipboard: "剪贴板", windows: "窗口")
        case .zhTW: return QuickRingStrings(
            title: "快捷環",
            hubDescription: "在滑鼠指標周圍打開的一圈快捷動作。",
            triggersCaption: "逐一試試各種打開方式，留下喜歡的。按 Esc、按一下外面或移開指標即可關閉；按 1–4 選擇動作。",
            controlDoubleTap: "連按兩下 ⌃ Control",
            controlClick: "⌃ Control + 按一下",
            controlClickCaption: "開啟後，Control + 按一下不再當作右鍵。雙指按一下仍可使用。",
            middleClick: "滑鼠中鍵",
            middleClickCaption: "開啟後，App 將不再收到中鍵按一下。",
            tryIt: "顯示快捷環",
            capture: "截圖", record: "錄影", stop: "停止", clipboard: "剪貼簿", windows: "視窗")
        case .zhHK: return QuickRingStrings(
            title: "快捷環",
            hubDescription: "在滑鼠指標周圍打開的一圈快捷動作。",
            triggersCaption: "逐一試試各種打開方式，留下喜歡的。按 Esc、按一下外面或移開指標即可關閉；按 1–4 選擇動作。",
            controlDoubleTap: "連按兩下 ⌃ Control",
            controlClick: "⌃ Control + 按一下",
            controlClickCaption: "開啟後，Control + 按一下不再當作右鍵。雙指按一下仍可使用。",
            middleClick: "滑鼠中鍵",
            middleClickCaption: "開啟後，App 將不再收到中鍵按一下。",
            tryIt: "顯示快捷環",
            capture: "截圖", record: "錄影", stop: "停止", clipboard: "剪貼簿", windows: "視窗")
        }
    }
}
