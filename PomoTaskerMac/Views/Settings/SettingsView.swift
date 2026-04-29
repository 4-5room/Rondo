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
    @State private var syncFolderName: String? = BackupService.shared.syncFolderDisplayName
    @State private var syncMessage: String?

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

            // デザイン (パレット = カードグリッド + テーマ = セグメント)
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("カラーパレット")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 170), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(ColorPalette.allPresets) { palette in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    current.paletteID = palette.id
                                }
                            } label: {
                                PaletteCard(
                                    palette: palette,
                                    isSelected: current.paletteID == palette.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

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
                Text("カードをクリックでパレット切替。4.5room / ショート動画 / ミュージックはダーク固定。")
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

            // iOS版との同期 (iCloud Drive 共有フォルダ)
            Section {
                LabeledContent("同期フォルダ") {
                    Text(syncFolderName ?? "未設定")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                LabeledContent(syncFolderName == nil ? "選択" : "変更") {
                    Button {
                        pickSyncFolder()
                    } label: {
                        Label(syncFolderName == nil ? "フォルダを選択" : "フォルダを変更",
                              systemImage: "folder.badge.plus")
                    }
                }

                if syncFolderName != nil {
                    LabeledContent("操作") {
                        HStack(spacing: 6) {
                            Button {
                                let ok = BackupService.shared.syncWrite(context: modelContext)
                                syncMessage = ok ? "✓ 書き出しました" : "書き出しに失敗 (フォルダ再選択を)"
                            } label: {
                                Label("書き出し", systemImage: "icloud.and.arrow.up")
                            }
                            Button {
                                let imported = BackupService.shared.syncReadIfNewer(context: modelContext, force: true)
                                syncMessage = imported ? "✓ 取り込みました" : "取り込みなし (新しいデータがない or 同じデータ)"
                            } label: {
                                Label("取り込み", systemImage: "icloud.and.arrow.down")
                            }
                            Button(role: .destructive) {
                                BackupService.shared.clearSyncFolder()
                                syncFolderName = nil
                                syncMessage = "同期フォルダを解除しました"
                            } label: {
                                Label("解除", systemImage: "xmark.circle")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if let syncMessage {
                    Text(syncMessage)
                        .font(.caption)
                        .foregroundStyle(syncMessage.contains("失敗") ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                sectionHeader("iOS版と同期 (iCloud Drive)", systemImage: "icloud")
            } footer: {
                Text("iCloud Drive 上の **同じフォルダ** を iOS と Mac の両方で選択すると、起動時とフォアグラウンド復帰時に自動で書き出し/取り込みが行われます。\n削除は同期されません(追加・更新のみ)。設定 (テーマ・パレット等) は端末ごとに独立。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // バックアップ (手動)
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
                sectionHeader("手動バックアップ", systemImage: "externaldrive")
            } footer: {
                Text("全データを JSON ファイルに書き出し/読み込み。インポートは既存データを全置換します。")
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

    // MARK: - Sync folder picker

    /// iCloud Drive 同期フォルダを選択。
    /// 既存ファイルがあれば取り込み優先 (他端末のデータを守るため)。
    private func pickSyncFolder() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "iCloud Drive 内の同期フォルダを選択 (iOS版と同じフォルダを指定)"
        if panel.runModal() == .OK, let url = panel.url {
            let accessOK = url.startAccessingSecurityScopedResource()
            defer { if accessOK { url.stopAccessingSecurityScopedResource() } }
            do {
                try BackupService.shared.setSyncFolder(url: url)
                syncFolderName = url.lastPathComponent

                // 既存ファイルがあれば取り込み優先 (他端末データを守る)
                if BackupService.shared.syncFileExists() {
                    let imported = BackupService.shared.syncReadIfNewer(context: modelContext, force: true)
                    syncMessage = imported
                        ? "✓ 同期フォルダから取り込みました。次回バックグラウンド時に書き出します。"
                        : "同期フォルダを設定しました (取り込みなし)"
                } else {
                    // 初回 (フォルダ空) は即書き出し
                    let wrote = BackupService.shared.syncWrite(context: modelContext)
                    syncMessage = wrote
                        ? "✓ 同期フォルダを設定し、初回書き出しを完了しました"
                        : "同期フォルダを設定しました (書き出しは次回)"
                }
            } catch {
                syncMessage = "設定に失敗: \(error.localizedDescription)"
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
