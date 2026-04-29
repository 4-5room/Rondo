//
//  CategoryDonutChart.swift
//  PomoTaskerMac
//
//  分類別作業時間のドーナツチャート (リッチ版)。
//  - 中央に合計時間を大きく表示
//  - グラデ + シャドウで立体感
//  - アニメーションで進入を演出
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
            VStack(spacing: 16) {
                ZStack {
                    Chart(data, id: \.category) { item in
                        SectorMark(
                            angle: .value("時間", item.seconds),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [item.category.color, item.category.color.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .annotation(position: .overlay, alignment: .center) {
                            if item.seconds > total / 10 {
                                Text("\(Int(Double(item.seconds) / Double(total) * 100))%")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.4), radius: 1)
                            }
                        }
                    }
                    .frame(height: 220)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: total)

                    // 中央: 合計時間
                    VStack(spacing: 2) {
                        Text(formatHM(total))
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Text("合計")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // 凡例 (グリッド)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(data, id: \.category) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 9, height: 9)
                                .shadow(color: item.category.color.opacity(0.6), radius: 2)
                            Text(item.category.label)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer(minLength: 4)
                            Text(formatHM(item.seconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            item.category.color.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    }
                }
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
