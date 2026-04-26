//
//  TimelineColumnLayout.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  タイムラインを2列に割り当てるGreedyアルゴリズム。
//  各エントリは「最低表示時間」を持ち、実時間が短くても視覚上のスペースを確保する。
//

import Foundation

struct PositionedEntry: Identifiable {
    let entry: TimelineEntry
    let column: Int        // 0 or 1
    var id: UUID { entry.id }
}

enum TimelineColumnLayout {
    /// 列割当時の視覚的最低表示時間(秒)。
    /// これ以下の実時間のエントリは、この時間分のスペースを占有したとみなされる。
    static let minDisplaySeconds: TimeInterval = 30 * 60  // 30分(=60pt/時換算で30pt)

    /// エントリ配列を2列に割り当てる。
    static func layout(entries: [TimelineEntry]) -> [PositionedEntry] {
        let sorted = entries.sorted { $0.startAt < $1.startAt }
        var columnEnds: [Date] = [.distantPast, .distantPast]
        var result: [PositionedEntry] = []
        for entry in sorted {
            // 視覚上の占有終了時刻(実endAt または startAt + minDisplay の遅い方)
            let effectiveEnd = max(
                entry.endAt,
                entry.startAt.addingTimeInterval(minDisplaySeconds)
            )
            var placed = false
            for col in 0..<2 where columnEnds[col] <= entry.startAt {
                columnEnds[col] = effectiveEnd
                result.append(PositionedEntry(entry: entry, column: col))
                placed = true
                break
            }
            if !placed {
                // 2列とも埋まっている → 列0に積む(3件以上同時のオーバーフロー許容)
                result.append(PositionedEntry(entry: entry, column: 0))
                columnEnds[0] = max(columnEnds[0], effectiveEnd)
            }
        }
        return result
    }
}
