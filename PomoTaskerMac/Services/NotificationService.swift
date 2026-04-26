//
//  NotificationService.swift
//  PomoTaskerMac
//
//  ローカル通知(フェーズ完了音+バナー)のラッパー。
//  iOS版から移植 (identifier を Mac 用に変更、それ以外は同一)。
//

import Foundation
import UserNotifications
import Observation

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let pomodoroIdentifier = "com.sly.PomoTaskerMac.pomodoro.phase"

    private init() {}

    /// 初回起動時に呼ぶ。通知許可の状態を取得(要求はしない)。
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 必要時のみ許可を要求。既に許可済みなら何もしない。
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await currentAuthorizationStatus()
        switch status {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            } catch {
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// フェーズ完了通知を指定日時で予約。既存のポモ関連通知はキャンセル。
    func schedulePhaseCompletionNotification(
        fireAt: Date,
        phaseEnding: PomodoroTimerService.Phase,
        taskTitle: String?
    ) {
        cancelAll()

        let content = UNMutableNotificationContent()
        switch phaseEnding {
        case .work:
            content.title = "作業セット完了"
            content.body = taskTitle.map { "「\($0)」 お疲れ様です。休憩を開始しました。" }
                ?? "お疲れ様です。休憩を開始しました。"
        case .shortBreak:
            content.title = "休憩終了"
            content.body = "次の作業セットを開始しました。"
        }
        content.sound = .default

        let interval = max(1, fireAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: pomodoroIdentifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// ポモ関連の予約通知をすべてキャンセル。
    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [pomodoroIdentifier])
    }
}
