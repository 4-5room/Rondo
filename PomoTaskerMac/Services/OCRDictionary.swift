//
//  OCRDictionary.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  OCR の認識結果を、過去のタスク履歴・ユーザー修正履歴に基づいて補正するサービス。
//  - 補正履歴(OCRCorrection)に同じ raw が登録されていればそれを採用
//  - 既存タスクのタイトル一覧から、Levenshtein 距離で近いものを探して採用
//

import Foundation

enum OCRDictionary {

    /// 補正の信頼度しきい値。Levenshtein 距離が target 長 × この比率以下なら採用。
    private static let editDistanceRatio: Double = 0.3

    /// raw OCR 文字列を補正候補に変換する。優先順位:
    /// 1. 補正履歴(OCRCorrection) → 即採用
    /// 2. 既存タスクタイトルに正規化後完全一致 → 採用
    /// 3. 既存タスクタイトルに Levenshtein 距離が閾値以内のものがある → 採用
    /// いずれもマッチしなければ raw をそのまま返す。
    static func correct(
        _ raw: String,
        corrections: [OCRCorrection],
        knownTitles: [String]
    ) -> String {
        let normalizedRaw = TagMatcher.normalize(raw)
        guard !normalizedRaw.isEmpty else { return raw }

        // 1) 補正履歴
        if let hit = corrections.first(where: { $0.normalizedRaw == normalizedRaw }) {
            return hit.correctedText
        }

        // 2) 既存タスクタイトルとの完全一致
        if let hit = knownTitles.first(where: { TagMatcher.normalize($0) == normalizedRaw }) {
            return hit
        }

        // 3) Levenshtein 距離マッチング
        let threshold = max(1, Int(Double(normalizedRaw.count) * editDistanceRatio))
        var best: (title: String, distance: Int)? = nil
        for title in knownTitles {
            let normalized = TagMatcher.normalize(title)
            // 文字数差が閾値より大きければ計算スキップ(高速化)
            if abs(normalized.count - normalizedRaw.count) > threshold { continue }
            let d = TagMatcher.levenshteinDistance(normalized, normalizedRaw)
            if d <= threshold {
                if best == nil || d < best!.distance {
                    best = (title, d)
                }
            }
        }
        if let best { return best.title }

        return raw
    }

    /// 既存タスクの **ユニークなタイトル一覧**(出現頻度順)を取得。
    static func knownTitles(from tasks: [TaskItem]) -> [String] {
        var counter: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        for (idx, t) in tasks.enumerated() {
            let title = t.title.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            counter[title, default: 0] += 1
            if firstSeen[title] == nil { firstSeen[title] = idx }
        }
        return counter
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return (firstSeen[lhs.key] ?? 0) < (firstSeen[rhs.key] ?? 0)
            }
            .map { $0.key }
    }

    /// 補正履歴を upsert。同じ normalizedRaw が既にあれば occurrences を増やし、
    /// correctedText が変わっていたら新値で上書きして lastUsedAt を更新。
    /// 無ければ新規挿入。
    static func upsertCorrection(
        rawText: String,
        correctedText: String,
        in corrections: [OCRCorrection],
        insert: (OCRCorrection) -> Void
    ) {
        let normalized = TagMatcher.normalize(rawText)
        guard !normalized.isEmpty,
              !correctedText.trimmingCharacters(in: .whitespaces).isEmpty,
              normalized != TagMatcher.normalize(correctedText)
        else { return }

        if let existing = corrections.first(where: { $0.normalizedRaw == normalized }) {
            existing.occurrences += 1
            existing.lastUsedAt = .now
            if existing.correctedText != correctedText {
                existing.correctedText = correctedText
            }
        } else {
            let new = OCRCorrection(
                normalizedRaw: normalized,
                rawText: rawText,
                correctedText: correctedText
            )
            insert(new)
        }
    }
}
