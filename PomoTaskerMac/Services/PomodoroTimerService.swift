//
//  PomodoroTimerService.swift
//  PomoTaskerMac
//
//  ポモドーロタイマーの状態と制御。作業↔休憩の連続サイクル対応。
//  残り時間は endDate - Date.now から算出することで
//  スリープからの復帰時も正確。
//
//  iOS版から移植: LiveActivityService 呼び出しを全削除、
//  Haptic を AppKit (NSHapticFeedbackManager) ベースに置換。
//

import Foundation
import SwiftUI
import SwiftData
import Observation
#if canImport(AppKit)
import AppKit
#endif

@Observable
@MainActor
final class PomodoroTimerService {

    // MARK: - Enums

    enum State: Equatable {
        case idle       // 未開始
        case running    // カウントダウン中
        case paused     // 一時停止
        case finished   // ユーザーが終了(サイクル完全終了)
    }

    enum Phase: String {
        case work
        case shortBreak

        var label: String {
            switch self {
            case .work:       return "作業"
            case .shortBreak: return "休憩"
            }
        }

        var systemImage: String {
            switch self {
            case .work:       return "brain.head.profile"
            case .shortBreak: return "cup.and.saucer.fill"
            }
        }
    }

    /// タイマー動作モード。idle 状態でのみ切替可能。
    enum Mode: String {
        case pomodoro   // 従来のカウントダウン(作業↔休憩)
        case countUp    // フリーカウントアップ(経過時間を加算)
    }

    // MARK: - State

    private(set) var state: State = .idle
    private(set) var currentPhase: Phase = .work
    private(set) var currentTask: TaskItem?

    /// 現在のタイマー動作モード
    private(set) var mode: Mode = .pomodoro

    /// セッション全体の設定
    private(set) var workDurationSec: Int = 25 * 60
    private(set) var breakDurationSec: Int = 5 * 60

    /// 現在フェーズの残り秒数
    private(set) var remainingSec: Int = 25 * 60

    /// カウントアップモードの経過秒数
    private(set) var elapsedSec: Int = 0

    /// 現サイクル中に完走した作業フェーズ数(タスクのポモ回数ではない)
    private(set) var cyclesCompleted: Int = 0

    /// フェーズ0秒到達フラグ(View側で observe → advancePhase を呼ぶ)
    private(set) var phaseCompletionSignal: Int = 0

    // MARK: - Internal

    private var endDate: Date?
    private var pausedRemainingSec: Int?
    private var phaseStartedAt: Date?
    /// フェーズ開始時に握ったタスクのスナップショット。保存時は currentTask ではなくこれを使う。
    /// 走行中に currentTask が切り替わった場合でも、ログ記録が取り違わないようにするため。
    private var phaseStartedTask: TaskItem?
    private var tickTask: Task<Void, Never>?

    /// カウントアップ用: 開始時刻。 Date 基準で経過秒数を算出するため、スリープ復帰にも強い。
    private var countUpStartedAt: Date?
    /// カウントアップ用: 一時停止時に累積されていた秒数。再開時に加算起点として使う。
    private var countUpPausedElapsed: Int = 0

    // MARK: - Public API

    /// idle 時のみモード切替可能。走行中は無視。
    func setMode(_ newMode: Mode) {
        guard state == .idle else { return }
        mode = newMode
    }

    /// サイクル開始(作業フェーズから)。
    /// 既に走行中/一時停止中の場合は、先に経過分を部分セッションとして保存してから
    /// 新しいタスクで再開する(タスク切替の明示サポート)。
    func start(task: TaskItem?, workSec: Int, breakSec: Int, in modelContext: ModelContext) {
        // 走行中/一時停止中のまま呼ばれた場合: 古いタスクの経過分を先に確定
        if state == .running || state == .paused {
            saveInProgressIfNeeded(in: modelContext)
            NotificationService.shared.cancelAll()
        }

        stopTicker()
        self.mode = .pomodoro
        self.currentTask = task
        self.workDurationSec = workSec
        self.breakDurationSec = breakSec
        self.cyclesCompleted = 0
        self.currentPhase = .work
        beginPhase(phase: .work, durationSec: workSec)
        Haptic.impact(.medium)

        // 通知許可を要求(必要時のみ)
        Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
    }

