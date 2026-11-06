// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct RecorderShareStrings {
    let caption: String
    let compressing: String
    let uploading: String
    let tooLarge: String
    let failed: String
}

extension FeatureStrings {
    static func recorderShare(_ language: AppLanguage) -> RecorderShareStrings {
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

extension RecorderShareStrings {
    static let enUS = RecorderShareStrings(
        caption: "Choose 1 or 6 hours. The final video is compressed on this Mac to fit under 100 MB and deleted automatically.",
        compressing: "Compressing for sharing…",
        uploading: "Uploading securely…",
        tooLarge: "This recording cannot fit under 100 MB without losing too much quality.",
        failed: "The temporary link could not be created")

    static let ptBR = RecorderShareStrings(
        caption: "Escolha 1 ou 6 horas. O vídeo final é comprimido neste Mac para ficar abaixo de 100 MB e apagado automaticamente.",
        compressing: "Comprimindo para compartilhar…",
        uploading: "Enviando com segurança…",
        tooLarge: "Esta gravação não cabe em 100 MB sem perder qualidade demais.",
        failed: "Não foi possível criar o link temporário")

    static let tr = RecorderShareStrings(
        caption: "1 veya 6 saat seçin. Son video bu Mac’te 100 MB altında kalacak şekilde sıkıştırılır ve otomatik olarak silinir.",
        compressing: "Paylaşım için sıkıştırılıyor…",
        uploading: "Güvenli şekilde yükleniyor…",
        tooLarge: "Bu kayıt, kaliteden çok fazla ödün vermeden 100 MB altına sığmıyor.",
        failed: "Geçici bağlantı oluşturulamadı")

    static let ru = RecorderShareStrings(
        caption: "Выберите 1 или 6 часов. Готовое видео сжимается на этом Mac до размера менее 100 МБ и удаляется автоматически.",
        compressing: "Сжатие для публикации…",
        uploading: "Безопасная отправка…",
        tooLarge: "Эту запись нельзя уменьшить до 100 МБ без слишком большой потери качества.",
        failed: "Не удалось создать временную ссылку")

    static let es = RecorderShareStrings(
        caption: "Elige 1 o 6 horas. El vídeo final se comprime en este Mac para quedar por debajo de 100 MB y se elimina automáticamente.",
        compressing: "Comprimiendo para compartir…",
        uploading: "Subiendo de forma segura…",
        tooLarge: "Esta grabación no cabe en 100 MB sin perder demasiada calidad.",
        failed: "No se pudo crear el enlace temporal")

    static let sk = RecorderShareStrings(
        caption: "Vyberte 1 alebo 6 hodín. Finálne video sa na tomto Macu skomprimuje pod 100 MB a automaticky sa vymaže.",
        compressing: "Komprimuje sa na zdieľanie…",
        uploading: "Bezpečne sa nahráva…",
        tooLarge: "Toto nahrávanie sa nezmestí pod 100 MB bez príliš veľkej straty kvality.",
        failed: "Dočasný odkaz sa nepodarilo vytvoriť")

    static let de = RecorderShareStrings(
        caption: "Wähle 1 oder 6 Stunden. Das fertige Video wird auf diesem Mac auf unter 100 MB komprimiert und automatisch gelöscht.",
        compressing: "Wird zum Teilen komprimiert…",
        uploading: "Wird sicher hochgeladen…",
        tooLarge: "Diese Aufnahme passt nicht ohne zu großen Qualitätsverlust unter 100 MB.",
        failed: "Der temporäre Link konnte nicht erstellt werden")

    static let fr = RecorderShareStrings(
        caption: "Choisissez 1 ou 6 heures. La vidéo finale est compressée sur ce Mac à moins de 100 Mo, puis supprimée automatiquement.",
        compressing: "Compression pour le partage…",
        uploading: "Envoi sécurisé…",
        tooLarge: "Cet enregistrement ne peut pas tenir sous 100 Mo sans perdre trop de qualité.",
        failed: "Impossible de créer le lien temporaire")

    static let it = RecorderShareStrings(
        caption: "Scegli 1 o 6 ore. Il video finale viene compresso su questo Mac sotto i 100 MB ed eliminato automaticamente.",
        compressing: "Compressione per la condivisione…",
        uploading: "Caricamento sicuro…",
        tooLarge: "Questa registrazione non può restare sotto i 100 MB senza perdere troppa qualità.",
        failed: "Impossibile creare il link temporaneo")

    static let ja = RecorderShareStrings(
        caption: "1時間または6時間を選びます。完成した動画はこのMacで100 MB未満に圧縮され、自動的に削除されます。",
        compressing: "共有用に圧縮中…",
        uploading: "安全にアップロード中…",
        tooLarge: "この録画は、品質を大きく落とさずに100 MB未満にできません。",
        failed: "一時リンクを作成できませんでした")

    static let ko = RecorderShareStrings(
        caption: "1시간 또는 6시간을 선택하세요. 완성된 동영상은 이 Mac에서 100MB 미만으로 압축되고 자동으로 삭제됩니다.",
        compressing: "공유용으로 압축 중…",
        uploading: "안전하게 업로드 중…",
        tooLarge: "이 녹화는 품질을 너무 많이 낮추지 않고 100MB 미만으로 만들 수 없습니다.",
        failed: "임시 링크를 만들 수 없습니다")

    static let zhHans = RecorderShareStrings(
        caption: "选择1小时或6小时。最终视频会在这台Mac上压缩到100 MB以内，并自动删除。",
        compressing: "正在压缩以便分享…",
        uploading: "正在安全上传…",
        tooLarge: "这段录制无法在不过度损失画质的情况下压缩到100 MB以内。",
        failed: "无法创建临时链接")

    static let zhTW = RecorderShareStrings(
        caption: "選擇1小時或6小時。最終影片會在這台Mac上壓縮至100 MB以內，並自動刪除。",
        compressing: "正在壓縮以供分享…",
        uploading: "正在安全上傳…",
        tooLarge: "這段錄製無法在不過度損失畫質的情況下壓縮至100 MB以內。",
        failed: "無法建立暫時連結")

    static let zhHK = RecorderShareStrings(
        caption: "選擇1小時或6小時。最終影片會在這部Mac上壓縮至100 MB以內，並自動刪除。",
        compressing: "正在壓縮以供分享…",
        uploading: "正在安全上載…",
        tooLarge: "這段錄製無法在不過度損失畫質的情況下壓縮至100 MB以內。",
        failed: "無法建立暫時連結")
    static let uk = RecorderShareStrings(
        caption: "Виберіть 1 або 6 годин. Фінальне відео стискається на цьому Mac, щоб уміститися в 100 МБ, та видаляється автоматично.",
        compressing: "Стиснення для поширення…",
        uploading: "Безпечне завантаження…",
        tooLarge: "Цей запис не може уміститися в 100 МБ без зайвої втрати якості.",
        failed: "Не вдалося створити тимчасове посилання")
}
