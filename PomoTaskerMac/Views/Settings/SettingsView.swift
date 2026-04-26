//
//  SettingsView.swift
//  PomoTaskerMac
//
//  アプリ全体の設定 (Mac System Settings 風)。
//  LabeledContent + Form(.grouped) でラベル左 / コントロール右の整列。
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var settings: [UserSettings]

    @State private var backupMessage: String?

    /// シングルトン UserSettings を取得 (なければ作成)。
    private var current: UserSettings {
        if let first = settings.first { return first }
        let created = UserSettings()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        Form {
            // デフォルト時間
            Section {
                LabeledContent("作業時間") {
                    Stepper(value: Binding(
                        get: { current.defaultPomodoroMinutes },
                        set: { current.defaultPomodoroMinutes = $0 }
                    ), in: 1...180) {
                        Text("\(current.defaultPomodoroMinutes) 分")
                            .monospacedDigit()
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
                LabeledContent("短休憩") {
                    Stepper(value: Binding(
                        get: { current.shortBreakMinutes },
                        set: { current.shortBreakMinutes = $0 }
                    ), in: 1...60) {
                        Text("\(current.shortBreakMinutes) 分")
                            .monospacedDigit()
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
            } header: {
                sectionHeader("デフォルト時間", systemImage: "timer")
            } footer: {
                Text("新規ポモドーロ起動時の初期値として使用されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // デザイン
            Section {
                LabeledContent("カラーパレット") {
                    Picker("カラーパレット", selection: Binding(
                        get: { current.paletteID },
                        set: { current.paletteID = $0 }
                    )) {
                        ForEach(ColorPalette.allPresets) { palette in
                            HStack {
                                Circle()
                                    .fill(palette.accent)
                                    .frame(width: 10, height: 10)
                                Text(palette.displayName)
                            }.tag(palette.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }

                LabeledContent("テーマ") {
                    Picker("テーマ", selection: Binding(
                        get: { current.theme },
                        set: { current.theme = $0 }
                    )) {
                        ForEach(ThemePreference.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            } header: {
                sectionHeader("デザイン", systemImage: "paintpalette.fill")
            } footer: {
                Text("テーマ(ライト/ダーク)はシステム設定より優先されます。4.5roomパレットはダーク強制です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // メニューバー
            Section {
                Toggle(isOn: Binding(
                    get: { current.menuBarEnabled },
                    set: { current.menuBarEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("メニューバーに常駐")
                        Text("残り時間とタイマー操作をメニューバーから利用可能。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                sectionHeader("メニューバー", systemImage: "menubar.rectangle")
            } footer: {
                Text("OFF にしても次回アプリ起動まで反映されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 通知
            Section {
                LabeledContent("通知設定") {
                    Button {
                        openSystemNotificationSettings()
                    } label: {
                        Label("システム設定を開く", systemImage: "arrow.up.right.square")
                    }
                }
            } header: {
                sectionHeader("通知", systemImage: "bell.badge")
            } footer: {
                Text("ポモドーロ完了時の通知を受け取るには、システム設定で許可が必要です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // バックアップ
            Section {
                LabeledContent("エクスポート") {
                    Button {
                        exportData()
                    } label: {
                        Label("JSON で保存", systemImage: "square.and.arrow.up")
                    }
                }

                LabeledContent("インポート") {
                    Button {
                        importData()
                    } label: {
                        Label("JSON から復元 (全置換)", systemImage: "square.and.arrow.down")
                    }
                }

                if let backupMessage {
                    Text(backupMessage)
                        .font(.caption)
                        .foregroundStyle(backupMessage.contains("失敗") ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                sectionHeader("バックアップ", systemImage: "externaldrive")
            } footer: {
                Text("全タスク・セッション・タイムライン・目標・設定を JSON で書き出し/読み込み。インポートは既存データを全置換します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // About
            Section {
                HStack(spacing: 16) {
                    RondoLogo(size: 72, withRoundedBackground: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rondo")
                            .font(.title2.weight(.semibold))
                        Text("PomoTasker for Mac")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                LabeledContent("バージョン") {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                LabeledContent("Bundle ID") {
                    Text(Bundle.main.bundleIdentifier ?? "(unknown)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LabeledContent("チャンネル") {
                    Link(destination: URL(string: "https://www.youtube.com/@4.5room")!) {
                        Label("4.5room", systemImage: "play.tv.fill")
                    }
                }
            } header: {
                sectionHeader("このアプリ", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// セクションヘッダー (アイコン + タイトル) の共通スタイル。
    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .textCase(nil)
                .font(.headline)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(ver) (\(build))"
    }

    private func openSystemNotificationSettings() {
        #if canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    // MARK: - Backup

    private func exportData() {
        #if canImport(AppKit)
        guard let data = BackupService.shared.exportJSON(context: modelContext) else {
            backupMessage = "エクスポートに失敗しました"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "rondo-backup-\(Date.now.exportFilenameTimestamp()).json"
        panel.message = "バックアップ JSON の保存先を選択"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                backupMessage = "✓ 保存しました: \(url.lastPathComponent)"
            } catch {
                backupMessage = "保存失敗: \(error.localizedDescription)"
            }
        }
        #endif
    }

    private func importData() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "インポートする Rondo バックアップ JSON を選択"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                try BackupService.shared.importJSON(data, into: modelContext)
                backupMessage = "✓ 復元しました: \(url.lastPathComponent)"
            } catch {
                backupMessage = "復元失敗: \(error.localizedDescription)"
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
