//
//  HourlyBarChart.swift
//  PomoTaskerMac
//
//  時間帯別 / 曜日別 / 日別の作業時間バーチャート (リッチ版)。
//  - グラデーション、影、丸みのあるバー
//  - アニメーション
//

import SwiftUI
import Charts

struct TimeBucket: Identifiable {
    let id = UUID()
    let label: String      // "12:00" or "月"
    let sortKey: Int
    let seconds: Int
}

struct TimeBarChart: View {
    let title: String
    let buckets: [TimeBucket]
    let xAxisLabel: String

    private var maxSec: Int { buckets.map { $0.seconds }.max() ?? 0 }
    private var totalSec: Int { buckets.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if totalSec > 0 {
                    Text("合計 \(formatHM(totalSec))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if buckets.allSatisfy({ $0.seconds == 0 }) {
                Text("データなし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 140, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value(xAxisLabel, bucket.label),
                        y: .value("分", Double(bucket.seconds) / 60.0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.95),
                                Color.accentColor.opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(5)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.15))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.caption2)
                    }
                }
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: totalSec)
            }
        }
    }

    private func formatHM(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
