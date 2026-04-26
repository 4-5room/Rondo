//
//  ContentView.swift
//  PomoTaskerMac
//
//  メインウィンドウ。NavigationSplitView で左サイドバー + 詳細ビュー。
//  Today/Timeline/Stats/Goals/Settings + PomodoroView (sheet表示) を実装。
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PomodoroTimerService.self) private var pomodoroService

    @Query private var settingsList: [UserSettings]

    @State private var selection: Section? = .today
    @State private var todayDate: Date = .now
    @State private var pendingPomodoroTask: TaskItem?
    @State private var showingPomodoro = false

    /// UserSettings から palette / theme を解決 (なければデフォルト)。
    private var palette: ColorPalette {
        settingsList.first?.palette ?? .pastel
    }
    private var preferredScheme: ColorScheme? {
        // パレット側に強制スキームがあればそれを優先
        if let forced = palette.prefersScheme { return forced }
        return settingsList.first?.theme.colorScheme
    }

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case today, timeline, stats, goals, settings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .today:    return "Today"
            case .timeline: return "Timeline"
            case .stats:    return "Stats"
            case .goals:    return "Goals"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .today:    return "checklist"
            case .timeline: return "calendar.day.timeline.left"
            case .stats:    return "chart.bar.fill"
            case .goals:    return "target"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.label, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Rondo")
        } detail: {
            detailView(for: selection ?? .today)
        }
        .environment(\.colorPalette, palette)
        .preferredColorScheme(preferredScheme)
        .task {
            // 初回起動時に UserSettings を作成
            if settingsList.isEmpty {
                modelContext.insert(UserSettings())
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingPomodoro) {
            NavigationStack {
                PomodoroView(task: pendingPomodoroTask)
            }
        }
        // タイマーがフェーズ0秒に到達した時、自動でフェーズ進行する。
        // PomodoroView を閉じている間も継続動作させるため ContentView 側で監視。
        .onChange(of: pomodoroService.phaseCompletionSignal) { _, _ in
            if pomodoroService.state == .running {
                pomodoroService.advancePhase(in: modelContext)
            }
        }
    }

    @ViewBuilder
    private func detailView(for section: Section) -> some View {
        switch section {
        case .today:
            NavigationStack {
                TodayView(
                    onStartPomodoro: { task in
                        pendingPomodoroTask = task
                        showingPomodoro = true
                    },
                    externalDate: $todayDate
                )
            }
        case .timeline:
            NavigationStack {
                TimelineView()
            }
        case .stats:
            NavigationStack {
                StatsView(onNavigateToDate: { date in
                    todayDate = date
                    selection = .today
                })
            }
        case .goals:
            NavigationStack {
                GoalsView()
            }
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.colorPalette, .pastel)
        .environment(PomodoroTimerService())
        .modelContainer(
            for: [
                TaskItem.self,
                PomodoroSession.self,
                TimelineEntry.self,
                MonthlyGoal.self,
                UserSettings.self,
            ],
            inMemory: true
        )
}
