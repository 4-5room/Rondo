//
//  TagInputField.swift
//  PomoTaskerMac
//
//  iOS版から移植 (Mac用に iOS固有 modifier を削除)。
//  タグ入力フィールド + チップサジェスト。
//  - 入力中の文字列を含む既存タグを下にチップ列で表示
//  - チップタップで入力欄に採用
//

import SwiftUI
import SwiftData

struct TagInputField: View {
    /// タグ文字列バインディング (nil 許容のため呼び出し側で String <-> String? 変換)
    @Binding var tag: String

    /// DB から取得した既存タグ一覧 (出現頻度順を期待)
    let existingTags: [String]

    @FocusState private var isFocused: Bool

    /// 入力に応じてフィルタしたサジェスト候補
    private var suggestions: [String] {
        TagMatcher.suggestions(for: tag, in: existingTags, maxCount: 8)
            .filter { TagMatcher.normalize($0) != TagMatcher.normalize(tag) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("タグ (任意)", text: $tag)
                    .focused($isFocused)
                    .textFieldStyle(.roundedBorder)
                if !tag.isEmpty {
                    Button {
                        tag = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { s in
                            Button {
                                tag = s
                                isFocused = false
                            } label: {
                                Text(s)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule().fill(Color.accentColor.opacity(0.12))
                                    )
                                    .overlay(
                                        Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

/// 既存タグ一覧を出現頻度順に取得する共通ヘルパー。
enum TagSource {
    static func uniqueTags(from tasks: [TaskItem]) -> [String] {
        var counter: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        for (idx, t) in tasks.enumerated() {
            guard let raw = t.tag?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { continue }
            counter[raw, default: 0] += 1
            if firstSeen[raw] == nil { firstSeen[raw] = idx }
        }
        return counter
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return (firstSeen[lhs.key] ?? 0) < (firstSeen[rhs.key] ?? 0)
            }
            .map { $0.key }
    }

    /// 各タグの使用件数を取得 (タグ管理画面で使用)。
    static func tagCounts(from tasks: [TaskItem]) -> [(tag: String, count: Int)] {
        var counter: [String: Int] = [:]
        for t in tasks {
            guard let raw = t.tag?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { continue }
            counter[raw, default: 0] += 1
        }
        return counter.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }.map { (tag: $0.key, count: $0.value) }
    }
}
