//
//  TaskRowView.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。チェックリスト行。
//  - カテゴリは「行の左端カテゴリ色ストライプ + 行背景の薄い tint」で表現
//  - LifeArea は Today タブ側のセグメントで明示済みのため、デフォルトで非表示
//  - 二段目はタグ + 累計時間のみのスッキリ構成
//

import SwiftUI

struct TaskRowView: View {
    @Environment(\.colorPalette) private var palette
    @Bindable var task: TaskItem

    /// 再生ボタンタップ時のコールバック
    var onStartPomodoro: ((TaskItem) -> Void)? = nil

    /// LifeArea バッジを表示するか。デフォルトでは非表示(Today はタブで絞り込み済みのため)。
    var showLifeAreaBadge: Bool = false

    private var categoryColor: Color { palette.color(for: task.category) }

    /// 累計実働時間の表示ラベル。0h0m なら非表示。
    private var totalDurationLabel: String? {
        let s = max(0, task.totalSeconds)
        guard s >= 1 else { return nil }
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        if m > 0 {
            return "\(m)m"
        }
        return "<1m"
    }

    /// 二段目に表示するメタ情報があるか
    private var hasSecondLineContent: Bool {
        if let tag = task.tag, !tag.isEmpty { return true }
        if showLifeAreaBadge { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 10) {
            // 左端: カテゴリ色の縦ストライプ
            Capsule()
                .fill(categoryColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            // 完了トグル
            Button {
                toggleDone()
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? categoryColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            // メイン情報
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isDone, color: .secondary)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(2)

                if hasSecondLineContent {
                    secondLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 累計時間
            if let label = totalDurationLabel {
                HStack(spacing: 3) {
                    Image(systemName: "stopwatch")
                        .font(.caption2)
                    Text(label)
                        .font(.caption)
                        .lineLimit(1)
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            }

            // ポモ開始ボタン
            if !task.isDone, let onStartPomodoro {
                Button {
                    onStartPomodoro(task)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.callout)
                        .foregroundStyle(categoryColor)
                        .frame(width: 36, height: 36)
                        .background(categoryColor.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ポモドーロを開始")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(categoryColor.opacity(0.08))
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var secondLine: some View {
        HStack(spacing: 6) {
            if showLifeAreaBadge {
                LifeAreaBadge(lifeArea: task.lifeArea)
            }
            if let tag = task.tag, !tag.isEmpty {
                TagBadge(tag: tag)
            }
        }
    }

    private func toggleDone() {
        task.isDone.toggle()
        task.completedAt = task.isDone ? .now : nil
    }
}

/// 生活領域(仕事/プライベート)バッジ
struct LifeAreaBadge: View {
    let lifeArea: LifeArea

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: lifeArea.systemImage)
                .font(.caption2)
            Text(lifeArea.label)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(lifeArea.tintColor)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(lifeArea.tintColor.opacity(0.12), in: Capsule())
    }
}

/// タグバッジ
struct TagBadge: View {
    let tag: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "tag.fill")
                .font(.caption2)
            Text(tag)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(Color.accentColor)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

#Preview {
    List {
        TaskRowView(task: TaskItem(title: "デザインレビュー", category: .important, pomodoroCount: 3, totalSeconds: 4500)) { _ in }
        TaskRowView(task: TaskItem(title: "メール返信", category: .urgent)) { _ in }
        TaskRowView(task: TaskItem(title: "論文読む", category: .special, pomodoroCount: 1, totalSeconds: 1500, lifeArea: .personal)) { _ in }
        TaskRowView(task: TaskItem(title: "買い物メモ", category: .normal, isDone: true, lifeArea: .personal))
    }
}
