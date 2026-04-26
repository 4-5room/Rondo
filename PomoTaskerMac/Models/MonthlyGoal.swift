//
//  MonthlyGoal.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。今月の目標1件。日次タスクへ流し込む元データ。
//

import Foundation
import SwiftData

@Model
final class MonthlyGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String?
    var targetMonth: Date         // その月の1日(時刻は00:00)
    var isAchieved: Bool
    var createdAt: Date
    /// 日次タスクに流し込んだ日時。nil ならまだ未移行。
    var addedToTasksAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        targetMonth: Date,
        isAchieved: Bool = false,
        createdAt: Date = .now,
        addedToTasksAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.targetMonth = targetMonth
        self.isAchieved = isAchieved
        self.createdAt = createdAt
        self.addedToTasksAt = addedToTasksAt
    }
}
