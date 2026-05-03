//
//  PomoTaskerMacApp.swift
//  PomoTaskerMac
//
//  Created by R S on 2026/04/26.
//

import SwiftUI
import SwiftData

@main
struct PomoTaskerMacApp: App {
    /// アプリ全体で共有するポモドーロタイマー。
    /// メインウィンドウとメニューバーの両方から参照される。
    @State private var pomodoroService = PomodoroTimerService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            PomodoroSession.self,
            TimelineEntry.self,
            MonthlyGoal.self,
            UserSettings.self,
            OCRCorrection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(pomodoroService)
        }
        .modelContainer(sharedModelContainer)

        // メニューバー常駐 (iOS の Live Activity / Dynamic Island の代替)
        MenuBarExtra {
            MenuBarContent()
                .environment(pomodoroService)
                .modelContainer(sharedModelContainer)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    /// メニューバーの表示 (idle: アイコンのみ / 走行中: アイコン+残り時間)。
    @ViewBuilder
    private var menuBarLabel: some View {
        if pomodoroService.state == .running || pomodoroService.state == .paused {
            Label {
                Text(pomodoroService.mode == .countUp
                     ? pomodoroService.formattedElapsed
                     : pomodoroService.formattedRemaining)
            } icon: {
                Image(systemName: pomodoroService.currentPhase == .shortBreak
                      ? "cup.and.saucer.fill"
                      : "brain.head.profile")
            }
        } else {
            Image(systemName: "timer")
        }
    }
}