    /// カウントアップモード開始。タスクに紐づく実働時間を計測する。
    /// pomodoro モード同様、走行中に呼ばれた場合は先に経過分を保存してから切り替える。
    func startCountUp(task: TaskItem?, in modelContext: ModelContext) {
        if state == .running || state == .paused {
            saveInProgressIfNeeded(in: modelContext)
            NotificationService.shared.cancelAll()
        }

        stopTicker()
        self.mode = .countUp
        self.currentTask = task
        self.currentPhase = .work  // 表示色は作業扱い
        self.cyclesCompleted = 0
        self.elapsedSec = 0
        self.countUpStartedAt = .now
        self.countUpPausedElapsed = 0
        self.phaseStartedAt = .now
        self.phaseStartedTask = task
        self.endDate = nil
        self.pausedRemainingSec = nil
        self.remainingSec = 0
        state = .running
        startTicker()
        Haptic.impact(.medium)
    }

    func pause() {
        guard state == .running else { return }

        switch mode {
        case .pomodoro:
            guard let endDate else { return }
            let remain = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
            pausedRemainingSec = remain
            remainingSec = remain
            self.endDate = nil
            state = .paused
            stopTicker()
            NotificationService.shared.cancelAll()

        case .countUp:
            // 現在の経過秒数を固定
            let total = currentCountUpElapsed()
            countUpPausedElapsed = total
            elapsedSec = total
            countUpStartedAt = nil
            state = .paused
            stopTicker()
        }

        Haptic.impact(.light)
    }

    func resume() {
        guard state == .paused else { return }

        switch mode {
        case .pomodoro:
            guard let paused = pausedRemainingSec else { return }
            let end = Date.now.addingTimeInterval(TimeInterval(paused))
            endDate = end
            pausedRemainingSec = nil
            state = .running
            startTicker()

            // 通知を再予約
            NotificationService.shared.schedulePhaseCompletionNotification(
                fireAt: end,
                phaseEnding: currentPhase,
                taskTitle: currentTask?.title
            )

        case .countUp:
            // 累積秒数を起点に再開。startedAt を「今 - 累積秒」に補正する。
            let newStart = Date.now.addingTimeInterval(-TimeInterval(countUpPausedElapsed))
            countUpStartedAt = newStart
            state = .running
            startTicker()
        }

        Haptic.impact(.light)
    }

    /// 実行中↔一時停止をトグル。画面タップで呼ぶ想定。
    func togglePauseResume() {
        switch state {
        case .running: pause()
        case .paused:  resume()
        default:       break
        }
    }

    /// サイクル全体を終了(中断)。
    /// 作業フェーズで 10 秒以上経過していた場合、未完走セッションとして
    /// PomodoroSession / TimelineEntry を保存する(ロギング継続のため)。
    /// カウントアップ時も同様に経過分を保存する(むしろ正常終了扱いに近い)。
    func cancel(in modelContext: ModelContext) {
        saveInProgressIfNeeded(in: modelContext)
        stopTicker()
        NotificationService.shared.cancelAll()
        reset()
    }

    /// モデルコンテキスト無しでの強制終了(ロギングなし、緊急リセット用)。
    func forceCancelWithoutLogging() {
        stopTicker()
        NotificationService.shared.cancelAll()
        reset()
    }

    /// カウントアップを明示的に終了(保存して idle に戻す)。cancel() と同挙動だが、
    /// UI 側で「停止」ボタンとして使うとき用のエイリアス。
    func stopCountUp(in modelContext: ModelContext) {
        guard mode == .countUp else { return }
        cancel(in: modelContext)
    }

    /// 休憩をスキップして即座に次の作業フェーズへ移行。
    func skipBreak() {
        guard currentPhase == .shortBreak else { return }
        stopTicker()
        beginPhase(phase: .work, durationSec: workDurationSec)
        Haptic.impact(.light)
    }

