//
//  TaskItem.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。チェックリスト上のタスク1件。
//  ※ Swift標準の `Task` と衝突するため型名は `TaskItem`。
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String?
    var categoryRaw: String       // TaskCategory.rawValue を格納(SwiftDataのenum扱いの制約回避)
    var isDone: Bool
    var createdAt: Date
    var completedAt: Date?
    var sourceGoalID: UUID?       // MonthlyGoal起源の場合

    /// 累計完了ポモ回数(非正規化: 集計高速化のため冗長保持)
    var pomodoroCount: Int

    /// 累計実働秒数(非正規化: 集計高速化のため冗長保持)
    /// ポモ完了・中断・カウントアップ停止のいずれでも加算される。
    var totalSeconds: Int = 0

    /// 並び替え用の表示順(同日内)
    var sortOrder: Int

    /// 持ち越し先日時。設定されている間、Todayリストから非表示になる。
    var deferredUntil: Date?

    /// 予定日(任意)。設定されている場合、その日の Today に表示される。
    /// nil の場合は createdAt 当日扱い。
    var scheduledDate: Date?

    /// カレンダー連携で追加された場合の外部イベント ID(ICS UID など)。
    /// 同じイベントを二重にタスク化しないための識別子。
    var externalEventID: String?

    /// 生活領域(仕事/プライベート)。TaskCategory とは直交する別軸。
    var lifeAreaRaw: String = LifeArea.work.rawValue

    /// 任意のタグ(単一)。OCR で検出したノートのグループ名や、
    /// ユーザーが独自に分類したい属性を入れる。サジェスト UI で既存値から選択可能。
    var tag: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \PomodoroSession.task)
    var sessions: [PomodoroSession] = []

    // MARK: - Computed

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .normal }
        set { categoryRaw = newValue.rawValue }
    }

    var lifeArea: LifeArea {
        get { LifeArea(rawValue: lifeAreaRaw) ?? .work }
        set { lifeAreaRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        category: TaskCategory = .normal,
        isDone: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        sourceGoalID: UUID? = nil,
        pomodoroCount: Int = 0,
        totalSeconds: Int = 0,
        sortOrder: Int = 0,
        deferredUntil: Date? = nil,
        scheduledDate: Date? = nil,
        externalEventID: String? = nil,
        lifeArea: LifeArea = .work,
        tag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.categoryRaw = category.rawValue
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sourceGoalID = sourceGoalID
        self.pomodoroCount = pomodoroCount
        self.totalSeconds = totalSeconds
        self.sortOrder = sortOrder
        self.deferredUntil = deferredUntil
        self.scheduledDate = scheduledDate
        self.externalEventID = externalEventID
        self.lifeAreaRaw = lifeArea.rawValue
        self.tag = tag
    }
}
