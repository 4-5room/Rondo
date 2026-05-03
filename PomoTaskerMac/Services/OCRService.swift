//
//  OCRService.swift
//  PomoTaskerMac
//
//  Vision framework によるオンデバイス文字認識 (Mac版)。
//  iOS版から削除:
//  - 文書検出/透視補正 (Macではスクショ/PDF前提で不要)
//  - ペン色推定 (デジタル文字には効かない)
//  - UIImage 依存 → CGImage / NSImage / PDFKit ベース
//
//  維持:
//  - Vision 多重パス (mid/strong/original) で精度確保
//  - 行頭四角 → タスク抽出
//  - 複数チェックボックス分割
//  - グループヘッダー検出 + カラム判定
//

import Foundation
@preconcurrency import Vision
import CoreGraphics
import CoreImage
#if canImport(AppKit)
import AppKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

@MainActor
final class OCRService {
    enum OCRError: Error {
        case invalidImage
        case recognitionFailed(Error)
    }

    /// 1行分の認識結果。
    struct RecognizedLine: Identifiable, Hashable {
        let id = UUID()
        var text: String
        /// (Mac版ではnil固定。互換性のため残す)
        var category: TaskCategory? = nil
        /// 所属グループ名(例: 「・ルーティン」配下のタスクなら "ルーティン")。
        var groupName: String? = nil
        /// Vision の生認識候補(topCandidates(3))。デバッグ表示用。
        var rawCandidates: [String] = []
    }

    /// チェックボックス相当と見做す文字集合 (1個目を剥がす判定用)。
    /// 手書き四角が誤認識されやすい字も許容する。
    static let checkboxChars: Set<Character> = [
        "\u{2B1C}", // ⬜
        "\u{2B1B}", // ⬛
        "\u{25A1}", // □
        "\u{25A0}", // ■
        "\u{2610}", // ☐
        "\u{2611}", // ☑
        "\u{2612}", // ☒
        "\u{25FB}", // ◻
        "\u{25FC}", // ◼
        "\u{53E3}", // 口
        "\u{30ED}", // ロ
        "\u{65E5}", // 日
        "\u{25CB}", // ○
        "\u{25EF}", // ◯
        "\u{30FB}", // ・
        "0", "O", "o"
    ]

    /// 複数タスク分割に使う厳格な四角文字集合 (誤分割防止)。
    static let strictCheckboxChars: Set<Character> = [
        "\u{2B1C}", "\u{2B1B}", "\u{25A1}", "\u{25A0}",
        "\u{2610}", "\u{2611}", "\u{2612}", "\u{25FB}", "\u{25FC}"
    ]

    nonisolated static let maxImageDimension: CGFloat = 2000

    // MARK: - Public API

    /// 単一画像から認識。多重パス (中前処理 / 元 / 強前処理) で精度確保。
    func recognize(from cgImage: CGImage, checkboxOnly: Bool = true) async throws -> [RecognizedLine] {
        let preprocessed = Self.preprocessForOCR(cgImage)
        let strong = Self.preprocessForOCRStrong(cgImage)

        async let midObs = Self.runVisionRequest(cgImage: preprocessed)
        async let originalObs = Self.runVisionRequest(cgImage: cgImage)
        async let strongObs = Self.runVisionRequest(cgImage: strong)

        let (mid, original, strongRes) = try await (midObs, originalObs, strongObs)
        let merged = Self.mergeObservations(primary: mid, others: [original, strongRes])

        // ペン色推定には前処理前 (元画像) を渡す。前処理で色情報が失われるため。
        return Self.classifyAndBuild(
            observations: merged,
            colorCGImage: cgImage,
            checkboxOnly: checkboxOnly
        )
    }

    /// 複数画像をシリアルに処理。
    func recognize(from cgImages: [CGImage], checkboxOnly: Bool = true) async throws -> [RecognizedLine] {
        var all: [RecognizedLine] = []
        for image in cgImages {
            let lines = try await recognize(from: image, checkboxOnly: checkboxOnly)
            all.append(contentsOf: lines)
        }
        return all
    }

