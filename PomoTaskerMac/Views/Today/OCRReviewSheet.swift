//
//  OCRReviewSheet.swift
//  PomoTaskerMac
//
//  OCR結果を確認・編集 → 一括追加するシート (Mac版)。
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct OCRReviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allTasks: [TaskItem]
    @Query private var ocrCorrections: [OCRCorrection]

    @State var candidates: [CandidateRow]
    @State private var defaultCategory: TaskCategory = .normal
    @State private var showRawCandidates: Bool = false
    @State private var isAIRunning: Bool = false
    @State private var didApplyDictionary: Bool = false

    struct CandidateRow: Identifiable {
        let id = UUID()
        var text: String
        /// OCR の生 raw (補正前)。学習 (OCRCorrection upsert) 用。
        var originalRaw: String
        var category: TaskCategory?
        var groupName: String?
        var isSelected: Bool
        var rawCandidates: [String] = []
    }

    private var existingTags: [String] {
        var counter: [String: Int] = [:]
        for t in allTasks {
            guard let tag = t.tag?.trimmingCharacters(in: .whitespaces), !tag.isEmpty else { continue }
            counter[tag, default: 0] += 1
        }
        return counter.sorted { $0.value > $1.value }.map { $0.key }
    }

    init(lines: [String]) {
        _candidates = State(initialValue: lines.map {
            CandidateRow(
                text: $0, originalRaw: $0,
                category: nil, groupName: nil, isSelected: !$0.isEmpty
            )
        })
    }

    init(recognized: [OCRService.RecognizedLine]) {
        _candidates = State(initialValue: recognized.map {
            CandidateRow(
                text: $0.text,
                originalRaw: $0.text,
                category: $0.category,
                groupName: $0.groupName,
                isSelected: !$0.text.isEmpty,
                rawCandidates: $0.rawCandidates
            )
        })
    }

    private var selectedCount: Int {
        candidates.filter { $0.isSelected && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("デフォルト分類") {
                        CategorySelector(selection: $defaultCategory)
                            .frame(maxWidth: 320)
                    }
                    Toggle(isOn: $showRawCandidates) {
                        Label("生認識結果を表示", systemImage: "text.magnifyingglass")
                    }
                } header: {
                    sectionHeader("一括設定", systemImage: "slider.horizontal.3")
                } footer: {
                    Text("各行で個別に分類を上書き可能。「生認識結果」は誤認識の原因特定用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if candidates.isEmpty {
                        Text("検出された行はありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($candidates) { $row in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    Button {
                                        row.isSelected.toggle()
                                    } label: {
                                        Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(row.isSelected ? Color.accentColor : .secondary)
                                            .contentTransition(.symbolEffect(.replace))
                                    }
                                    .buttonStyle(.plain)

                                    TextField("タスクを入力", text: $row.text, axis: .vertical)
                                        .lineLimit(1...3)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(!row.isSelected)
                                }

                                // メタ情報行 (カテゴリ + グループ名)
                                HStack(spacing: 8) {
                                    Menu {
                                        Button {
                                            row.category = nil
                                        } label: {
                                            Label("(デフォルト)", systemImage: row.category == nil ? "checkmark" : "")
                                        }
                                        Divider()
                                        ForEach(TaskCategory.allCasesByPriority) { cat in
                                            Button {
                                                row.category = cat
                                            } label: {
                                                Label(cat.label, systemImage: cat.symbolName)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            if let c = row.category {
                                                Image(systemName: c.symbolName)
                                                    .foregroundStyle(c.color)
                                                Text(c.label)
                                                    .foregroundStyle(c.color)
                                            } else {
                                                Text("(デフォルト)")
                                                    .foregroundStyle(.secondary)
                                            }
                                            Image(systemName: "chevron.up.chevron.down")
                                                .foregroundStyle(.secondary)
                                                .font(.caption2)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(NSColor.controlBackgroundColor), in: Capsule())
                                    }
                                    .menuStyle(.borderlessButton)
                                    .fixedSize()
                                    .disabled(!row.isSelected)

                                    if let group = row.groupName, !group.isEmpty {
                                        Button {
                                            row.groupName = nil
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "folder.fill")
                                                Text(group)
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!row.isSelected)
                                    }

                                    Spacer()
                                }
                                .padding(.leading, 28)

                                // 生認識結果デバッグ表示
                                if showRawCandidates, !row.rawCandidates.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(Array(row.rawCandidates.enumerated()), id: \.offset) { idx, cand in
                                            Text("[\(idx + 1)] \(cand)")
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                    .padding(.leading, 28)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    sectionHeader("検出された行 (\(selectedCount) 件選択中)", systemImage: "list.bullet.rectangle")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("OCR結果を確認")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(selectedCount) 件追加") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedCount == 0)
                }
            }
            .frame(minWidth: 580, minHeight: 600)
            .task {
                // 起動時に1回: 辞書補正 → AI 補正 (順次)
                guard !didApplyDictionary else { return }
                didApplyDictionary = true
                applyDictionaryCorrection()
                await applyIntelligentCorrection()
            }
            .overlay(alignment: .top) {
                if isAIRunning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("AI 補正中…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - OCR Correction Pipeline

    /// 起動時の同期辞書補正 (補正履歴 + 既存タスクタイトル)。
    private func applyDictionaryCorrection() {
        let knownTitles = OCRDictionary.knownTitles(from: allTasks)
        for i in candidates.indices {
            let raw = candidates[i].text
            let corrected = OCRDictionary.correct(
                raw,
                corrections: ocrCorrections,
                knownTitles: knownTitles
            )
            if corrected != raw {
                candidates[i].text = corrected
            }
        }
    }

    /// Apple Intelligence 補正 (対応端末のみ、非同期)。
    private func applyIntelligentCorrection() async {
        guard IntelligentOCRCorrector.isAvailable else { return }
        isAIRunning = true
        let rawTexts = candidates.map { $0.text }
        let knownTitles = OCRDictionary.knownTitles(from: allTasks)
        let corrected = await IntelligentOCRCorrector.correct(
            rawTexts: rawTexts,
            knownTitles: knownTitles
        )
        if corrected.count == candidates.count {
            for i in candidates.indices where corrected[i] != candidates[i].text {
                candidates[i].text = corrected[i]
            }
        }
        isAIRunning = false
    }

    private func save() {
        let now = Date.now
        var order = 0
        let registeredTags = existingTags
        for row in candidates {
            let trimmed = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard row.isSelected, !trimmed.isEmpty else { continue }

            // 学習: raw と修正後が異なれば OCRCorrection を upsert (次回以降の自動補正用)
            OCRDictionary.upsertCorrection(
                rawText: row.originalRaw,
                correctedText: trimmed,
                in: ocrCorrections,
                insert: { modelContext.insert($0) }
            )

            let tagValue: String? = {
                guard let g = row.groupName?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return nil }
                return TagMatcher.bestMatch(for: g, in: registeredTags) ?? g
            }()
            let task = TaskItem(
                title: trimmed,
                category: row.category ?? defaultCategory,
                createdAt: now.addingTimeInterval(Double(order) * 0.001),
                sortOrder: order,
                tag: tagValue
            )
            modelContext.insert(task)
            order += 1
        }
        dismiss()
    }

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
}
