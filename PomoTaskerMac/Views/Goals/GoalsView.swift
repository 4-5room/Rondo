//
//  GoalsView.swift
//  PomoTaskerMac
//
//  今月の目標リスト画面 (Mac版)。
//  iOS版から paletteBackground 削除、insetGrouped → inset。
//

import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\MonthlyGoal.createdAt)]) private var allGoals: [MonthlyGoal]

    @State private var displayedMonth: Date = Date.now.startOfMonth
    @State private var showingAddSheet = false
    @State private var showMovedOrAchieved = false

    /// 表示中の月の目標
    private var goalsOfMonth: [MonthlyGoal] {
        allGoals.filter { $0.targetMonth.startOfMonth == displayedMonth }
    }

    /// アクティブ(未タスク化 & 未達成)
    private var activeGoals: [MonthlyGoal] {
        goalsOfMonth.filter { $0.addedToTasksAt == nil && !$0.isAchieved }
    }

    /// 追加済み or 達成済み
    private var movedOrAchievedGoals: [MonthlyGoal] {
        goalsOfMonth.filter { $0.addedToTasksAt != nil || $0.isAchieved }
    }

    /// 達成率
    private var achievedRate: Double {
        guard !goalsOfMonth.isEmpty else { return 0 }
        let achieved = goalsOfMonth.filter { $0.isAchieved }.count
        return Double(achieved) / Double(goalsOfMonth.count)
    }

    var body: some View {
        Group {
            if goalsOfMonth.isEmpty {
                ContentUnavailableView(
                    "\(displayedMonth.yearMonthString()) の目標がありません",
                    systemImage: "target",
                    description: Text("右上の + ボタンから追加してください。")
                )
            } else {
                goalList
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 14) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { moveMonth(by: -1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                    .accessibilityLabel("前の月")

                    Button {
                        withAnimation { displayedMonth = Date.now.startOfMonth }
                    } label: {
                        Text(displayedMonth.yearMonthString())
                            .font(.headline)
                            .frame(minWidth: 100)
                            .contentTransition(.numericText())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("クリックで今月に戻ります")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { moveMonth(by: 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                    }
                    .accessibilityLabel("次の月")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("目標を追加")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width > 60 {
                        withAnimation(.easeInOut(duration: 0.2)) { moveMonth(by: -1) }
                    } else if value.translation.width < -60 {
                        withAnimation(.easeInOut(duration: 0.2)) { moveMonth(by: 1) }
                    }
                }
        )
        .sheet(isPresented: $showingAddSheet) {
            AddGoalSheet(targetMonth: displayedMonth)
        }
    }

    private var goalList: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ProgressView(value: achievedRate)
                        .tint(.green)
                    Text("\(Int(achievedRate * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            } header: {
                Text("達成率")
            }

            if !activeGoals.isEmpty {
                Section("目標") {
                    ForEach(activeGoals) { goal in
                        GoalRowView(goal: goal) { category in
                            convertToTask(goal, category: category)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(goal)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !movedOrAchievedGoals.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showMovedOrAchieved) {
                        ForEach(movedOrAchievedGoals) { goal in
                            GoalRowView(goal: goal)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(goal)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                                .foregroundStyle(.secondary)
                            Text("追加済み・達成済み (\(movedOrAchievedGoals.count))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private func moveMonth(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newDate.startOfMonth
        }
    }

    private func delete(_ goal: MonthlyGoal) {
        modelContext.delete(goal)
    }

    private func convertToTask(_ goal: MonthlyGoal, category: TaskCategory) {
        let task = TaskItem(
            title: goal.title,
            note: goal.detail,
            category: category,
            sourceGoalID: goal.id
        )
        modelContext.insert(task)
        goal.addedToTasksAt = .now
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