    /// URL 配列から CGImage 配列を生成 (画像 / PDF両対応、PDFは全ページ展開)。
    nonisolated static func loadCGImages(from urls: [URL]) -> [CGImage] {
        var result: [CGImage] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                result.append(contentsOf: cgImagesFromPDF(at: url))
            } else if let image = cgImageFromImageFile(at: url) {
                result.append(image)
            }
        }
        return result
    }

    /// 画像ファイル → CGImage (ダウンサンプリング)。
    nonisolated static func cgImageFromImageFile(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImageDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// PDF → CGImage 配列 (各ページをレンダリング)。
    nonisolated static func cgImagesFromPDF(at url: URL) -> [CGImage] {
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url) else { return [] }
        var images: [CGImage] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            // スケール: 長辺が maxImageDimension になるよう調整
            let longSide = max(bounds.width, bounds.height)
            let scale = min(2.0, maxImageDimension / longSide)
            let scaledSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            guard let cgContext = CGContext(
                data: nil,
                width: Int(scaledSize.width),
                height: Int(scaledSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            // 白背景 (PDFは透過が多いため)
            cgContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            cgContext.fill(CGRect(origin: .zero, size: scaledSize))
            cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: cgContext)

            if let cg = cgContext.makeImage() {
                images.append(cg)
            }
        }
        return images
        #else
        return []
        #endif
    }

    // MARK: - Vision request

    private static func runVisionRequest(cgImage: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[VNRecognizedTextObservation], Error>) in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    cont.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }
                let results = req.results as? [VNRecognizedTextObservation] ?? []
                cont.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            // 手書きでは言語モデルが逆効果なため無効化
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.minimumTextHeight = 0.003
            request.revision = VNRecognizeTextRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: OCRError.recognitionFailed(error))
                }
            }
        }
    }

    // MARK: - Multi-pass merge

    /// 複数パターンの認識結果を、boundingBox の重複(IoU > 0.4)で除去しつつマージ。
    static func mergeObservations(
        primary: [VNRecognizedTextObservation],
        others: [[VNRecognizedTextObservation]]
    ) -> [VNRecognizedTextObservation] {
        var merged = primary
        for list in others {
            for obs in list {
                if let idx = merged.firstIndex(where: { rectIoU(obs.boundingBox, $0.boundingBox) > 0.4 }) {
                    if topConfidence(of: obs) > topConfidence(of: merged[idx]) {
                        merged[idx] = obs
                    }
                } else {
                    merged.append(obs)
                }
            }
        }
        return merged
    }

    private static func topConfidence(of obs: VNRecognizedTextObservation) -> Float {
        obs.topCandidates(1).first?.confidence ?? 0
    }

    static func rectIoU(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull || inter.isEmpty { return 0 }
        let interArea = inter.width * inter.height
        let unionArea = (a.width * a.height) + (b.width * b.height) - interArea
        guard unionArea > 0 else { return 0 }
        return interArea / unionArea
    }

    // MARK: - Classification & build

    private static func classifyAndBuild(
        observations: [VNRecognizedTextObservation],
        colorCGImage: CGImage,
        checkboxOnly: Bool
    ) -> [RecognizedLine] {
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        struct TaskHit {
            let text: String
            let boundingBox: CGRect
            let rawCandidates: [String]
        }
        struct HeaderHit {
            let text: String
            let boundingBox: CGRect
        }
        var taskHits: [TaskHit] = []
        var headerHits: [HeaderHit] = []

        for obs in sorted {
            let candidates = obs.topCandidates(3).map { $0.string }
            guard !candidates.isEmpty else { continue }

            // ヘッダー判定 (行末コロン → 中黒の順に試す)
            // extractColonHeader を先に試すことで「YouTube:」のような英字+コロンを優先判定。
            // 時刻表記 (12:30 等) は内部「:」を含むため除外される。
            if let headerText = candidates.compactMap({
                extractColonHeader(from: $0) ?? extractBulletHeader(from: $0)
            }).first {
                headerHits.append(HeaderHit(text: headerText, boundingBox: obs.boundingBox))
                continue
            }

            // 複数チェックボックス分割
            if checkboxOnly {
                if let multi = candidates.compactMap({ extractMultipleCheckboxTasks(from: $0) }).first,
                   !multi.isEmpty {
                    for t in multi where !isLikelyNoise(t) {
                        taskHits.append(TaskHit(text: t, boundingBox: obs.boundingBox, rawCandidates: candidates))
                    }
                    continue
                }
            }

            // 単一タスク
            if let taskText = pickBestText(from: obs, checkboxOnly: checkboxOnly) {
                if !isLikelyNoise(taskText) {
                    taskHits.append(TaskHit(text: taskText, boundingBox: obs.boundingBox, rawCandidates: candidates))
                }
                continue
            }

            // checkboxOnly=false 互換
            if !checkboxOnly {
                let best = candidates.max(by: { $0.count < $1.count }) ?? candidates[0]
                let cleaned = cleanLeadingMarkers(best)
                if !cleaned.isEmpty, !isLikelyNoise(cleaned) {
                    taskHits.append(TaskHit(text: cleaned, boundingBox: obs.boundingBox, rawCandidates: candidates))
                }
            }
        }

        let columns = clusterHeadersIntoColumns(headerHits.map { ($0.text, $0.boundingBox) })

        var results: [RecognizedLine] = []
        for hit in taskHits {
            let groupName = resolveGroupName(for: hit.boundingBox, columns: columns)
            // ペン色 (赤=緊急 / 青=重要 / 緑=特殊 / 黒=通常) からカテゴリ推定
            let category = estimateCategory(cgImage: colorCGImage, boundingBox: hit.boundingBox)
            results.append(RecognizedLine(
                text: hit.text,
                category: category,
                groupName: groupName,
                rawCandidates: hit.rawCandidates
            ))
        }
        return results
    }

    // MARK: - Color-based category estimation (iOS版から移植)

    /// boundingBox (Vision の正規化座標、原点左下) の領域からペン色を推定して
    /// TaskCategory を返す。前景ピクセル (彩度高 or 明度低) の平均 HSB で判定。
    static func estimateCategory(cgImage: CGImage, boundingBox: CGRect) -> TaskCategory? {
        let w = cgImage.width
        let h = cgImage.height

        let rectX = Int(boundingBox.minX * CGFloat(w))
        let rectW = Int(boundingBox.width * CGFloat(w))
        let rectH = Int(boundingBox.height * CGFloat(h))
        let rectY = Int((1.0 - boundingBox.maxY) * CGFloat(h))

        let clampedX = max(0, min(w - 1, rectX))
        let clampedY = max(0, min(h - 1, rectY))
        let clampedW = max(1, min(w - clampedX, rectW))
        let clampedH = max(1, min(h - clampedY, rectH))

        guard let sampled = sampleForegroundHSB(
            cgImage: cgImage,
            x: clampedX, y: clampedY, width: clampedW, height: clampedH
        ) else { return nil }

        return classifyCategory(hue: sampled.h, saturation: sampled.s, brightness: sampled.b)
    }

    /// 指定領域からサブサンプリングで前景ピクセルの平均 HSB を算出。
    /// 前景判定: 彩度 > 0.18 もしくは 明度 < 0.55 (= 白背景より暗い)
    /// 該当ピクセルが 1% 未満なら nil (= 文字が薄すぎて判定不能)
    private static func sampleForegroundHSB(
        cgImage: CGImage, x: Int, y: Int, width: Int, height: Int
    ) -> (h: CGFloat, s: CGFloat, b: CGFloat)? {
        let totalPixels = width * height
        let targetPixels = 20_000
        let ratio = max(1.0, Double(totalPixels) / Double(targetPixels))
        let sampleStep = max(1, Int(ratio.squareRoot().rounded(.up)))

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &buffer,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        let sourceRect = CGRect(x: x, y: y, width: width, height: height)
        guard let cropped = cgImage.cropping(to: sourceRect) else { return nil }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

        var sumVectorX: CGFloat = 0  // hue 円周平均の cos 成分
        var sumVectorY: CGFloat = 0  // sin 成分
        var sumS: CGFloat = 0
        var sumB: CGFloat = 0
        var fgCount = 0
        var totalCount = 0

        var py = 0
        while py < height {
            var px = 0
            while px < width {
                let offset = (py * bytesPerRow) + (px * bytesPerPixel)
                let r = CGFloat(buffer[offset]) / 255.0
                let g = CGFloat(buffer[offset + 1]) / 255.0
                let b = CGFloat(buffer[offset + 2]) / 255.0

                let hsb = rgbToHSB(r: r, g: g, b: b)
                totalCount += 1

                if hsb.s > 0.18 || hsb.b < 0.55 {
                    fgCount += 1
                    let angle = hsb.h * 2 * .pi
                    sumVectorX += cos(angle) * hsb.s  // 彩度で重み付け
                    sumVectorY += sin(angle) * hsb.s
                    sumS += hsb.s
                    sumB += hsb.b
                }
                px += sampleStep
            }
            py += sampleStep
        }

        guard totalCount > 0, fgCount >= max(5, totalCount / 100) else {
            return nil
        }

        let avgS = sumS / CGFloat(fgCount)
        let avgB = sumB / CGFloat(fgCount)
        let avgAngle = atan2(sumVectorY / CGFloat(fgCount), sumVectorX / CGFloat(fgCount))
        var avgH = avgAngle / (2 * .pi)
        if avgH < 0 { avgH += 1 }

        return (avgH, avgS, avgB)
    }

    /// HSB → カテゴリ分類:
    /// - 彩度 < 0.20 → 通常 (黒/グレー/鉛筆)
    /// - 赤 (0〜20° / 340〜360°) → 緊急
    /// - 青 (200〜260°) → 重要
    /// - 緑/黄 (40〜160°) → 特殊
    /// - その他 (紫/ピンク/シアン) → 判定困難 → nil
    private static func classifyCategory(hue h: CGFloat, saturation s: CGFloat, brightness b: CGFloat) -> TaskCategory? {
        if s < 0.20 { return .normal }

        let deg = h * 360.0
        if deg < 20 || deg >= 340 { return .urgent }
        if deg >= 200 && deg < 260 { return .important }
        if deg >= 40 && deg < 160 { return .special }
        return nil
    }

    /// RGB → HSB 変換
    private static func rgbToHSB(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV
        var h: CGFloat = 0
        if delta > 0 {
            if maxV == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxV == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = maxV == 0 ? 0 : delta / maxV
        return (h, s, maxV)
    }

    // MARK: - Image preprocessing

    /// 中コントラスト前処理(露出補正 + コントラスト1.6 + アンシャープ)。
    static func preprocessForOCR(_ cgImage: CGImage) -> CGImage {
        let input = CIImage(cgImage: cgImage)

        let exposure = CIFilter(name: "CIExposureAdjust")
        exposure?.setValue(input, forKey: kCIInputImageKey)
        exposure?.setValue(0.3, forKey: kCIInputEVKey)
        let exposed = exposure?.outputImage ?? input

        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(exposed, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.6, forKey: kCIInputContrastKey)
        controls?.setValue(0.08, forKey: kCIInputBrightnessKey)
        let controlled = controls?.outputImage ?? exposed

        let sharpen = CIFilter(name: "CIUnsharpMask")
        sharpen?.setValue(controlled, forKey: kCIInputImageKey)
        sharpen?.setValue(2.0, forKey: kCIInputRadiusKey)
        sharpen?.setValue(0.8, forKey: kCIInputIntensityKey)
        let sharpened = sharpen?.outputImage ?? controlled

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(sharpened, from: sharpened.extent) ?? cgImage
    }

    /// 強コントラスト前処理(薄い文字や陰影が強い文字の補完用)。
    static func preprocessForOCRStrong(_ cgImage: CGImage) -> CGImage {
        let input = CIImage(cgImage: cgImage)

        let exposure = CIFilter(name: "CIExposureAdjust")
        exposure?.setValue(input, forKey: kCIInputImageKey)
        exposure?.setValue(0.5, forKey: kCIInputEVKey)
        let exposed = exposure?.outputImage ?? input

        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(exposed, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(2.0, forKey: kCIInputContrastKey)
        controls?.setValue(0.15, forKey: kCIInputBrightnessKey)
        let controlled = controls?.outputImage ?? exposed

        let sharpen = CIFilter(name: "CIUnsharpMask")
        sharpen?.setValue(controlled, forKey: kCIInputImageKey)
        sharpen?.setValue(2.5, forKey: kCIInputRadiusKey)
        sharpen?.setValue(1.2, forKey: kCIInputIntensityKey)
        let sharpened = sharpen?.outputImage ?? controlled

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(sharpened, from: sharpened.extent) ?? cgImage
    }

    // MARK: - Text selection

    private static func pickBestText(
        from obs: VNRecognizedTextObservation,
        checkboxOnly: Bool
    ) -> String? {
        let candidates = obs.topCandidates(3).map { $0.string }
        guard !candidates.isEmpty else { return nil }

        if checkboxOnly {
            for cand in candidates {
                if let cleaned = extractCheckboxLeftTask(from: cand, depth: 2) {
                    return cleaned
                }
            }
            return nil
        } else {
            let best = candidates.max(by: { $0.count < $1.count }) ?? candidates[0]
            let cleaned = cleanLeadingMarkers(best)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    /// 行頭(最大 depth 文字目まで)にチェックボックスがある行を抽出し、除去したテキストを返す。
    static func extractCheckboxLeftTask(from line: String, depth: Int = 2) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var index = trimmed.startIndex
        var boxIndex: String.Index?
        var steps = 0
        while index < trimmed.endIndex, steps < depth {
            let ch = trimmed[index]
            if checkboxChars.contains(ch) {
                boxIndex = index
                break
            }
            if !ch.isWhitespace {
                steps += 1
            }
            index = trimmed.index(after: index)
        }
        guard let boxAt = boxIndex else { return nil }

        var rest = String(trimmed[trimmed.index(after: boxAt)...])
        while let next = rest.first,
              next.unicodeScalars.contains(where: { $0.value == 0xFE0E || $0.value == 0xFE0F }) {
            rest.removeFirst()
        }
        while let next = rest.first, next.isWhitespace {
            rest.removeFirst()
        }
        let cleaned = rest.trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func cleanLeadingMarkers(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)
        let prefixes = [
            "- ", "* ", "・", "□ ", "□", "☐ ", "☐", "◯ ", "◯",
            "● ", "●", "▪ ", "▪", "• ", "•", "▸ ", "▸", "⬜ ", "⬜"
        ]
        for p in prefixes where result.hasPrefix(p) {
            result.removeFirst(p.count)
            break
        }
        if let match = result.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) {
            result.removeSubrange(match)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// OCR の誤認識断片・記号ゴミっぽい文字列を判定する。
    static func isLikelyNoise(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 1 { return true }
        let meaningful = trimmed.unicodeScalars.filter {
            CharacterSet.letters.contains($0)
        }
        return meaningful.count < 2
    }

    /// 1つの observation に「□A □B □C」が並ぶケースを分割。
    static func extractMultipleCheckboxTasks(from line: String) -> [String]? {
        var tasks: [String] = []
        var current = ""
        var started = false
        for ch in line {
            if strictCheckboxChars.contains(ch) {
                if started {
                    let cleaned = current.trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty { tasks.append(cleaned) }
                }
                current = ""
                started = true
            } else if started {
                current.append(ch)
            }
        }
        if started {
            let cleaned = current.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty { tasks.append(cleaned) }
        }
        return tasks.count >= 2 ? tasks : nil
    }

    // MARK: - Group header extraction

    private static let bulletHeaderChars: Set<Character> = [
        "\u{30FB}", "\u{00B7}", "\u{2022}", "\u{25E6}", "\u{2219}"
    ]

    /// 行末が「:」または「:」で終わる行をヘッダー扱いで抽出する。
    /// 例: `YouTube:` → "YouTube", `ルーティン:` → "ルーティン"
    /// 時刻表記 (12:30 等) は内部に「:」を含むため除外。
    /// チェックボックスを含む行も除外 (タスク行の可能性が高い)。
    static func extractColonHeader(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let last = trimmed.last
        let isHalfColon = last == ":"
        let isFullColon = last == "\u{FF1A}"
        guard isHalfColon || isFullColon else { return nil }

        // チェックボックスを含む行はタスク行とみなす
        if trimmed.contains(where: { checkboxChars.contains($0) }) { return nil }

        let body = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
        guard body.count >= 1, body.count <= 15 else { return nil }
        // 内部に「:」が残っていれば時刻系の可能性 → 除外
        if body.contains(":") || body.contains("\u{FF1A}") { return nil }
        // 文字種は緩く: 文字 / 数字 / スペースのみ許容
        for ch in body {
            guard ch.isLetter || ch.isNumber || ch.isWhitespace else { return nil }
        }
        return body
    }

    /// 「・ルーティン」「・YouTube」「・GAS」のようなグループヘッダーを抽出。
    /// 条件:
    /// - 先頭が中黒系の記号
    /// - 直後にスペースがない (手書き「□ X」誤認識との区別)
    /// - 残り 2〜10 文字
    /// - 全文字が「漢字 / ひらがな / カタカナ / 英字 / 数字」のいずれか
    static func extractBulletHeader(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, bulletHeaderChars.contains(first) else { return nil }
        let afterBulletIdx = trimmed.index(after: trimmed.startIndex)
        guard afterBulletIdx < trimmed.endIndex else { return nil }
        if trimmed[afterBulletIdx].isWhitespace { return nil }

        let rest = String(trimmed[afterBulletIdx...]).trimmingCharacters(in: .whitespaces)
        guard rest.count >= 2, rest.count <= 10 else { return nil }
        for ch in rest {
            guard ch.isHeaderAllowedChar else { return nil }
        }
        return rest
    }

    // MARK: - Column clustering

    struct HeaderColumn {
        var centerX: CGFloat
        var headers: [(text: String, boundingBox: CGRect)]
    }

    static func clusterHeadersIntoColumns(
        _ headers: [(text: String, boundingBox: CGRect)]
    ) -> [HeaderColumn] {
        let threshold: CGFloat = 0.12
        var columns: [HeaderColumn] = []
        for h in headers {
            let x = h.boundingBox.minX
            if let idx = columns.firstIndex(where: { abs($0.centerX - x) < threshold }) {
                columns[idx].headers.append(h)
                let sum = columns[idx].headers.reduce(0) { $0 + $1.boundingBox.minX }
                columns[idx].centerX = sum / CGFloat(columns[idx].headers.count)
            } else {
                columns.append(HeaderColumn(centerX: x, headers: [h]))
            }
        }
        for i in columns.indices {
            columns[i].headers.sort { $0.boundingBox.midY > $1.boundingBox.midY }
        }
        return columns
    }

    /// タスクの所属カラム → 直上ヘッダーをグループ名として返す。
    static func resolveGroupName(
        for taskBox: CGRect,
        columns: [HeaderColumn]
    ) -> String? {
        guard !columns.isEmpty else { return nil }
        let maxColumnDistance: CGFloat = 0.20

        let taskX = taskBox.minX
        guard let nearest = columns.min(by: {
            abs($0.centerX - taskX) < abs($1.centerX - taskX)
        }), abs(nearest.centerX - taskX) < maxColumnDistance else {
            return nil
        }

        let above = nearest.headers.filter { $0.boundingBox.midY > taskBox.midY }
        return above.last?.text
    }
}

private extension Character {
    /// ヘッダー名として許容する文字種か(漢字/ひらがな/カタカナのみ)。
    var isJapaneseCategoryChar: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let v = scalar.value
        if (0x3040...0x309F).contains(v) { return true }   // ひらがな
        if (0x30A0...0x30FF).contains(v) { return true }   // カタカナ
        if (0x4E00...0x9FFF).contains(v) { return true }   // CJK統合漢字
        if (0x3400...0x4DBF).contains(v) { return true }   // CJK統合漢字拡張A
        return false
    }

    /// ヘッダー名として許容する文字種 (日本語 + ASCII 英字 + 数字)。
    /// 記号・スペース・スラッシュ等は false → タスク行とみなす。
    /// 「YouTube」「GAS」「MASTA」「GAS2」等を拾えるよう拡張。
    var isHeaderAllowedChar: Bool {
        if isJapaneseCategoryChar { return true }
        guard let scalar = unicodeScalars.first else { return false }
        let v = scalar.value
        if (0x0041...0x005A).contains(v) || (0x0061...0x007A).contains(v) { return true } // A-Z, a-z
        if (0x0030...0x0039).contains(v) { return true } // 0-9
        return false
    }
}
