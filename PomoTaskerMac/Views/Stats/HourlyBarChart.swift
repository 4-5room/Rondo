//
//  HourlyBarChart.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  時間帯別 / 曜日別 / 日別の作業時間バーチャート。
//

import SwiftUI
import Charts

struct TimeBucket: Identifiable {
    let id = UUID()
    let label: String      // "12:00" or "月"
    let sortKey: Int       // 並び替え用
    let seconds: Int
}

struct TimeBarChart: View {
    let title: String
    let buckets: [TimeBucket]
    let xAxisLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if buckets.allSatisfy({ $0.seconds == 0 }) {
                Text("データなし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value(xAxisLabel, bucket.label),
                        y: .value("分", Double(bucket.seconds) / 60.0)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(3)
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }
}
