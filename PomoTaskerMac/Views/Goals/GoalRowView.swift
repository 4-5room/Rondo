//
//  GoalRowView.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  月次目標の行表示。達成/未達成切り替え、タスクへの追加メニュー。
//

import SwiftUI

struct GoalRowView: View {
    @Bindable var goal: MonthlyGoal

    /// 「今日のタスクに追加」アクション
    var onAddToTasks: ((TaskCategory) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button {
                    goal.isAchieved.toggle()
                } label: {
                    Image(systemName: goal.isAchieved ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(goal.isAchieved ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(goal.isAchieved, color: .secondary)
                        .foregroundStyle(goal.isAchieved ? .secondary : .primary)

                    if let detail = goal.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if let addedAt = goal.addedToTasksAt {
                        Label("タスクに追加済み (\(addedAt.shortDateWithWeekday()))", systemImage: "tray.and.arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()
            }
        }
        .contextMenu {
            if goal.addedToTasksAt == nil, let onAddToTasks {
                Menu {
                    ForEach(TaskCategory.allCases) { cat in
                        Button {
                            onAddToTasks(cat)
                        } label: {
                            Label(cat.label, systemImage: cat.symbolName)
                        }
                    }
                } label: {
                    Label("今日のタスクに追加", systemImage: "tray.and.arrow.down.fill")
                }
            }
        }
    }
}
