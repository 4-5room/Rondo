//
//  StatsView.swift
//  PomoTaskerMac
//
//  D/W/M 集計画面 (Mac版)。
//  iOS版から paletteBackground 削除、secondarySystemBackground を Mac 用に置換。
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct StatsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String {
            switch self {
            case .day:   return "Day"
            case .week:  return "Week"
            case .month: return "Month"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    /// 日付タップ時のナビゲーション(ContentView で Today タブに切替)
    var onNavigateToDate: ((Date) -> Void)? = nil

    @Query(sort: [SortDescriptor(\TimelineEntry.startAt)])
    private var allEntries: [TimelineEntry]

    @Query(sort: [SortDescriptor(\PomodoroSession.startedAt)])
    private var allSessions: [PomodoroSession]

    @State private var period: Period = .day

    // MARK: - Range

    private var range: (start: Date, end: Date, title: String) {
        let now = Date.now
        switch period {
        case .day:
            return (now.startOfDay, now.startOfNextDay, now.shortDateWithWeekday())
        case .week:
            let start = now.startOfWeek
            let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? now
            let endLabel = Calendar.current.date(byAdding: .day, value: 6, to: start)?.shortDateWithWeekday() ?? ""
            return (start, end, "\(start.shortDateWithWeekday()) – \(endLabel)")
        case .month:
            return (now.startOfMonth, now.startOfNextMonth, now.yearMonthString())
        }
    }

    private var entriesInRange: [TimelineEntry] {
        let r = range
        return allEntries.filter {
            $0.endAt > r.start && $0.startAt < r.end
        }
    }

    private var sessionsInRange: [PomodoroSession] {
        let r = range
        return allSessions.filter {
            let e = $0.endedAt ?? $0.startedAt
            return e > r.start && $0.startedAt < r.end
        }
    }

    private func clippedSeconds(_ entry: TimelineEntry, in r: (start: Date, end: Date, title: String)) -> Int {
        let s = max(entry.startAt, r.start)
        let e = min(entry.endAt, r.end)
        return max(0, Int(e.timeIntervalSince(s)))
    }

    private var totalSeconds: Int {
        let r = range
        return entriesInRange.reduce(0) { $0 + clippedSeconds($1, in: r) }
    }

    private var completedPomoCount: Int {
        sessionsInRange.filter { $0.wasCompleted }.count
    }

    private var interruptedCount: Int {
        sessionsInRange.filter { !$0.wasCompleted }.count
    }

    private var manualEntryCount: Int {
        entriesInRange.filter { $0.source == .manual }.count
    }

    private var categoryBreakdown: [(category: TaskCategory, seconds: Int)] {
        let r = range
        let grouped = Dictionary(grouping: entriesInRange) { $0.category }
        return TaskCategory.allCases
            .map { cat in
                let secs = grouped[cat]?.reduce(0) {
                    $0 + clippedSeconds($1, in: r)
                } ?? 0
                return (cat, secs)
            }
            .filter { $0.1 > 0 }
    }

    private var lifeAreaBreakdown: [(lifeArea: LifeArea, seconds: Int)] {
        let r = range
        let grouped = Dictionary(grouping: entriesInRange) { $0.lifeArea }
        return LifeArea.allCases.map { area in
            let secs = grouped[area]?.reduce(0) {
                $0 + clippedSeconds($1, in: r)
            } ?? 0
            return (area, secs)
        }
    }

    // MARK: - View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("期間", selection: $period) {
                    ForEach(Period.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                Text(range.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                summaryCards

                if period != .day {
                    lifeAreaSummarySection
                }

                if period == .month {
                    Divider()
                    Text("カレンダー")
                        .font(.headline)
                    MonthCalendarView(
                        monthStart: range.start,
                        secondsByDay: secondsByDay(),
                        onSelectDate: { date in
                            onNavigateToDate?(date)
                        }
                    )
                    Text("日付クリックで Today タブのその日に移動します。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("分類別")
                    .font(.headline)
                CategoryDonutChart(data: categoryBreakdown)

                Divider()

                timeBarChart
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Stats")
    }

    private var summaryCards: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                summaryCard(
                    title: "累計時間",
                    value: formatDuration(totalSeconds),
                    systemImage: "hourglass"
                )
                summaryCard(
                    title: "完走ポモ",
                    value: "\(completedPomoCount)",
                    systemImage: "timer"
                )
            }
            HStack(spacing: 8) {
                summaryCard(
                    title: "中断",
                    value: "\(interruptedCount)",
                    systemImage: "exclamationmark.triangle"
                )
                summaryCard(
                    title: "手動ログ",
                    value: "\(manualEntryCount)",
                    systemImage: "pencil"
                )
            }
        }
    }

    private func summaryCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private var lifeAreaSummarySection: some View {
        HStack(spacing: 8) {
            ForEach(lifeAreaBreakdown, id: \.lifeArea.id) { row in
                lifeAreaCard(area: row.lifeArea, seconds: row.seconds)
            }
        }
    }

    private func lifeAreaCard(area: LifeArea, seconds: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(area.label, systemImage: area.systemImage)
                .font(.caption)
                .foregroundStyle(area.tintColor)
            Text(formatDuration(seconds))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(area.tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(area.tintColor.opacity(0.3), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var timeBarChart: some View {
        switch period {
        case .day:
            TimeBarChart(
                title: "時間帯別",
                buckets: hourlyBuckets(),
                xAxisLabel: "時"
            )
        case .week:
            TimeBarChart(
                title: "曜日別",
                buckets: weekdayBuckets(),
                xAxisLabel: "曜日"
            )
        case .month:
            TimeBarChart(
                title: "日別",
                buckets: dailyBuckets(),
                xAxisLabel: "日"
            )
        }
    }

    // MARK: - Buckets (TimelineEntry-based, 日跨ぎ按分対応)

    private func distributeSeconds(
        bucketCount: Int,
        bucketRange: (Int) -> (start: Date, end: Date)
    ) -> [Int] {
        var sums = Array(repeating: 0, count: bucketCount)
        for e in entriesInRange {
            for i in 0..<bucketCount {
                let b = bucketRange(i)
                let s = max(e.startAt, b.start)
                let en = min(e.endAt, b.end)
                let dur = Int(en.timeIntervalSince(s))
                if dur > 0 { sums[i] += dur }
            }
        }
        return sums
    }

    private func hourlyBuckets() -> [TimeBucket] {
        let cal = Calendar.current
        let dayStart = range.start
        let sums = distributeSeconds(bucketCount: 24) { i in
            let s = cal.date(byAdding: .hour, value: i, to: dayStart) ?? dayStart
            let e = cal.date(byAdding: .hour, value: i + 1, to: dayStart) ?? dayStart
            return (s, e)
        }
        return (0..<24).map {
            TimeBucket(label: "\($0)", sortKey: $0, seconds: sums[$0])
        }
    }

    private func weekdayBuckets() -> [TimeBucket] {
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        let cal = Calendar.current
        let weekStart = range.start
        let sums = distributeSeconds(bucketCount: 7) { i in
            let s = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
            let e = cal.date(byAdding: .day, value: i + 1, to: weekStart) ?? weekStart
            return (s, e)
        }
        return (0..<7).map {
            TimeBucket(label: labels[$0], sortKey: $0, seconds: sums[$0])
        }
    }

    private func dailyBuckets() -> [TimeBucket] {
        let cal = Calendar.current
        let start = range.start
        let end = range.end
        let dayCount = cal.dateComponents([.day], from: start, to: end).day ?? 30
        let sums = distributeSeconds(bucketCount: dayCount) { i in
            let s = cal.date(byAdding: .day, value: i, to: start) ?? start
            let e = cal.date(byAdding: .day, value: i + 1, to: start) ?? start
            return (s, e)
        }
        return (0..<dayCount).map {
            TimeBucket(label: "\($0 + 1)", sortKey: $0, seconds: sums[$0])
        }
    }

    private func formatDuration(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// カレンダー表示用: 月内の各日の合計秒数を返す(日跨ぎ按分対応)
    private func secondsByDay() -> [Date: Int] {
        var result: [Date: Int] = [:]
        let cal = Calendar.current
        for e in entriesInRange {
            var dayStart = e.startAt.startOfDay
            while dayStart < e.endAt {
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                let s = max(e.startAt, dayStart)
                let en = min(e.endAt, dayEnd)
                let dur = Int(en.timeIntervalSince(s))
                if dur > 0 {
                    result[dayStart, default: 0] += dur
                }
                dayStart = dayEnd
            }
        }
        return result
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .environment(\.colorPalette, .pastel)
    .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
