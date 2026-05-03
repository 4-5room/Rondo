//
//  AddTaskSheet.swift
//  PomoTaskerMac
//
//  タスク追加シート (Mac System Settings 風)。
//  LabeledContent + Form(.grouped) でラベル左 / コントロール右の整列。
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// タグサジェスト用に既存タスクを取得 (TagInputField に渡す)
    @Query private var existingTasksForTags: [TaskItem]

    let initialDate: Date
    let initialLifeArea: LifeArea

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var category: TaskCategory = .normal
    @State private var lifeArea: LifeArea
    @State private var tag: String = ""
    @State private var scheduledDate: Date
    @FocusState private var titleFocused: Bool

    // OCR
    @State private var ocrRecognized: [OCRService.RecognizedLine]? = nil
    @State private var isProcessingOCR = false
    @State private var ocrError: String? = nil
    @State private var isDropTargeted = false
    private let ocrService = OCRService()

    init(initialDate: Date = .now, initialLifeArea: LifeArea = .work) {
        self.initialDate = initialDate
        self.initialLifeArea = initialLifeArea
        _scheduledDate = State(initialValue: initialDate.startOfDay)
        _lifeArea = State(initialValue: initialLifeArea)
    }

    var body: some View {
        NavigationStack {
            Form {
                // タスク入力
                Section {
                    TextField("タイトル", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .textFieldStyle(.roundedBorder)

                    TextField("メモ (任意)", text: $note, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    sectionHeader("タスク", systemImage: "checklist")
                }

                // 分類
                Section {
                    LabeledContent("分類") {
                        CategorySelector(selection: $category)
                            .frame(maxWidth: 320)
                    }

                    LabeledContent("生活領域") {
                        Picker("生活領域", selection: $lifeArea) {
                            ForEach(LifeArea.allCases) { area in
                                Label(area.label, systemImage: area.systemImage).tag(area)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }

                    LabeledContent("タグ (任意)") {
                        TagInputField(
                            tag: $tag,
                            existingTags: TagSource.uniqueTags(from: existingTasksForTags)
                        )
                        .frame(maxWidth: 320)
                    }
                } header: {
                    sectionHeader("分類とタグ", systemImage: "tag.fill")
                }

                // 予定日
                Section {
                    LabeledContent("予定日") {
                        DatePicker("予定日", selection: $scheduledDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    HStack(spacing: 6) {
                        Spacer()
                        Button("昨日") { scheduledDate = dateOffset(-1) }
                        Button("今日") { scheduledDate = Date.now.startOfDay }
                        Button("明日") { scheduledDate = dateOffset(1) }
                        Button("来週") { scheduledDate = dateOffset(7) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } header: {
                    sectionHeader("予定日", systemImage: "calendar")
                } footer: {
                    Text("過去日にも登録可能。Today画面の日付ナビで切り替えると見えます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // OCR
                Section {
                    ocrDropArea

                    if isProcessingOCR {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("認識中…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let ocrError {
                        Label(ocrError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    sectionHeader("OCR で取り込み", systemImage: "doc.text.viewfinder")
                } footer: {
                    Text("画像 / PDF を **ドラッグ&ドロップ** または **「ファイルを選択」** から取り込み。行頭に **□ ☐ ⬜︎** などの四角がある行のみを抽出します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新規タスク")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
            .frame(minWidth: 540, minHeight: 640)
            .sheet(isPresented: Binding(
                get: { ocrRecognized != nil },
                set: { if !$0 { ocrRecognized = nil } }
            )) {
                if let recognized = ocrRecognized {
                    // 現在の AddTaskSheet で選んでいる生活領域を OCRReview にも引き継ぐ
                    OCRReviewSheet(recognized: recognized, initialLifeArea: lifeArea)
                        .onDisappear {
                            ocrRecognized = nil
                            dismiss()
                        }
                }
            }
        }
    }

    // MARK: - OCR Drop Area

    private var ocrDropArea: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .background(
                        isDropTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    Text("ここに画像 / PDF をドロップ")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("または下のボタンから選択")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .dropDestination(for: URL.self) { urls, _ in
                runOCR(on: urls)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }

            Button {
                openFilePicker()
            } label: {
                Label("ファイルを選択", systemImage: "doc.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    // MARK: - OCR action

    private func openFilePicker() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .pdf]
        panel.message = "OCR で取り込む画像または PDF を選択"
        if panel.runModal() == .OK {
            runOCR(on: panel.urls)
        }
        #endif
    }

    private func runOCR(on urls: [URL]) {
        guard !urls.isEmpty else { return }
        isProcessingOCR = true
        ocrError = nil
        Task {
            let cgImages = OCRService.loadCGImages(from: urls)
            guard !cgImages.isEmpty else {
                await MainActor.run {
                    isProcessingOCR = false
                    ocrError = "画像の読み込みに失敗しました。"
                }
                return
            }

            do {
                let recognized = try await ocrService.recognize(from: cgImages)
                await MainActor.run {
                    isProcessingOCR = false
                    if recognized.isEmpty {
                        ocrError = "文字を検出できませんでした。"
                    } else {
                        ocrRecognized = recognized
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingOCR = false
                    ocrError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Save (manual)

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)

        let task = TaskItem(
            title: trimmed,
            note: note.isEmpty ? nil : note,
            category: category,
            scheduledDate: scheduledDate.startOfDay,
            lifeArea: lifeArea,
            tag: trimmedTag.isEmpty ? nil : trimmedTag
        )
        modelContext.insert(task)
        dismiss()
    }

    private func dateOffset(_ days: Int) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: days, to: Date.now.startOfDay) ?? Date.now
    }

    // MARK: - Section header

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

#Preview {
    AddTaskSheet()
        .modelContainer(for: [TaskItem.self, PomodoroSession.self, TimelineEntry.self, MonthlyGoal.self, UserSettings.self], inMemory: true)
}
