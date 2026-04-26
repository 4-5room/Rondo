//
//  CategoryDonutChart.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  分類別作業時間のドーナツチャート。
//

import SwiftUI
import Charts

struct CategoryDonutChart: View {
    /// 分類ごとの作業秒数
    let data: [(category: TaskCategory, seconds: Int)]

    private var total: Int {
        data.reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        if total == 0 {
            ContentUnavailableView(
                "データなし",
                systemImage: "chart.pie",
                description: Text("この期間の作業ログがありません。")
            )
            .frame(height: 200)
        } else {
            VStack(spacing: 12) {
                Chart(data, id: \.category) { item in
                    SectorMark(
                        angle: .value("時間", item.seconds),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.category.color)
                    .annotation(position: .overlay, alignment: .center) {
                        if item.seconds > total / 10 {
                            Text("\(Int(Double(item.seconds) / Double(total) * 100))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 200)

                HStack(spacing: 12) {
                    ForEach(data, id: \.category) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 8, height: 8)
                            Text(item.category.label)
                                .font(.caption2)
                            Text(formatHMS(item.seconds))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func formatHMS(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }
}
