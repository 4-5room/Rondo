//
//  BackupService.swift
//  PomoTaskerMac
//
//  SwiftData の全エンティティを JSON でエクスポート/インポート (Mac版簡素化)。
//  iOS版から削除: 自動バックアップ世代管理、iCloud Drive 同期。
//  シンプルに「ユーザーが指定した場所に保存」「ファイルから読み込み (全置換)」のみ。
//

import Foundation
import SwiftData

@MainActor
final class BackupService {
    static let shared = BackupService()
    private init() {}

    enum BackupError: Error, LocalizedError {
        case encodeFailed
        case decodeFailed(String)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .encodeFailed: return "エンコードに失敗しました"
            case .decodeFailed(let detail): return "ファイルの読み込みに失敗: \(detail)"
            case .saveFailed(let detail): return "保存に失敗: \(detail)"
            }
        }
    }

    // MARK: - Snapshot DTO

    struct Snapshot: Codable {
        var version: Int = 1
        var exportedAt: Date = .now
        var tasks: [TaskItemDTO] = []
        var sessions: [PomodoroSessionDTO] = []
        var entries: [TimelineEntryDTO] = []
        var goals: [MonthlyGoalDTO] = []
        var settings: [UserSettingsDTO] = []
    }

    struct TaskItemDTO: Codable {
        var id: UUID
        var title: String
        var note: String?
        var categoryRaw: String
        var isDone: Bool
        var createdAt: Date
        var completedAt: Date?
        var sourceGoalID: UUID?
        var pomodoroCount: Int
        var totalSeconds: Int?
        var sortOrder: Int
        var deferredUntil: Date?
        var scheduledDate: Date?
        var externalEventID: String?
        var lifeAreaRaw: String?
        var tag: String?
    }

    struct PomodoroSessionDTO: Codable {
        var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var plannedDurationSec: Int
        var actualDurationSec: Int
        var wasCompleted: Bool
        var taskID: UUID?
    }

    struct TimelineEntryDTO: Codable {
        var id: UUID
        var startAt: Date
        var endAt: Date
        var taskID: UUID?
        var title: String
        var categoryRaw: String
        var sourceRaw: String
        var lifeAreaRaw: String?
    }

    struct MonthlyGoalDTO: Codable {
        var id: UUID
        var title: String
        var detail: String?
        var targetMonth: Date
        var isAchieved: Bool
        var createdAt: Date
        var addedToTasksAt: Date?
    }

    struct UserSettingsDTO: Codable {
        var id: UUID
        var defaultPomodoroMinutes: Int
        var shortBreakMinutes: Int
        var longBreakMinutes: Int
        var autoBreakEnabled: Bool
        var themeRaw: String
        var paletteID: String
        var menuBarEnabled: Bool
    }

    // MARK: - Export

    /// 全データを JSON Data として返す。
    func exportJSON(context: ModelContext) -> Data? {
        let snapshot = buildSnapshot(context: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }

    private func buildSnapshot(context: ModelContext) -> Snapshot {
        var snapshot = Snapshot()

        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        snapshot.tasks = tasks.map { t in
            TaskItemDTO(
                id: t.id, title: t.title, note: t.note, categoryRaw: t.categoryRaw,
                isDone: t.isDone, createdAt: t.createdAt, completedAt: t.completedAt,
                sourceGoalID: t.sourceGoalID, pomodoroCount: t.pomodoroCount,
                totalSeconds: t.totalSeconds, sortOrder: t.sortOrder,
                deferredUntil: t.deferredUntil, scheduledDate: t.scheduledDate,
                externalEventID: t.externalEventID, lifeAreaRaw: t.lifeAreaRaw, tag: t.tag
            )
        }

        let sessions = (try? context.fetch(FetchDescriptor<PomodoroSession>())) ?? []
        snapshot.sessions = sessions.map { s in
            PomodoroSessionDTO(
                id: s.id, startedAt: s.startedAt, endedAt: s.endedAt,
                plannedDurationSec: s.plannedDurationSec,
                actualDurationSec: s.actualDurationSec,
                wasCompleted: s.wasCompleted, taskID: s.task?.id
            )
        }

        let entries = (try? context.fetch(FetchDescriptor<TimelineEntry>())) ?? []
        snapshot.entries = entries.map { e in
            TimelineEntryDTO(
                id: e.id, startAt: e.startAt, endAt: e.endAt, taskID: e.taskID,
                title: e.title, categoryRaw: e.categoryRaw, sourceRaw: e.sourceRaw,
                lifeAreaRaw: e.lifeAreaRaw
            )
        }

        let goals = (try? context.fetch(FetchDescriptor<MonthlyGoal>())) ?? []
        snapshot.goals = goals.map { g in
            MonthlyGoalDTO(
                id: g.id, title: g.title, detail: g.detail, targetMonth: g.targetMonth,
                isAchieved: g.isAchieved, createdAt: g.createdAt, addedToTasksAt: g.addedToTasksAt
            )
        }

        let settings = (try? context.fetch(FetchDescriptor<UserSettings>())) ?? []
        snapshot.settings = settings.map { s in
            UserSettingsDTO(
                id: s.id, defaultPomodoroMinutes: s.defaultPomodoroMinutes,
                shortBreakMinutes: s.shortBreakMinutes, longBreakMinutes: s.longBreakMinutes,
                autoBreakEnabled: s.autoBreakEnabled, themeRaw: s.themeRaw,
                paletteID: s.paletteID, menuBarEnabled: s.menuBarEnabled
            )
        }

        return snapshot
    }

    // MARK: - Import (全置換)

    /// JSON Data を読み込み、既存データを全削除して復元する。
    func importJSON(_ data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: Snapshot
        do {
            snapshot = try decoder.decode(Snapshot.self, from: data)
        } catch {
            throw BackupError.decodeFailed(error.localizedDescription)
        }

        // 既存データを全削除
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: PomodoroSession.self)
        try? context.delete(model: TimelineEntry.self)
        try? context.delete(model: MonthlyGoal.self)
        try? context.delete(model: UserSettings.self)

        // 復元: TaskItem を先に作成し、id でマップしておく (Session の参照解決用)
        var taskMap: [UUID: TaskItem] = [:]
        for dto in snapshot.tasks {
            let task = TaskItem(
                id: dto.id,
                title: dto.title,
                note: dto.note,
                category: TaskCategory(rawValue: dto.categoryRaw) ?? .normal,
                isDone: dto.isDone,
                createdAt: dto.createdAt,
                completedAt: dto.completedAt,
                sourceGoalID: dto.sourceGoalID,
                pomodoroCount: dto.pomodoroCount,
                totalSeconds: dto.totalSeconds ?? 0,
                sortOrder: dto.sortOrder,
                deferredUntil: dto.deferredUntil,
                scheduledDate: dto.scheduledDate,
                externalEventID: dto.externalEventID,
                lifeArea: LifeArea(rawValue: dto.lifeAreaRaw ?? LifeArea.work.rawValue) ?? .work,
                tag: dto.tag
            )
            context.insert(task)
            taskMap[dto.id] = task
        }

        for dto in snapshot.sessions {
            let session = PomodoroSession(
                id: dto.id,
                startedAt: dto.startedAt,
                endedAt: dto.endedAt,
                plannedDurationSec: dto.plannedDurationSec,
                actualDurationSec: dto.actualDurationSec,
                wasCompleted: dto.wasCompleted,
                task: dto.taskID.flatMap { taskMap[$0] }
            )
            context.insert(session)
        }

        for dto in snapshot.entries {
            let entry = TimelineEntry(
                id: dto.id,
                startAt: dto.startAt,
                endAt: dto.endAt,
                taskID: dto.taskID,
                title: dto.title,
                category: TaskCategory(rawValue: dto.categoryRaw) ?? .normal,
                source: EntrySource(rawValue: dto.sourceRaw) ?? .manual,
                lifeArea: LifeArea(rawValue: dto.lifeAreaRaw ?? LifeArea.work.rawValue) ?? .work
            )
            context.insert(entry)
        }

        for dto in snapshot.goals {
            let goal = MonthlyGoal(
                id: dto.id,
                title: dto.title,
                detail: dto.detail,
                targetMonth: dto.targetMonth,
                isAchieved: dto.isAchieved,
                createdAt: dto.createdAt,
                addedToTasksAt: dto.addedToTasksAt
            )
            context.insert(goal)
        }

        // UserSettings はシングルトンなので最初の1件のみ復元
        if let dto = snapshot.settings.first {
            let s = UserSettings(
                id: dto.id,
                defaultPomodoroMinutes: dto.defaultPomodoroMinutes,
                shortBreakMinutes: dto.shortBreakMinutes,
                longBreakMinutes: dto.longBreakMinutes,
                autoBreakEnabled: dto.autoBreakEnabled,
                theme: ThemePreference(rawValue: dto.themeRaw) ?? .system,
                paletteID: dto.paletteID,
                menuBarEnabled: dto.menuBarEnabled
            )
            context.insert(s)
        }

        do {
            try context.save()
        } catch {
            throw BackupError.saveFailed(error.localizedDescription)
        }
    }
}
