//
//  OCRCorrection.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  OCR の誤認識補正履歴。ユーザーが OCRReviewSheet で text を修正したとき、
//  (raw, corrected) ペアを学習として保存し、次回以降の OCR 結果に自動適用する。
//

import Foundation
import SwiftData

@Model
final class OCRCorrection {
    @Attribute(.unique) var id: UUID

    /// OCR が認識した raw 文字列(`TagMatcher.normalize` 適用後)。
    var normalizedRaw: String

    /// 表示用に元の raw 文字列も残しておく(デバッグ・参照用)
    var rawText: String

    /// ユーザーが修正した正解テキスト(表示用そのまま)
    var correctedText: String

    /// 同じ補正が発生した回数。多いほど信頼度が高い。
    var occurrences: Int

    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        normalizedRaw: String,
        rawText: String,
        correctedText: String,
        occurrences: Int = 1,
        createdAt: Date = .now,
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.normalizedRaw = normalizedRaw
        self.rawText = rawText
        self.correctedText = correctedText
        self.occurrences = occurrences
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
