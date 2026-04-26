//
//  PomodoroSession.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。ポモドーロ1回分の実行ログ。
//

import Foundation
import SwiftData

@Model
final class PomodoroSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?            // 実際の終了時刻(中断/完走どちらも)
    var plannedDurationSec: Int   // 計画時間(秒)
    var actualDurationSec: Int    // 実働時間(秒)
    var wasCompleted: Bool        // 完走したか
    var task: TaskItem?           // 紐づくタスク(逆参照)

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        plannedDurationSec: Int,
        actualDurationSec: Int = 0,
        wasCompleted: Bool = false,
        task: TaskItem? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedDurationSec = plannedDurationSec
        self.actualDurationSec = actualDurationSec
        self.wasCompleted = wasCompleted
        self.task = task
    }
}
