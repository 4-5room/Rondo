//
//  IntelligentOCRCorrector.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  Apple Intelligence (FoundationModels) を用いた OCR 結果の文脈補正。
//  - オンデバイス LLM で「明らかに変な文字列」を自然な日本語に直す
//  - 既存タスク名(辞書)を文脈として渡し、似ている候補があればそちらに寄せる
//  - 利用可否は実行時に確認(対応端末・OS でなければスキップ)
//
//  対応:
//  - macOS 26+ / iOS 26+ (Apple Intelligence + Apple Silicon)
//  - 非対応端末ではメソッドが no-op で raw を返す
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
enum IntelligentOCRCorrector {

    /// このデバイスで Apple Intelligence の補正が利用可能か。
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// 複数行の OCR 結果を一括で補正する。
    /// **後処理ガード**: AI 補正結果が原文と大きく乖離している場合は採用せず raw を残す。
    static func correct(rawTexts: [String], knownTitles: [String]) async -> [String] {
        guard !rawTexts.isEmpty else { return rawTexts }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else { return rawTexts }
            do {
                let session = LanguageModelSession(instructions: Self.systemInstructions)
                let prompt = Self.buildPrompt(rawTexts: rawTexts, knownTitles: knownTitles)
                let response = try await session.respond(to: prompt)
                let parsed = Self.parseResponse(response.content, expecting: rawTexts.count)
                guard parsed.count == rawTexts.count else {
                    #if DEBUG
                    print("[IntelligentOCRCorrector] count mismatch: expected=\(rawTexts.count) got=\(parsed.count)")
                    #endif
                    return rawTexts
                }
                // 後処理ガード: 原文と乖離しすぎている補正案は捨てて raw を残す
                return zip(rawTexts, parsed).map { raw, suggested in
                    Self.acceptSuggestion(raw: raw, suggested: suggested) ? suggested : raw
                }
            } catch {
                #if DEBUG
                print("[IntelligentOCRCorrector] session error: \(error)")
                #endif
                return rawTexts
            }
        }
        #endif
        return rawTexts
    }

    // MARK: - Prompt building

    /// LLM への共通指示。**保守的に** 動作させ、推測が強くならないよう抑制する。
    private static let systemInstructions: String = """
    あなたは OCR(光学文字認識)の出力を**最小限**に直すツールです。
    入力された各行は OCR が画像から読み取った文字列です。
    あなたの仕事は「明らかな誤認識(記号や 1 文字の見間違い)だけ」を直すことです。

    厳守する原則:
    1. **原文をできる限り残す**。意味の保たれる範囲で 1〜2 文字直す程度に留める。
    2. **要約や言い換えは禁止**。意味を変えてはいけない。
       - 例: 「口Rondo farMac開発」を「アプリ開発」のように要約しない。
         先頭の □/口 を除いて「Rondo for Mac 開発」のように直す程度に留める。
    3. **既知タスク名は参考情報**であり、無理に当てはめない。
       入力と既知タスク名が**明らかに似ていない**場合は、入力をそのまま返す。
       - 例: 入力「hote」が既知タスク「校閲」と似ていなければ、「hote」のまま返す。
    4. 自信がなければ**必ず入力をそのまま返す**。
    5. 入力配列の順序と要素数を絶対に変えない(N 件入れたら N 件返す)。
    6. 1 行ごとに 1 つの文字列のみ。改行・説明・引用を入れない。
    7. JSON 配列のみで応答。前後の説明や ```json ブロックは付けない。

    出力例(入力が ["口校閱", "hote", "Rolbahn"] のとき): ["校閲", "hote", "Rollbahn"]
    """

    private static func buildPrompt(rawTexts: [String], knownTitles: [String]) -> String {
        let rawJSON = (try? String(data: JSONEncoder().encode(rawTexts), encoding: .utf8)) ?? "[]"
        let knownLimited = Array(knownTitles.prefix(50))
        let knownJSON = (try? String(data: JSONEncoder().encode(knownLimited), encoding: .utf8)) ?? "[]"
        return """
        以下の各行について、明らかな誤認識のみを最小限に直してください。
        意味を変える書き換え・要約・既知タスク名へのこじつけは禁止です。

        # 入力(N=\(rawTexts.count) 件、順序を保って N 件の JSON 配列で返す)
        \(rawJSON)

        # 既知タスク名(参考のみ。明らかに似てない場合は使わないでください)
        \(knownJSON)
        """
    }

    // MARK: - Post-process guard

    /// AI の補正案を採用してよいか判定するガード。
    /// 大きく乖離している場合は採用しない(原文を残す)。
    static func acceptSuggestion(raw: String, suggested: String) -> Bool {
        let r = raw.trimmingCharacters(in: .whitespaces)
        let s = suggested.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return false }
        if r == s { return true }
        if r.isEmpty { return true }
        let lenR = Double(r.count)
        let lenS = Double(s.count)
        let ratio = lenS / lenR
        if ratio < 0.5 || ratio > 2.0 { return false }
        let distance = TagMatcher.levenshteinDistance(r, s)
        let limit = max(2, Int(Double(min(r.count, s.count)) * 0.6))
        return distance <= limit
    }

    /// 応答テキストから JSON 配列を取り出して文字列配列に変換。
    private static func parseResponse(_ raw: String, expecting count: Int) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = stripped.firstIndex(of: "["),
              let end = stripped.lastIndex(of: "]"),
              start <= end else { return [] }
        let jsonSubstring = stripped[start...end]
        guard let data = String(jsonSubstring).data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}