    /// フォアグラウンド復帰時に呼び出す。経過時間を超えたフェーズを自動進行する。
    /// 通知によりバックグラウンドでフェーズ完了していた場合のキャッチアップ処理。
    func reconcilePhaseIfExpired(in modelContext: ModelContext) {
        var safety = 20
        while state == .running, let endDate, endDate.timeIntervalSinceNow <= 0, safety > 0 {
            advancePhase(in: modelContext)
            safety -= 1
        }
        // 表示用の残り時間を同期
        if state == .running, let endDate {
            remainingSec = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
        }
    }

    /// フェーズ0秒到達時に View から呼ばれる。
    /// 作業フェーズ完了ならセッション保存→休憩フェーズ開始。
    /// 休憩フェーズ完了なら次の作業フェーズ開始。
    func advancePhase(in modelContext: ModelContext) {
        switch currentPhase {
        case .work:
            saveWorkSession(in: modelContext)
            cyclesCompleted += 1
            beginPhase(phase: .shortBreak, durationSec: breakDurationSec)
            Haptic.notification(.success)

        case .shortBreak:
            beginPhase(phase: .work, durationSec: workDurationSec)
            Haptic.impact(.medium)
        }
    }

    /// 初期状態に戻す。mode は維持(UI 側の選択を尊重)。
    func reset() {
        currentTask = nil
        currentPhase = .work
        workDurationSec = 25 * 60
        breakDurationSec = 5 * 60
        remainingSec = workDurationSec
        elapsedSec = 0
        cyclesCompleted = 0
        endDate = nil
        pausedRemainingSec = nil
        phaseStartedAt = nil
        phaseStartedTask = nil
        countUpStartedAt = nil
        countUpPausedElapsed = 0
        state = .idle
    }

    /// idle 時のみ currentTask を差し替え可能(start 前の選択用)。
    /// 走行中/一時停止中は `start(task:...)` を使うこと(旧タスクの経過分が保存される)。
    func setCurrentTask(_ task: TaskItem?) {
        guard state == .idle else { return }
        currentTask = task
    }

    // MARK: - Phase management

    private func beginPhase(phase: Phase, durationSec: Int) {
        currentPhase = phase
        remainingSec = durationSec
        phaseStartedAt = .now
        // このフェーズの記録に使うタスクをここで確定(以後 currentTask が差し替わっても影響しない)
        phaseStartedTask = currentTask
        let end = Date.now.addingTimeInterval(TimeInterval(durationSec))
        endDate = end
        pausedRemainingSec = nil
        state = .running
        startTicker()

        // 通知予約: このフェーズが終わる時刻に発火
        NotificationService.shared.schedulePhaseCompletionNotification(
            fireAt: end,
            phaseEnding: phase,
            taskTitle: currentTask?.title
        )
    }

    private func saveWorkSession(in modelContext: ModelContext) {
        let now = Date.now
        let started = phaseStartedAt ?? now.addingTimeInterval(-TimeInterval(workDurationSec))
        // フェーズ開始時に握ったタスクで記録(SSoT + 取り違え防止)
        let task = phaseStartedTask

        let session = PomodoroSession(
            startedAt: started,
            endedAt: now,
            plannedDurationSec: workDurationSec,
            actualDurationSec: workDurationSec,
            wasCompleted: true,
            task: task
        )
        modelContext.insert(session)

        if let task {
            task.pomodoroCount += 1
            // 累計実働秒数を加算(非正規化: 集計高速化のため冗長保持)
            task.totalSeconds += workDurationSec
        }

        mergeOrInsertPomodoroEntry(
            startAt: started,
            endAt: now,
            task: task,
            in: modelContext
        )
    }

