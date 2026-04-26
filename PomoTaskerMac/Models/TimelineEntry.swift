//
//  TimelineEntry.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  タイムライン上の1ブロック。ポモドーロ完了時に自動生成、手動追加も可。
//

import Foundation
import SwiftData

enum EntrySource: String, Codable {
    case pomodoro
    case manual
}

@Model
final class TimelineEntry {
    @Attribute(.unique) var id: UUID
    var startAt: Date
    var endAt: Date
    var taskID: UUID?
    var title: String             // タスク削除後もログに残すため非正規化
    var categoryRaw: String
    var sourceRaw: String         // EntrySource.rawValue

    /// 生活領域(仕事/プライベート)。
    /// ポモドーロ自動ログ時はタスクから継承、手動追加時は UI で選択。
    var lifeAreaRaw: String = LifeArea.work.rawValue

    init(
        id: UUID = UUID(),
        startAt: Date,
        endAt: Date,
        taskID: UUID? = nil,
        title: String,
        category: TaskCategory = .normal,
        source: EntrySource = .manual,
        lifeArea: LifeArea = .work
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.taskID = taskID
        self.title = title
        self.categoryRaw = category.rawValue
        self.sourceRaw = source.rawValue
        self.lifeAreaRaw = lifeArea.rawValue
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .normal }
        set { categoryRaw = newValue.rawValue }
    }

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var lifeArea: LifeArea {
        get { LifeArea(rawValue: lifeAreaRaw) ?? .work }
        set { lifeAreaRaw = newValue.rawValue }
    }
}
