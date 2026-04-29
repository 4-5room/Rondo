//
//  BackupService.swift
//  PomoTaskerMac
//
//  SwiftData の全エンティティを JSON でエクスポート/インポート。
//  iOS版と互換性のある同期機能 (iCloud Drive 共有フォルダ経由) も提供。
//
//  - exportJSON / importJSON: 手動 (ファイル選択)
//  - syncWrite / syncReadIfNewer: iCloud Drive 同期フォルダ
//  - 同期では UserSettings は除外 (iOS と Mac でフィールド異なるため)
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

    // MARK: - UserDefaults keys

    private let syncBookmarkKey = "rondo.sync.folder.bookmark"
    private let lastImportedMtimeKey = "rondo.sync.last.imported.mtime"
    private let lastWriteFingerprintKey = "rondo.sync.last.write.fingerprint"
    private let syncFileName = "rondo-sync.json"

    // MARK: - Snapshot DTO

    struct Snapshot: Codable {
        var version: Int = 1
        var exportedAt: Date = .now
        /// 同期用フィンガープリント。書き出しごとに新規発行、自端末書込みの取り込み判定に使う。
        var fingerprint: UUID? = nil
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

    /// UserSettings は iOS と Mac でフィールドが異なるため optional で互換性確保。
    /// (Mac版は menuBarEnabled だけ使用、iOS版固有フィールドは Mac 側でデコード時無視)
    struct UserSettingsDTO: Codable {
        var id: UUID
        var defaultPomodoroMinutes: Int
        var shortBreakMinutes: Int
        var longBreakMinutes: Int
        var autoBreakEnabled: Bool
        var themeRaw: String
        var paletteID: String
        var menuBarEnabled: Bool? = nil
        // iOS 互換 (Mac版では使わないが、デコード時にエラーにならないように)
        var dynamicIslandEnabled: Bool? = nil
        var landscapeAutoStartEnabled: Bool? = nil
        var calendarSyncEnabled: Bool? = nil
        var calendarSourceRaw: String? = nil
        var googleCalendarICSURL: String? = nil
    }

    // MARK: - Encoders

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Manual Export

    func exportJSON(context: ModelContext) -> Data? {
        let snapshot = buildSnapshot(context: context)
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

    // MARK: - Manual Import (全置換)

    func importJSON(_ data: Data, into context: ModelContext) throws {
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

        var taskMap: [UUID: TaskItem] = [:]
        for dto in snapshot.tasks {
            let task = TaskItem(
                id: dto.id, title: dto.title, note: dto.note,
                category: TaskCategory(rawValue: dto.categoryRaw) ?? .normal,
                isDone: dto.isDone, createdAt: dto.createdAt,
                completedAt: dto.completedAt, sourceGoalID: dto.sourceGoalID,
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
                id: dto.id, startedAt: dto.startedAt, endedAt: dto.endedAt,
                plannedDurationSec: dto.plannedDurationSec,
                actualDurationSec: dto.actualDurationSec,
                wasCompleted: dto.wasCompleted,
                task: dto.taskID.flatMap { taskMap[$0] }
            )
            context.insert(session)
        }

        for dto in snapshot.entries {
            let entry = TimelineEntry(
                id: dto.id, startAt: dto.startAt, endAt: dto.endAt,
                taskID: dto.taskID, title: dto.title,
                category: TaskCategory(rawValue: dto.categoryRaw) ?? .normal,
                source: EntrySource(rawValue: dto.sourceRaw) ?? .manual,
                lifeArea: LifeArea(rawValue: dto.lifeAreaRaw ?? LifeArea.work.rawValue) ?? .work
            )
            context.insert(entry)
        }

        for dto in snapshot.goals {
            let goal = MonthlyGoal(
                id: dto.id, title: dto.title, detail: dto.detail,
                targetMonth: dto.targetMonth, isAchieved: dto.isAchieved,
                createdAt: dto.createdAt, addedToTasksAt: dto.addedToTasksAt
            )
            context.insert(goal)
        }

        if let dto = snapshot.settings.first {
            let s = UserSettings(
                id: dto.id,
                defaultPomodoroMinutes: dto.defaultPomodoroMinutes,
                shortBreakMinutes: dto.shortBreakMinutes,
                longBreakMinutes: dto.longBreakMinutes,
                autoBreakEnabled: dto.autoBreakEnabled,
                theme: ThemePreference(rawValue: dto.themeRaw) ?? .system,
                paletteID: dto.paletteID,
                menuBarEnabled: dto.menuBarEnabled ?? true
            )
            context.insert(s)
        }

        do {
            try context.save()
        } catch {
            throw BackupError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Sync folder (iCloud Drive 共有フォルダ経由の擬似同期)

    /// 同期フォルダが設定されているか。
    var hasSyncFolder: Bool {
        UserDefaults.standard.data(forKey: syncBookmarkKey) != nil
    }

    /// 表示用のフォルダ名。
    var syncFolderDisplayName: String? {
        resolveSyncFolder()?.lastPathComponent
    }

    /// ユーザーが選択したフォルダを security-scoped bookmark として保存。
    func setSyncFolder(url: URL) throws {
        // macOS では withSecurityScope オプションが必要
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: syncBookmarkKey)
        // 新フォルダなのでカウンタリセット
        UserDefaults.standard.removeObject(forKey: lastImportedMtimeKey)
        UserDefaults.standard.removeObject(forKey: lastWriteFingerprintKey)
    }

    /// 同期フォルダ設定を解除。
    func clearSyncFolder() {
        UserDefaults.standard.removeObject(forKey: syncBookmarkKey)
        UserDefaults.standard.removeObject(forKey: lastImportedMtimeKey)
        UserDefaults.standard.removeObject(forKey: lastWriteFingerprintKey)
    }

    /// bookmark を URL に解決。利用側は startAccessingSecurityScopedResource で挟むこと。
    private func resolveSyncFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: syncBookmarkKey) else { return nil }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                if let fresh = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    UserDefaults.standard.set(fresh, forKey: syncBookmarkKey)
                }
            }
            return url
        } catch {
            NSLog("[BackupService] sync bookmark 解決失敗: \(error)")
            return nil
        }
    }

    /// 同期フォルダにスナップショット書き込み (UserSettings 除外)。
    /// fingerprint で「自端末の書込み」を識別、次回読込みでスキップ。
    @discardableResult
    func syncWrite(context: ModelContext) -> Bool {
        guard let folder = resolveSyncFolder() else { return false }
        let accessOK = folder.startAccessingSecurityScopedResource()
        defer { if accessOK { folder.stopAccessingSecurityScopedResource() } }

        do {
            guard FileManager.default.fileExists(atPath: folder.path) else {
                NSLog("[BackupService] sync フォルダが消失: \(folder.path)")
                return false
            }
            // UserSettings 除外版の Snapshot を作成
            var snap = buildSnapshot(context: context)
            snap.settings = []  // ← Mac/iOS で互換性問題回避のため除外
            let fingerprint = UUID()
            snap.fingerprint = fingerprint

            let data = try encoder.encode(snap)
            let url = folder.appendingPathComponent(syncFileName)
            try data.write(to: url, options: .atomic)

            UserDefaults.standard.set(fingerprint.uuidString, forKey: lastWriteFingerprintKey)
            if let mtime = fileModificationDate(at: url) {
                UserDefaults.standard.set(mtime, forKey: lastImportedMtimeKey)
            }
            NSLog("[BackupService] sync 書込み完了: fp=\(fingerprint.uuidString.prefix(8))")
            return true
        } catch {
            NSLog("[BackupService] sync 書込み失敗: \(error)")
            return false
        }
    }

    /// 同期フォルダから取り込み (mtime/fingerprint で自端末書込みは除外)。
    @discardableResult
    func syncReadIfNewer(context: ModelContext, force: Bool = false) -> Bool {
        guard let folder = resolveSyncFolder() else { return false }
        let accessOK = folder.startAccessingSecurityScopedResource()
        defer { if accessOK { folder.stopAccessingSecurityScopedResource() } }

        let url = folder.appendingPathComponent(syncFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        let currentMtime = fileModificationDate(at: url)
        if !force {
            let lastImported = UserDefaults.standard.object(forKey: lastImportedMtimeKey) as? Date ?? .distantPast
            if let mtime = currentMtime, mtime <= lastImported {
                return false
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let snap = try decoder.decode(Snapshot.self, from: data)

            // 自端末の書込みなら取り込まない
            if let fp = snap.fingerprint?.uuidString,
               let lastFp = UserDefaults.standard.string(forKey: lastWriteFingerprintKey),
               fp == lastFp {
                if let mtime = currentMtime {
                    UserDefaults.standard.set(mtime, forKey: lastImportedMtimeKey)
                }
                return false
            }

            try upsert(snapshot: snap, into: context)
            if let mtime = currentMtime {
                UserDefaults.standard.set(mtime, forKey: lastImportedMtimeKey)
            }
            NSLog("[BackupService] sync 取り込み完了 force=\(force) fp=\(snap.fingerprint?.uuidString.prefix(8) ?? "nil")")
            return true
        } catch {
            NSLog("[BackupService] sync 読込み失敗: \(error)")
            return false
        }
    }

    /// 同期フォルダにファイルが既に存在するか。
    func syncFileExists() -> Bool {
        guard let folder = resolveSyncFolder() else { return false }
        let accessOK = folder.startAccessingSecurityScopedResource()
        defer { if accessOK { folder.stopAccessingSecurityScopedResource() } }
        let url = folder.appendingPathComponent(syncFileName)
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func fileModificationDate(at url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    // MARK: - Upsert (sync 用、id 一致で更新、新規は挿入。削除は伝播しない)
    // UserSettings は除外 (iOS と Mac で異なるため)

    private func upsert(snapshot snap: Snapshot, into context: ModelContext) throws {
        // 既存エンティティを id でインデックス
        var taskMap: [UUID: TaskItem] = [:]
        for t in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] { taskMap[t.id] = t }
        var sessionMap: [UUID: PomodoroSession] = [:]
        for s in (try? context.fetch(FetchDescriptor<PomodoroSession>())) ?? [] { sessionMap[s.id] = s }
        var entryMap: [UUID: TimelineEntry] = [:]
        for e in (try? context.fetch(FetchDescriptor<TimelineEntry>())) ?? [] { entryMap[e.id] = e }
        var goalMap: [UUID: MonthlyGoal] = [:]
        for g in (try? context.fetch(FetchDescriptor<MonthlyGoal>())) ?? [] { goalMap[g.id] = g }

        // TaskItem
        for dto in snap.tasks {
            if let t = taskMap[dto.id] {
                t.title = dto.title
                t.note = dto.note
                t.categoryRaw = dto.categoryRaw
                t.isDone = dto.isDone
                t.completedAt = dto.completedAt
                t.sourceGoalID = dto.sourceGoalID
                t.pomodoroCount = dto.pomodoroCount
                t.sortOrder = dto.sortOrder
                t.deferredUntil = dto.deferredUntil
                t.scheduledDate = dto.scheduledDate
                t.externalEventID = dto.externalEventID
                if let v = dto.totalSeconds { t.totalSeconds = v }
                if let raw = dto.lifeAreaRaw { t.lifeAreaRaw = raw }
                if let tag = dto.tag { t.tag = tag }
            } else {
                let t = TaskItem(
                    id: dto.id, title: dto.title, note: dto.note,
                    category: TaskCategory(rawValue: dto.categoryRaw) ?? .normal,
                    isDone: dto.isDone, createdAt: dto.createdAt,
                    completedAt: dto.completedAt, sourceGoalID: dto.sourceGoalID,
                    pomodoroCount: dto.pomodoroCount,
                    totalSeconds: dto.totalSeconds ?? 0,
                    sortOrder: dto.sortOrder,
                    deferredUntil: dto.deferredUntil,
                    scheduledDate: dto.scheduledDate,
                    externalEventID: dto.externalEventID,
                    lifeArea: LifeArea(rawValue: dto.lifeAreaRaw ?? "") ?? .work,
                    tag: dto.tag
                )
                context.insert(t)
                taskMap[dto.id] = t
            }
        }

        // PomodoroSession (task 参照解決)
        for dto in snap.sessions {
            let taskRef = dto.taskID.flatMap { taskMap[$0] }
            if let s = sessionMap[dto.id] {
                s.startedAt = dto.startedAt
                s.endedAt = dto.endedAt
                s.plannedDurationSec = dto.plannedDurationSec
                s.actualDurationSec = dto.actualDurationSec
                s.wasCompleted = dto.wasCompleted
                s.task = taskRef
            } else {
                let s = PomodoroSession(
                    id: dto.id, startedAt: dto.startedAt, endedAt: dto.endedAt,
                    plannedDurationSec: dto.plannedDurationSec,
                    actualDurationSec: dto.actualDurationSec,
                    wasCompleted: dto.wasCompleted,
                    task: taskRef
                )
                context.insert(s)
            }
        }

        // TimelineEntry
        for dto in snap.entries {
            if let e = entryMap[dto.id] {
                e.startAt = dto.startAt
                e.endAt = dto.endAt
                e.taskID = dto.taskID
                e.title = dto.title
                e.categoryRaw = dto.categoryRaw
                e.sourceRaw = dto.sourceRaw
                if let raw = dto.lifeAreaRaw { e.lifeAreaRaw = raw }
            } else {
                let e = TimelineEntry(
                    id: dto.id, startAt: dto.startAt, endAt: dto.endAt,
                    taskID: dto.taskID, title: dto.title,
                    category: TaskCategory(rawValue: dto.categoryRaw) ?? .normal,
                    source: EntrySource(rawValue: dto.sourceRaw) ?? .manual,
                    lifeArea: LifeArea(rawValue: dto.lifeAreaRaw ?? "") ?? .work
                )
                context.insert(e)
            }
        }

        // MonthlyGoal
        for dto in snap.goals {
            if let g = goalMap[dto.id] {
                g.title = dto.title
                g.detail = dto.detail
                g.targetMonth = dto.targetMonth
                g.isAchieved = dto.isAchieved
                g.addedToTasksAt = dto.addedToTasksAt
            } else {
                let g = MonthlyGoal(
                    id: dto.id, title: dto.title, detail: dto.detail,
                    targetMonth: dto.targetMonth, isAchieved: dto.isAchieved,
                    createdAt: dto.createdAt, addedToTasksAt: dto.addedToTasksAt
                )
                context.insert(g)
            }
        }

        // UserSettings は同期対象外 (Mac/iOS 互換性問題のため)

        try context.save()
    }
}
