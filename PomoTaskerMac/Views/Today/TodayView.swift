//
//  TodayView.swift
//  PomoTaskerMac
//
//  日付ナビゲーション付きタスク一覧 (Mac版)。
//  - LifeArea セグメントは上部、日付ナビはツールバー、追加ボタンは右上
//  - 空状態は中央寄せで大きく表示
//  - Section header は Mac らしくテキスト + chevron
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorPalette) private var palette

    let onStartPomodoro: (TaskItem) -> Void
    @Binding var externalDate: Date

    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]

    @AppStorage("todayCollapsedUrgent")    private var collapsedUrgent = false
    @AppStorage("todayCollapsedImportant") private var collapsedImportant = false
    @AppStorage("todayCollapsedSpecial")   private var collapsedSpecial = false
    @AppStorage("todayCollapsedNormal")    private var collapsedNormal = false
    @AppStorage("todayCollapsedCompleted") private var collapsedCompleted = true

    @AppStorage("today.lifeAreaFilter") private var lifeAreaFilterRaw: String = LifeArea.work.rawValue
    private var selectedLifeArea: LifeArea {
        LifeArea(rawValue: lifeAreaFilterRaw) ?? .work
    }

    @State private var showingAddTask = false

    private var displayedDate: Date { externalDate }
    private var isToday: Bool { Calendar.current.isDateInToday(displayedDate) }

    init(
        onStartPomodoro: @escaping (TaskItem) -> Void,
        externalDate: Binding<Date>
    ) {
        self.onStartPomodoro = onStartPomodoro
        self._externalDate = externalDate
    }

    private var visibleTasks: [TaskItem] {
        let dayStart = displayedDate.startOfDay
        let dayEnd = displayedDate.startOfNextDay
        let now = Date.now
        let area = selectedLifeArea

        return allTasks.filter { task in
            guard task.lifeArea == area else { return false }

            if isToday {
                if task.isDone {
                    if let c = task.completedAt { return c >= dayStart && c < dayEnd }
                    return false
                } else {
                    if let deferred = task.deferredUntil, deferred > now { return false }
                    if let scheduled = task.scheduledDate, scheduled >= dayEnd { return false }
                    return true
                }
            } else {
                if task.isDone {
                    if let c = task.completedAt { return c >= dayStart && c < dayEnd }
                    return false
                } else {
                    if let scheduled = task.scheduledDate,
                       scheduled >= dayStart, scheduled < dayEnd { return true }
                    if let deferred = task.deferredUntil,
                       deferred >= dayStart, deferred < dayEnd { return true }
                    return false
                }
            }
        }
    }

    private var incompleteTasks: [TaskItem] {
        visibleTasks.filter { !$0.isDone }
    }
    private var completedTasks: [TaskItem] {
        visibleTasks.filter { $0.isDone }
    }
    private func tasks(for category: TaskCategory) -> [TaskItem] {
        incompleteTasks.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 上部: 生活領域セグメント
            HStack {
                Picker("生活領域", selection: Binding(
                    get: { selectedLifeArea },
                    set: { lifeAreaFilterRaw = $0.rawValue }
                )) {
                    ForEach(LifeArea.allCases) { area in
                        Label(area.label, systemImage: area.systemImage).tag(area)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // 本体
            if incompleteTasks.isEmpty && completedTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .principal) {
                dateNav
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTask = true
                } label: {
                    Label("タスク追加", systemImage: "plus")
                }
                .accessibilityLabel("タスクを追加")
            }
        }
        .sheet(isPresented: $showingAddTask) {
            // 今開いているタブの LifeArea (仕事/プライベート) を初期値に
            AddTaskSheet(
                initialDate: displayedDate,
                initialLifeArea: selectedLifeArea
            )
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text(emptyTitle)
                .font(.title3.weight(.semibold))
            Text(emptyDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Date nav

    private var dateNav: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("前日")

            Button {
                withAnimation { externalDate = .now }
            } label: {
                VStack(spacing: 0) {
                    Text(headerLabel)
                        .font(.headline)
                    if !isToday {
                        Text("クリックで今日へ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 110)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("翌日")
        }
    }

    private var headerLabel: String {
        if Calendar.current.isDateInToday(displayedDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(displayedDate) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(displayedDate) { return "Yesterday" }
        return displayedDate.shortDateWithWeekday()
    }

    private var emptyTitle: String {
        if isToday { return "タスクがありません" }
        if Calendar.current.isDateInTomorrow(displayedDate) { return "明日の予定はありません" }
        if Calendar.current.isDateInYesterday(displayedDate) { return "昨日のタスクはありません" }
        return "\(displayedDate.shortDateWithWeekday()) のタスクはありません"
    }

    private var emptyDescription: String {
        if isToday { return "右上の + ボタンから追加してください。" }
        return "この日に紐づくタスクはまだありません。"
    }

    // MARK: - Task list

    private var taskList: some View {
        List {
            if !tasks(for: .urgent).isEmpty {
                categorySection(.urgent, collapsed: $collapsedUrgent)
            }
            if !tasks(for: .important).isEmpty {
                categorySection(.important, collapsed: $collapsedImportant)
            }
            if !tasks(for: .special).isEmpty {
                categorySection(.special, collapsed: $collapsedSpecial)
            }
            if !tasks(for: .normal).isEmpty {
                categorySection(.normal, collapsed: $collapsedNormal)
            }
            if !completedTasks.isEmpty {
                completedSection
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func categorySection(_ category: TaskCategory, collapsed: Binding<Bool>) -> some View {
        let categoryTasks = tasks(for: category)

        Section {
            if !collapsed.wrappedValue {
                ForEach(categoryTasks) { task in
                    TaskRowView(
                        task: task,
                        onStartPomodoro: isToday ? onStartPomodoro : nil
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if isToday {
                            Button {
                                deferToTomorrow(task)
                            } label: {
                                Label("明日", systemImage: "arrow.turn.down.right")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTask(task)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        if isToday {
                            Button {
                                deferToTomorrow(task)
                            } label: {
                                Label("明日に持ち越す", systemImage: "arrow.turn.down.right")
                            }
                        }
                        Button(role: .destructive) {
                            deleteTask(task)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            sectionHeader(
                count: categoryTasks.count,
                collapsed: collapsed
            ) {
                CategoryBadge(category: category)
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        Section {
            if !collapsedCompleted {
                ForEach(completedTasks) { task in
                    TaskRowView(task: task)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteTask(task)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteTask(task)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                }
            }
        } header: {
            sectionHeader(
                count: completedTasks.count,
                collapsed: $collapsedCompleted
            ) {
                Label("完了", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }
        }
    }

    /// Section header の共通スタイル (badge/label + count + chevron)。
    @ViewBuilder
    private func sectionHeader<Label: View>(
        count: Int,
        collapsed: Binding<Bool>,
        @ViewBuilder badge: () -> Label
    ) -> some View {
        HStack(spacing: 8) {
            badge()
            Text("(\(count))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: collapsed.wrappedValue ? "chevron.right" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                collapsed.wrappedValue.toggle()
            }
        }
    }

    // MARK: - Actions

    private func moveDay(by delta: Int) {
        if let new = Calendar.current.date(byAdding: .day, value: delta, to: displayedDate) {
            externalDate = new
        }
    }

    private func deferToTomorrow(_ task: TaskItem) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now.startOfDay) ?? Date.now
        withAnimation {
            task.deferredUntil = tomorrow
        }
    }

    private func deleteTask(_ task: TaskItem) {
        modelContext.delete(task)
    }
}

#Preview {
    @Previewable @State var date: Date = .now
    return NavigationStack {
        TodayView(onStartPomodoro: { _ in }, externalDate: $date)
    }
    .environment(\.colorPalette, .pastel)
    .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
