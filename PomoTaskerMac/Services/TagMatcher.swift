//
//  TagMatcher.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  タグ名のマッチング/サジェスト用ユーティリティ。
//

import Foundation

enum TagMatcher {

    // MARK: - Normalization

    /// 比較用の正規化:
    /// - 全角/半角の英数字を半角に統一
    /// - ひらがな ⇄ カタカナの差異を解消(カタカナに寄せる)
    /// - 前後空白の除去 + 内部空白を縮約
    /// - 大文字/小文字を小文字に統一(英字)
    static func normalize(_ s: String) -> String {
        var result = s.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? result
        result = result.applyingTransform(.hiraganaToKatakana, reverse: false) ?? result
        result = result.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        )
        result = result.lowercased()
        return result
    }

    // MARK: - Match

    /// 候補文字列を既存タグへマッチさせ、最も近いものを返す。
    static func bestMatch(for candidate: String, in existing: [String]) -> String? {
        let target = normalize(candidate)
        guard !target.isEmpty else { return nil }

        let normalized = existing.map { (raw: $0, norm: normalize($0)) }

        if let hit = normalized.first(where: { $0.norm == target }) {
            return hit.raw
        }

        if let hit = normalized.first(where: {
            !$0.norm.isEmpty && (target.contains($0.norm) || $0.norm.contains(target))
        }) {
            return hit.raw
        }

        let threshold = max(1, target.count / 3)
        var best: (raw: String, distance: Int)? = nil
        for entry in normalized {
            let d = levenshteinDistance(target, entry.norm)
            if d <= threshold {
                if best == nil || d < best!.distance {
                    best = (entry.raw, d)
                }
            }
        }
        return best?.raw
    }

    // MARK: - Suggestion

    static func suggestions(
        for input: String,
        in existing: [String],
        maxCount: Int = 8
    ) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for tag in existing where !tag.isEmpty {
            let key = normalize(tag)
            if seen.insert(key).inserted {
                unique.append(tag)
            }
        }
        let typed = normalize(input)
        let filtered: [String]
        if typed.isEmpty {
            filtered = unique
        } else {
            filtered = unique.filter { normalize($0).contains(typed) }
        }
        return Array(filtered.prefix(maxCount))
    }

    // MARK: - Levenshtein

    static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = aChars.count
        let m = bChars.count
        if n == 0 { return m }
        if m == 0 { return n }

        var prev = Array(0...m)
        var curr = Array(repeating: 0, count: m + 1)

        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = Swift.min(
                    curr[j - 1] + 1,
                    prev[j] + 1,
                    prev[j - 1] + cost
                )
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }
}
