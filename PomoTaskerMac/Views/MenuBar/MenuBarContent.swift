//
//  MenuBarContent.swift
//  PomoTaskerMac
//
//  メニューバーポップアップの中身。
//  - タイマー状態表示 (フェーズ / 残り時間 / タスク名)
//  - 操作ボタン (一時停止 / 再開 / 中断)
//  - メインウィンドウ起動 / アプリ終了
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct MenuBarContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PomodoroTimerService.self) private var timer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack(spacing: 8) {
                RondoLogo(size: 22)
                Text("Rondo")
                    .font(.headline)
                Spacer()
            }

            Divider()

            if timer.state == .idle {
                idleContent
            } else {
                activeContent
            }

            Divider()

            // フッター: ウィンドウ表示 / 終了
            HStack {
                Button {
                    activateMainWindow()
                } label: {
                    Label("メインウィンドウ", systemImage: "macwindow")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("終了", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 260)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("タイマー停止中")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("メインウィンドウからタスクを選んで開始してください。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Active (running / paused / finished)

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // フェーズバッジ + 残り時間
            HStack {
                Image(systemName: timer.currentPhase.systemImage)
                    .foregroundStyle(phaseColor)
                Text(phaseLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(phaseColor)
                Spacer()
                Text(timer.mode == .countUp ? timer.formattedElapsed : timer.formattedRemaining)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
            }

            // タスク名
            if let task = timer.currentTask {
                HStack(spacing: 6) {
                    CategoryBadge(category: task.category, style: .icon)
                    Text(task.title)
                        .font(.caption)
                        .lineLimit(2)
                }
            } else {
                Text(timer.mode == .countUp ? "フリータイマー" : "フリーポモドーロ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 操作ボタン
            HStack(spacing: 8) {
                if timer.state == .running {
                    Button {
                        timer.pause()
                    } label: {
                        Label("一時停止", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if timer.state == .paused {
                    Button {
                        timer.resume()
                    } label: {
                        Label("再開", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if timer.state == .running || timer.state == .paused {
                    Button {
                        timer.cancel(in: modelContext)
                    } label: {
                        Label("中断", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
            .font(.caption)

            // 休憩スキップ (ポモモードの休憩中のみ)
            if timer.mode == .pomodoro && timer.currentPhase == .shortBreak && timer.state == .running {
                Button {
                    timer.skipBreak()
                } label: {
                    Label("休憩をスキップ", systemImage: "forward.fill")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private var phaseLabel: String {
        if timer.mode == .countUp { return "カウントアップ" }
        return timer.currentPhase.label
    }

    private var phaseColor: Color {
        if timer.currentPhase == .shortBreak && timer.state != .idle {
            return .green
        }
        return timer.currentTask?.category.color ?? .accentColor
    }

    private func activateMainWindow() {
        #if canImport(AppKit)
        NSApp.activate(ignoringOtherApps: true)
        // メインウィンドウを前面表示
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        #endif
    }
}
