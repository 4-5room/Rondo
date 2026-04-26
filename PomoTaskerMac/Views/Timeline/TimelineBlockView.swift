//
//  TimelineBlockView.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  タイムライン上の1ブロック表示。ブロック高さに応じて内容を段階的に省略。
//

import SwiftUI

struct TimelineBlockView: View {
    let entry: TimelineEntry
    /// ブロック表示高さ(px)。内容の省略判定に使用。
    let height: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(entry.category.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                if height >= 36 {
                    Text("\(entry.startAt.hourMinute()) – \(entry.endAt.hourMinute())")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if height >= 60 && entry.source == .pomodoro {
                    Label(durationText, systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(entry.category.color)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(entry.category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(entry.category.color.opacity(0.4), lineWidth: 0.5)
        )
        .clipped()
    }

    private var durationText: String {
        let sec = Int(entry.endAt.timeIntervalSince(entry.startAt))
        let m = sec / 60
        let s = sec % 60
        if m > 0 && s > 0 { return "\(m)分\(s)秒" }
        if m > 0 { return "\(m)分" }
        return "\(s)秒"
    }
}