    /// 走行中(running/paused)の経過分を部分セッションとして保存する。
    /// モードに応じて pomodoro(作業フェーズのみ)/countUp(常に経過時間)のどちらかを保存。
    /// 10秒未満の経過はノイズ扱いで保存しない(従来仕様)。
    private func saveInProgressIfNeeded(in modelContext: ModelContext, minimumSeconds: Int = 10) {
        guard state == .running || state == .paused else { return }

        switch mode {
        case .pomodoro:
            saveInProgressWorkIfNeeded(in: modelContext, minimumSeconds: minimumSeconds)
        case .countUp:
            saveCountUpSession(in: modelContext, minimumSeconds: minimumSeconds)
        }
    }

    /// 作業フェーズが途中で中断された時、経過分を部分セッションとして保存。
    /// 10秒未満の経過はノイズ扱いで保存しない(従来仕様)。
    private func saveInProgressWorkIfNeeded(in modelContext: ModelContext, minimumSeconds: Int = 10) {
        guard currentPhase == .work,
              let startedAt = phaseStartedAt else { return }

        // 実働秒数を Date 基準で正確に計算
        let elapsed: Int
        if state == .paused, let paused = pausedRemainingSec {
            elapsed = max(0, workDurationSec - paused)
        } else if let end = endDate {
            let remaining = max(0, Int(end.timeIntervalSinceNow.rounded()))
            elapsed = max(0, workDurationSec - remaining)
        } else {
            elapsed = 0
        }

        guard elapsed >= minimumSeconds else { return }
        let endedAt = startedAt.addingTimeInterval(TimeInterval(elapsed))
        let task = phaseStartedTask

        let session = PomodoroSession(
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDurationSec: workDurationSec,
            actualDurationSec: elapsed,
            wasCompleted: false,
            task: task
        )
        modelContext.insert(session)

        // 累計実働秒数を加算(非正規化)
        if let task {
            task.totalSeconds += elapsed
        }

        mergeOrInsertPomodoroEntry(
            startAt: startedAt,
            endAt: endedAt,
            task: task,
            in: modelContext
        )

        // 確実に永続化
        try? modelContext.save()
    }

    /// カウントアップの経過分をセッション+タイムラインに保存。
    /// カウントアップは「中断=正常終了」扱いなので wasCompleted=true とする。
    private func saveCountUpSession(in modelContext: ModelContext, minimumSeconds: Int = 10) {
        guard let startedAt = phaseStartedAt else { return }
        let elapsed = currentCountUpElapsed()
        guard elapsed >= minimumSeconds else { return }
        let endedAt = startedAt.addingTimeInterval(TimeInterval(elapsed))
        let task = phaseStartedTask

        let session = PomodoroSession(
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDurationSec: elapsed,
            actualDurationSec: elapsed,
            wasCompleted: true,
            task: task
        )
        modelContext.insert(session)

        if let task {
            task.totalSeconds += elapsed
        }

        mergeOrInsertPomodoroEntry(
            startAt: startedAt,
            endAt: endedAt,
            task: task,
            in: modelContext
        )

        try? modelContext.save()
    }

    /// カウントアップの経過秒を取得。
    /// running 時は Date 基準(startedAt は resume で「今 - 累積秒」に補正済み)。
    /// paused 時は固定された countUpPausedElapsed を返す。
    private func currentCountUpElapsed() -> Int {
        if state == .paused {
            return countUpPausedElapsed
        }
        guard let started = countUpStartedAt else { return countUpPausedElapsed }
        return max(0, Int(Date.now.timeIntervalSince(started).rounded()))
    }

    /// 直近の同タスク TimelineEntry と時間が近接していれば統合、そうでなければ新規挿入。
    /// しきい値: UserSettings.longBreakMinutes + 2 分(休憩を挟んだ連続実行を1ブロックにまとめる)。
    private func mergeOrInsertPomodoroEntry(
        startAt: Date,
        endAt: Date,
        task: TaskItem?,
        in modelContext: ModelContext
    ) {
        let thresholdSec = Self.resolveMergeThresholdSec(in: modelContext)
        let lowerBound = startAt.addingTimeInterval(-TimeInterval(thresholdSec))
        let pomodoroRaw = EntrySource.pomodoro.rawValue

        var desc = FetchDescriptor<TimelineEntry>(
            predicate: #Predicate { entry in
                entry.sourceRaw == pomodoroRaw &&
                entry.endAt >= lowerBound &&
                entry.endAt <= startAt
            },
            sortBy: [SortDescriptor(\.endAt, order: .reverse)]
        )
        desc.fetchLimit = 5

