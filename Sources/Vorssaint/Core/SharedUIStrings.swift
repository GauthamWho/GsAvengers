// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import Foundation

/// A few words several pages share: the reorder hint under tiles, the way to
/// the Features page, a layout heading and the camera’s retry message.
struct SharedUIStrings {
    let layout: String
    let reorderHint: String
    let openFeatures: String
    let enableFeatureFormat: String
    let cameraUnavailable: String
    let startCamera: String

    /// What an option says while the feature it needs is uninstalled.
    func enableFeature(_ title: String) -> String { String(format: enableFeatureFormat, title) }
}

extension FeatureStrings {
    static func shared(_ language: AppLanguage) -> SharedUIStrings {
        switch language {
        case .enUS: return SharedUIStrings(
            layout: "Layout", reorderHint: "Drag to reorder. Click the checkmark to show or hide.",
            openFeatures: "Open Features", enableFeatureFormat: "Enable “%@” in Features.",
            cameraUnavailable: "The camera could not start. Try opening it again.",
            startCamera: "Open camera")
        case .ptBR: return SharedUIStrings(
            layout: "Layout", reorderHint: "Arraste para reordenar. Clique na marca para mostrar ou ocultar.",
            openFeatures: "Abrir Recursos", enableFeatureFormat: "Ative “%@” em Recursos.",
            cameraUnavailable: "Não foi possível iniciar a câmera. Tente abri-la novamente.",
            startCamera: "Abrir câmera")
        case .es: return SharedUIStrings(
            layout: "Diseño", reorderHint: "Arrastra para ordenar. Pulsa la marca para mostrar u ocultar.",
            openFeatures: "Abrir Funciones", enableFeatureFormat: "Activa “%@” en Funciones.",
            cameraUnavailable: "No se pudo iniciar la cámara. Intenta abrirla de nuevo.",
            startCamera: "Abrir cámara")
        case .sk: return SharedUIStrings(
            layout: "Rozloženie", reorderHint: "Presunutím zmeníte poradie. Kliknutím na fajku zobrazíte alebo skryjete.",
            openFeatures: "Otvoriť Funkcie", enableFeatureFormat: "Zapnite „%@“ vo Funkciách.",
            cameraUnavailable: "Kameru sa nepodarilo spustiť. Skúste ju otvoriť znova.",
            startCamera: "Otvoriť kameru")
        case .de: return SharedUIStrings(
            layout: "Layout", reorderHint: "Zum Sortieren ziehen. Mit dem Häkchen ein- oder ausblenden.",
            openFeatures: "Funktionen öffnen", enableFeatureFormat: "Aktiviere „%@“ unter Funktionen.",
            cameraUnavailable: "Die Kamera konnte nicht starten. Versuche, sie erneut zu öffnen.",
            startCamera: "Kamera öffnen")
        case .fr: return SharedUIStrings(
            layout: "Disposition", reorderHint: "Glissez pour réordonner. Cliquez sur la coche pour afficher ou masquer.",
            openFeatures: "Ouvrir Fonctionnalités", enableFeatureFormat: "Activez « %@ » dans Fonctionnalités.",
            cameraUnavailable: "La caméra n’a pas pu démarrer. Essayez de l’ouvrir à nouveau.",
            startCamera: "Ouvrir la caméra")
        case .it: return SharedUIStrings(
            layout: "Layout", reorderHint: "Trascina per riordinare. Fai clic sulla spunta per mostrare o nascondere.",
            openFeatures: "Apri Funzioni", enableFeatureFormat: "Attiva “%@” in Funzioni.",
            cameraUnavailable: "Impossibile avviare la fotocamera. Prova ad aprirla di nuovo.",
            startCamera: "Apri fotocamera")
        case .ru: return SharedUIStrings(
            layout: "Макет", reorderHint: "Перетащите для сортировки. Нажмите галочку, чтобы показать или скрыть.",
            openFeatures: "Открыть функции", enableFeatureFormat: "Включите «%@» в разделе функций.",
            cameraUnavailable: "Не удалось запустить камеру. Попробуйте открыть её снова.",
            startCamera: "Открыть камеру")
        case .tr: return SharedUIStrings(
            layout: "Yerleşim", reorderHint: "Sıralamak için sürükleyin. Göstermek veya gizlemek için onay işaretine tıklayın.",
            openFeatures: "Özellikler’i aç", enableFeatureFormat: "Özellikler’de “%@” özelliğini etkinleştirin.",
            cameraUnavailable: "Kamera başlatılamadı. Yeniden açmayı deneyin.",
            startCamera: "Kamerayı aç")
        case .ja: return SharedUIStrings(
            layout: "レイアウト", reorderHint: "ドラッグして並べ替え、チェックマークで表示を切り替えます。",
            openFeatures: "機能を開く", enableFeatureFormat: "機能で「%@」を有効にしてください。",
            cameraUnavailable: "カメラを開始できませんでした。もう一度開いてください。",
            startCamera: "カメラを開く")
        case .ko: return SharedUIStrings(
            layout: "레이아웃", reorderHint: "드래그하여 순서를 바꾸고 체크 표시로 표시 여부를 바꾸세요.",
            openFeatures: "기능 열기", enableFeatureFormat: "기능에서 “%@”을(를) 활성화하세요.",
            cameraUnavailable: "카메라를 시작할 수 없습니다. 다시 열어 보세요.",
            startCamera: "카메라 열기")
        case .zhHans: return SharedUIStrings(
            layout: "布局", reorderHint: "拖动以排序。点击勾选标记来显示或隐藏。",
            openFeatures: "打开功能", enableFeatureFormat: "在功能中启用“%@”。",
            cameraUnavailable: "无法启动摄像头，请尝试重新打开。",
            startCamera: "打开摄像头")
        case .zhTW: return SharedUIStrings(
            layout: "佈局", reorderHint: "拖移以排序。按一下勾選標記來顯示或隱藏。",
            openFeatures: "開啟功能", enableFeatureFormat: "在功能中啟用「%@」。",
            cameraUnavailable: "無法啟動相機，請嘗試重新打開。",
            startCamera: "打開相機")
        case .zhHK: return SharedUIStrings(
            layout: "佈局", reorderHint: "拖移以排序。按一下勾選標記來顯示或隱藏。",
            openFeatures: "開啟功能", enableFeatureFormat: "在功能中啟用「%@」。",
            cameraUnavailable: "無法啟動相機，請嘗試重新開啟。",
            startCamera: "開啟相機")
        case .uk: return SharedUIStrings(
            layout: "Розкладка", reorderHint: "Перетягуйте, щоб змінити порядок. Натисніть галочку, щоб показати або сховати.",
            openFeatures: "Відкрити Функції", enableFeatureFormat: "Увімкніть «%@» у Функціях.",
            cameraUnavailable: "Не вдалося запустити камеру. Спробуйте відкрити її знову.",
            startCamera: "Відкрити камеру")
        }
    }
}
