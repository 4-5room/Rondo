//
//  TimelineView.swift
//  PomoTaskerMac
//
//  2列バーチカルのタイムラインログ画面 (Mac版)。
//  iOS版から paletteBackground / iOS toolbar placement を Mac 用に置換。
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TimelineEntry.startAt)])
    private var allEntries: [TimelineEntry]

    @State private var displayedDate: Date = .now
    @State private var showingAddSheet = false
    @State private var editingEntry: TimelineEntry?

    private let hourHeight: CGFloat = 60
    private let hourLabelWidth: CGFloat = 44
    private let columnGap: CGFloat = 4

    private var dayStart: Date { displayedDate.startOfDay }
    private var dayEnd: Date { displayedDate.startOfNextDay }

    private var entriesOfDay: [TimelineEntry] {
        allEntries.filter { $0.endAt > dayStart && $0.startAt < dayEnd }
    }

    private var positionedEntries: [PositionedEntry] {
        TimelineColumnLayout.layout(entries: entriesOfDay)
    }

    var body: some View {
        Group {
            if entriesOfDay.isEmpty {
                emptyState
            } else {
                timelineScroll
            }
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItem(placement: .principal) {
                dateNav
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("ログを追加")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTimelineEntrySheet(referenceDate: displayedDate)
        }
        .sheet(item: $editingEntry) { entry in
            AddTimelineEntrySheet(editingEntry: entry, referenceDate: displayedDate)
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 60 {
                        withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: -1) }
                    } else if value.translation.width < -60 {
                        withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: 1) }
                    }
                }
        )
    }

    // MARK: - Subviews

    private var dateNav: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .accessibilityLabel("前日")

            Button {
                withAnimation { displayedDate = .now }
            } label: {
                Text(displayedDate.shortDateWithWeekday())
                    .font(.headline)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.plain)
            .accessibilityHint("クリックで今日に戻ります")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { moveDay(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .accessibilityLabel("翌日")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "\(displayedDate.shortDateWithWeekday()) のログがありません",
            systemImage: "calendar.day.timeline.left",
            description: Text("ポモドーロで記録されるか、右上の + ボタンから手動で追加してください。")
        )
    }

    private var timelineScroll: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - hourLabelWidth
            let columnWidth = (contentWidth - columnGap) / 2

            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        currentTimeIndicator(columnWidth: columnWidth)
                        blockLayer(columnWidth: columnWidth)
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.vertical, 8)
                }
                .scrollContentBackground(.hidden)
                .onAppear { scrollToInitialPosition(using: proxy) }
                .onChange(of: displayedDate) { _, _ in
                    scrollToInitialPosition(using: proxy)
                }
            }
        }
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text("\(hour):00")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: hourLabelWidth, alignment: .trailing)
                        .padding(.trailing, 4)
                        .offset(y: -6)

                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                }
                .frame(height: hourHeight, alignment: .top)
                .id("hour_\(hour)")
            }
        }
    }

    /// 今日を表示中のとき、現在時刻にラインを重ねる。
    @ViewBuilder
    private func currentTimeIndicator(columnWidth: CGFloat) -> some View {
        if Calendar.current.isDateInToday(displayedDate) {
            let y = yOffset(for: .now)
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: hourLabelWidth - 4)
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1)
            }
            .offset(y: y - 0.5)
            .allowsHitTesting(false)
        }
    }

    /// 日付切替時のスクロール位置調整。
    /// - 今日: 現在時刻の少し前まで自動スクロール
    /// - その他: 上端から表示
    private func scrollToInitialPosition(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if Calendar.current.isDateInToday(displayedDate) {
                let hour = Calendar.current.component(.hour, from: .now)
                let target = max(0, hour - 1)
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("hour_\(target)", anchor: .top)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("hour_0", anchor: .top)
                }
            }
        }
    }

    private func blockLayer(columnWidth: CGFloat) -> some View {
        ForEach(positionedEntries) { item in
            let y = yOffset(for: item.entry.startAt)
            let displayHeight = max(28, height(for: item.entry))
            let x = hourLabelWidth + (CGFloat(item.column) * (columnWidth + columnGap))

            TimelineBlockView(entry: item.entry, height: displayHeight)
                .frame(width: columnWidth, height: displayHeight)
                .offset(x: x, y: y)
                .contextMenu {
                    Button {
                        editingEntry = item.entry
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(item.entry)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
        }
    }

    // MARK: - Helpers

    private func moveDay(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: displayedDate) {
            displayedDate = newDate
        }
    }

    /// startAt の y座標(0:00 からの経過分 / 60 * hourHeight)
    private func yOffset(for date: Date) -> CGFloat {
        let clamped = max(dayStart, min(dayEnd, date))
        let seconds = clamped.timeIntervalSince(dayStart)
        return CGFloat(seconds) / 3600.0 * hourHeight
    }

    private func height(for entry: TimelineEntry) -> CGFloat {
        let clampedStart = max(dayStart, entry.startAt)
        let clampedEnd = min(dayEnd, entry.endAt)
        let seconds = max(0, clampedEnd.timeIntervalSince(clampedStart))
        return CGFloat(seconds) / 3600.0 * hourHeight
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
    .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