        let candidates = (try? modelContext.fetch(desc)) ?? []
        let taskID = task?.id
        // 直近の中から、taskID が一致する(両方 nil も一致)最初のものを選ぶ
        if let existing = candidates.first(where: { $0.taskID == taskID }) {
            // 統合: endAt を延長。title/category は既存の方を尊重(最初に記録された状態を維持)。
            if endAt > existing.endAt {
                existing.endAt = endAt
            }
        } else {
            let entry = TimelineEntry(
                startAt: startAt,
                endAt: endAt,
                taskID: taskID,
                title: task?.title ?? "ポモドーロ",
                category: task?.category ?? .normal,
                source: .pomodoro
            )
            modelContext.insert(entry)
        }
    }

    /// 連続タスク統合のしきい値を UserSettings から解決。未作成時は既定 (15 + 2) 分。
    private static func resolveMergeThresholdSec(in modelContext: ModelContext) -> Int {
        let desc = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(desc).first {
            return (settings.longBreakMinutes + 2) * 60
        }
        return (15 + 2) * 60
    }

    // MARK: - Ticker

    private func startTicker() {
        tickTask = Task { @MainActor [weak self] in
            // 安全装置: 最大24時間でタイムアウト(異常な長時間実行を防ぐ)
            let maxIterations = 24 * 60 * 60 * 4 // 24時間 × 4回/秒
            var iterations = 0

            while !Task.isCancelled && iterations < maxIterations {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25秒毎
                guard let self else { return }

                self.tick()

                // running 以外なら終了
                if self.state != .running {
                    break
                }

                iterations += 1
            }
        }
    }

    private func stopTicker() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        guard state == .running else { return }

        switch mode {
        case .pomodoro:
            guard let endDate else { return }
            let remain = Int(endDate.timeIntervalSinceNow.rounded())
            if remain <= 0 {
                remainingSec = 0
                stopTicker()
                // View側にシグナル: onChange(of: phaseCompletionSignal) で advancePhase を呼ぶ
                phaseCompletionSignal &+= 1
            } else {
                remainingSec = remain
            }

        case .countUp:
            // カウントアップは終了判定なし、経過秒を更新するだけ
            elapsedSec = currentCountUpElapsed()
        }
    }

    // MARK: - Helpers

    var progress: Double {
        switch mode {
        case .pomodoro:
            let total = currentPhase == .work ? workDurationSec : breakDurationSec
            guard total > 0 else { return 0 }
            let done = total - remainingSec
            return max(0, min(1, Double(done) / Double(total)))
        case .countUp:
            // カウントアップは無限進行なので、1時間を目安に 0〜1 をループさせる(装飾目的)
            let loop = 60 * 60
            return Double(elapsedSec % loop) / Double(loop)
        }
    }

    var formattedRemaining: String {
        let s = max(0, remainingSec)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// カウントアップの経過時間を表示用にフォーマット。
    /// 1時間未満は MM:SS、1時間以上は HH:MM:SS。
    var formattedElapsed: String {
        let s = max(0, elapsedSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Haptic Helper (macOS)

/// macOS の Haptic は NSHapticFeedbackManager 経由(トラックパッド対応機のみ動作)。
/// 非対応機では no-op になるので呼び出し側は気にしなくて良い。
enum Haptic {
    static func impact(_ style: ImpactStyle) {
        #if canImport(AppKit)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        #endif
    }

    static func notification(_ type: NotificationType) {
        #if canImport(AppKit)
        let pattern: NSHapticFeedbackManager.FeedbackPattern = (type == .success) ? .alignment : .levelChange
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
        #endif
    }

    enum ImpactStyle {
        case light, medium, heavy
    }

    enum NotificationType {
        case success, warning, error
    }
}
