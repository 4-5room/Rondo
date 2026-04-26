//
//  MonthCalendarView.swift
//  PomoTaskerMac
//
//  iOS版から移植 (Color(.tertiarySystemFill) を Mac 用に置換)。
//  月単位のカレンダーグリッド。各日にアクティビティ強度を表示。
//

import SwiftUI

struct MonthCalendarView: View {
    let monthStart: Date
    /// 日付ごとの作業秒数 (key は startOfDay)
    let secondsByDay: [Date: Int]
    let onSelectDate: (Date) -> Void

    @Environment(\.colorPalette) private var palette

    private let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2  // 月曜始まり
        return cal
    }

    private var monthDays: [Date?] {
        // 月初の曜日(月曜=0)
        let firstWeekday = (calendar.component(.weekday, from: monthStart) + 5) % 7
        // 月の日数
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let daysInMonth = range.count
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var maxSeconds: Int {
        secondsByDay.values.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let dayStart = date.startOfDay
        let seconds = secondsByDay[dayStart] ?? 0
        let intensity: Double = maxSeconds > 0 ? min(1.0, Double(seconds) / Double(maxSeconds)) : 0
        let isToday = Calendar.current.isDateInToday(date)
        let dayNum = Calendar.current.component(.day, from: date)

        Button {
            onSelectDate(date)
        } label: {
            VStack(spacing: 3) {
                Text("\(dayNum)")
                    .font(.caption.monospacedDigit())
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.white : .primary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(isToday ? palette.accent : Color.clear)
                    )

                Capsule()
                    .fill(intensity > 0 ? palette.accent.opacity(0.3 + intensity * 0.7) : Color.gray.opacity(0.15))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(seconds > 0 ? palette.accent.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
