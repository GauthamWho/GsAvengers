// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ImageIO

/// How large a capture is read for text recognition: a screenshot keeps
/// every pixel; only a larger picture (a long scrolling capture) is scaled
/// down to this area to bound its bitmap.
enum ClipboardImageRecognition {
    static let maxPixels = 24_000_000

    /// The longest side to decode a `width` by `height` picture at.
    static func decodeMaxPixelSize(width: Int, height: Int) -> Int {
        let longest = max(width, height, 1)
        let pixels = Double(max(width, 1)) * Double(max(height, 1))
        guard pixels > Double(maxPixels) else { return longest }
        return max(1, Int(Double(longest) * (Double(maxPixels) / pixels).squareRoot()))
    }

    /// The size to scale a picture in memory to, or nil to read it whole.
    static func scaledSize(width: Int, height: Int) -> (width: Int, height: Int)? {
        let longest = max(width, height, 1)
        let side = decodeMaxPixelSize(width: width, height: height)
        guard side < longest else { return nil }
        let shorter = max(1, Int(Double(min(width, height)) * Double(side) / Double(longest)))
        return width >= height ? (width: side, height: shorter) : (width: shorter, height: side)
    }
}

extension NSPasteboard.PasteboardType {
    /// The nspasteboard.org convention naming the app that wrote a copy.
    static let source = NSPasteboard.PasteboardType("org.nspasteboard.source")
    /// Added by the system to a copy that came from another device (Universal Clipboard).
    static let remoteClipboard = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
}

extension NSPasteboard {
    /// Signs a write the app makes for itself (copied OCR text, a capture),
    /// so clipboard history does not credit it to the app in front.
    func declareVorssaintSource() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        setString(bundleID, forType: .source)
    }
}

/// Text recognition languages for the app's language, English as fallback.
enum MediaSupport {
    static func recognitionLanguages(for languageRawValue: String) -> [String] {
        switch languageRawValue {
        case "pt-BR": return ["pt-BR", "en-US"]
        case "tr": return ["tr-TR", "en-US"]
        case "ru": return ["ru-RU", "en-US"]
        case "es": return ["es-ES", "en-US"]
        case "de": return ["de-DE", "en-US"]
        case "fr": return ["fr-FR", "en-US"]
        case "it": return ["it-IT", "en-US"]
        case "ja": return ["ja-JP", "en-US"]
        case "ko": return ["ko-KR", "en-US"]
        case "uk": return ["uk-UA", "en-US"]
        case "zh-Hans": return ["zh-Hans", "en-US"]
        case "zh-TW", "zh-HK": return ["zh-Hant", "en-US"]
        default: return ["en-US"]
        }
    }

    static let maxImageRenderDimension = 20_000
    static let maxImageRenderPixels = 8_192 * 8_192

    static func imageDisplaySize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any] else { return nil }
        guard let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width.isFinite, height.isFinite, width > 0, height > 0,
              width < Double(Int.max), height < Double(Int.max) else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let size = 5...8 ~= orientation ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        return CGSize(width: size.width.rounded(), height: size.height.rounded())
    }

    static func imageThumbnail(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ] as CFDictionary)
    }

    static func imageRenderSizeIsSafe(_ size: CGSize,
                                      maxDimension: Int = maxImageRenderDimension,
                                      maxPixels: Int = maxImageRenderPixels) -> Bool {
        let width = abs(size.width)
        let height = abs(size.height)
        guard width.isFinite, height.isFinite, width >= 1, height >= 1,
              width <= CGFloat(maxDimension), height <= CGFloat(maxDimension) else { return false }
        return width * height <= CGFloat(maxPixels)
    }
}
