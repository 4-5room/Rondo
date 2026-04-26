//
//  PomodoroView.swift
//  PomoTaskerMac
//
//  ポモドーロ実行画面 (Mac版)。
//  iOS版から横画面レイアウト・PomodoroTaskListColumn を削除して簡素化。
//  ContentView 側で sheet として表示される前提。
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct PomodoroView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PomodoroTimerService.self) private var timer

    let initialTask: TaskItem?

    @State private var workMinutes: Int = 25
    @State private var breakMinutes: Int = 5

    init(task: TaskItem?) {
        self.initialTask = task
    }

    /// 表示用の currentTask は常に timer 側を正とする(SSoT)。
    private var currentTask: TaskItem? { timer.currentTask }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 16) {
                header

                Spacer(minLength: 8)

                timerDisplay(size: timer.state == .idle ? 200 : 280)

                Spacer(minLength: 8)

                controls
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .frame(minWidth: 520, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if timer.state == .idle || timer.state == .finished {
                        timer.reset()
                    }
                    dismiss()
                } label: {
                    Label("閉じる", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .principal) {
                if timer.state == .running || timer.state == .paused {
                    Text(timer.mode == .countUp ? "カウントアップ" : "ポモドーロ")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if timer.state == .idle {
                timer.reset()
                timer.setCurrentTask(initialTask)
            }
        }
        .tint(accent)
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [accent.opacity(0.18), Color(NSColor.windowBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: timer.currentPhase)
    }

    private var header: some View {
        VStack(spacing: 8) {
            if let currentTask {
                CategoryBadge(category: currentTask.category)
                Text(currentTask.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            } else {
                Text(timer.mode == .countUp ? "フリータイマー" : "フリーポモドーロ")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            if timer.state == .running || timer.state == .paused {
                HStack(spacing: 6) {
                    if timer.mode == .countUp {
                        Image(systemName: "stopwatch")
                        Text("カウントアップ")
                    } else {
                        Image(systemName: timer.currentPhase.systemImage)
                        Text(timer.currentPhase.label)
                        Text("•")
                        Text("\(timer.cyclesCompleted + (timer.currentPhase == .work ? 1 : 0))セット目")
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accent.opacity(0.15), in: Capsule())
            }
        }
    }

    private func timerDisplay(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: 14)

            Circle()
                .trim(from: 0, to: timer.state == .idle ? 0 : timer.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: timer.progress)

            VStack(spacing: 4) {
                Text(timerMainText)
                    .font(.system(size: timerFontSize(for: size), weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if timer.state == .paused {
                    Label("クリックで再開", systemImage: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if timer.state == .running {
                    if timer.mode == .countUp {
                        Text("クリックで一時停止")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(timer.cyclesCompleted > 0 ? "完了 \(timer.cyclesCompleted) セット ・ クリックで一時停止" : "クリックで一時停止")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture {
            if timer.state == .running || timer.state == .paused {
                timer.togglePauseResume()
            }
        }
    }

    private var timerMainText: String {
        if timer.state == .idle {
            return timer.mode == .countUp ? "00:00" : initialTimeString
        }
        return timer.mode == .countUp ? timer.formattedElapsed : timer.formattedRemaining
    }

    private func timerFontSize(for circleSize: CGFloat) -> CGFloat {
        if timer.mode == .countUp && timer.elapsedSec >= 3600 {
            return circleSize * 0.22
        }
        return circleSize * 0.3
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch timer.state {
        case .idle:
            idleControls
        case .running:
            runningControls
        case .paused:
            pausedControls
        case .finished:
            finishedControls
        }
    }

    private var idleControls: some View {
        VStack(spacing: 12) {
            modePicker

            if timer.mode == .pomodoro {
                DurationPicker(
                    label: "作業時間",
                    symbolName: PomodoroTimerService.Phase.work.systemImage,
                    tint: .blue,
                    presets: [15, 25, 45, 60],
                    minutes: $workMinutes
                )

                DurationPicker(
                    label: "休憩時間",
                    symbolName: PomodoroTimerService.Phase.shortBreak.systemImage,
                    tint: .green,
                    range: 1...60,
                    presets: [3, 5, 10, 15],
                    minutes: $breakMinutes
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                        .foregroundStyle(.secondary)
                    Text("時間を計測します。途中で停止するまで加算されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            Button {
                switch timer.mode {
                case .pomodoro:
                    timer.start(
                        task: currentTask,
                        workSec: workMinutes * 60,
                        breakSec: breakMinutes * 60,
                        in: modelContext
                    )
                case .countUp:
                    timer.startCountUp(task: currentTask, in: modelContext)
                }
            } label: {
                Label("スタート", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var modePicker: some View {
        Picker("モード", selection: Binding(
            get: { timer.mode },
            set: { timer.setMode($0) }
        )) {
            Label("ポモドーロ", systemImage: "timer").tag(PomodoroTimerService.Mode.pomodoro)
            Label("フリー", systemImage: "stopwatch").tag(PomodoroTimerService.Mode.countUp)
        }
        .pickerStyle(.segmented)
    }

    private var runningControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                abortButton
                Button {
                    timer.pause()
                } label: {
                    Label("一時停止", systemImage: "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if timer.mode == .pomodoro && timer.currentPhase == .shortBreak {
                Button {
                    timer.skipBreak()
                } label: {
                    Label("休憩をスキップ", systemImage: "forward.fill")
                        .font(.footnote)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            completeTaskButton
        }
    }

    private var pausedControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                abortButton
                Button {
                    timer.resume()
                } label: {
                    Label("再開", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            completeTaskButton
        }
    }

    private var finishedControls: some View {
        Button {
            timer.reset()
            dismiss()
        } label: {
            Label("閉じる", systemImage: "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var completeTaskButton: some View {
        if currentTask != nil && !(currentTask?.isDone ?? true) {
            Button {
                completeTaskAndDismiss()
            } label: {
                Label("タスクを完了", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var abortButton: some View {
        Button {
            cancelAndDismiss()
        } label: {
            Label(timer.mode == .countUp ? "停止" : "中断", systemImage: "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor), in: Capsule())
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func cancelAndDismiss() {
        if timer.state == .running || timer.state == .paused {
            timer.cancel(in: modelContext)
        } else {
            timer.reset()
        }
        dismiss()
    }

    /// タスクを完了状態にして、走行中なら経過分を部分保存してから画面を閉じる。
    private func completeTaskAndDismiss() {
        guard let task = currentTask else {
            dismiss()
            return
        }
        if timer.state == .running || timer.state == .paused {
            timer.cancel(in: modelContext)
        } else {
            timer.reset()
        }
        task.isDone = true
        task.completedAt = .now
        try? modelContext.save()
        Haptic.notification(.success)
        dismiss()
    }

    // MARK: - Helpers

    private var accent: Color {
        if timer.currentPhase == .shortBreak && timer.state != .idle {
            return .green
        }
        return currentTask?.category.color ?? .accentColor
    }

    private var initialTimeString: String {
        String(format: "%02d:00", workMinutes)
    }
}

#Preview {
    NavigationStack {
        PomodoroView(task: TaskItem(title: "論文を読む", category: .special))
    }
    .environment(PomodoroTimerService())
    .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
