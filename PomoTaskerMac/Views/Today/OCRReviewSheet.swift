//
//  OCRReviewSheet.swift
//  PomoTaskerMac
//
//  Mac native UI: コンパクトな 1行レイアウト + Inspector 風メタ情報。
//  - Form を捨てて自前構造 (上部ヘッダ + 中央リスト + 下部 toolbar)
//  - 行はチェック + TextField + カテゴリ▼ + 🏷 を1行に
//  - グループバッジは行下の補助行 (ホバー時 × 表示)
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
    @Query private var corrections: [OCRCorrection]

    @State var candidates: [CandidateRow]
    @State private var defaultCategory: TaskCategory = .normal
    @State private var lifeArea: LifeArea
    @State private var showRawCandidates: Bool = false
    @State private var didApplyDictionary: Bool = false
    @State private var isApplyingAI: Bool = false
    @State private var didApplyAI: Bool = false
    /// タグ自動正規化を 1 度だけ走らせるガード
    @State private var didApplyTagNormalization: Bool = false
    /// タグ名編集 alert の対象行 ID と入力値
    @State private var editingTagRowID: UUID? = nil
    @State private var editingTagText: String = ""

    struct CandidateRow: Identifiable {
        let id = UUID()
        var text: String
        var originalText: String
        var category: TaskCategory?
        var groupName: String?
        var isSelected: Bool
        var isHeader: Bool = false
        var rawCandidates: [String] = []
        var wasAutoCorrected: Bool = false
    }

    private var existingTags: [String] {
        var counter: [String: Int] = [:]
        for t in allTasks {
            guard let tag = t.tag?.trimmingCharacters(in: .whitespaces), !tag.isEmpty else { continue }
            counter[tag, default: 0] += 1
        }
        return counter.sorted { $0.value > $1.value }.map { $0.key }
    }

    init(lines: [String], initialLifeArea: LifeArea = .work) {
        _candidates = State(initialValue: lines.map {
            CandidateRow(
                text: $0, originalText: $0,
                category: nil, groupName: nil, isSelected: !$0.isEmpty
            )
        })
        _lifeArea = State(initialValue: initialLifeArea)
    }

    init(recognized: [OCRService.RecognizedLine], initialLifeArea: LifeArea = .work) {
        _candidates = State(initialValue: recognized.map {
            CandidateRow(
                text: $0.text, originalText: $0.text,
                category: $0.category, groupName: $0.groupName,
                isSelected: !$0.text.isEmpty,
                rawCandidates: $0.rawCandidates
            )
        })
        _lifeArea = State(initialValue: initialLifeArea)
    }

    private var selectedCount: Int {
        candidates.filter {
            $0.isSelected && !$0.isHeader
            && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    /// 現在 candidates に付与されているグループタグ一覧 (使用件数付き、出現頻度順)。
    /// OCR 自動検出タグの誤認識を一括クリアするため上部パネルに表示する。
    private var detectedTags: [(name: String, count: Int)] {
        var counter: [String: Int] = [:]
        for c in candidates {
            guard let g = c.groupName?.trimmingCharacters(in: .whitespaces),
                  !g.isEmpty else { continue }
            counter[g, default: 0] += 1
        }
        return counter
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .map { (name: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topPanel
                Divider()
                rowList
            }
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
                ToolbarItem(placement: .principal) {
                    if isApplyingAI {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("AI 補正中…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(minWidth: 580, minHeight: 600)
            .onAppear {
                applyDictionaryCorrectionIfNeeded()
                applyTagNormalizationIfNeeded()
                applyAICorrectionIfAvailable()
            }
            .alert("タグ名を編集", isPresented: Binding(
                get: { editingTagRowID != nil },
                set: { if !$0 { editingTagRowID = nil } }
            )) {
                TextField("タグ名", text: $editingTagText)
                Button("キャンセル", role: .cancel) {
                    editingTagRowID = nil
                }
                Button("OK") {
                    commitTagEdit()
                }
            } message: {
                Text("既存タグから選ぶか、新しい名前を入力してください。")
            }
        }
    }

    // MARK: - Top panel (compact settings)

    private var topPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 行 1: デフォルト分類
            HStack(alignment: .center, spacing: 12) {
                Text("分類")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
                CategorySelector(selection: $defaultCategory)
                    .frame(maxWidth: 320)
                Spacer()
            }

            // 行 2: 生活領域
            HStack(alignment: .center, spacing: 12) {
                Text("生活領域")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
                Picker("生活領域", selection: $lifeArea) {
                    ForEach(LifeArea.allCases) { area in
                        Label(area.label, systemImage: area.systemImage).tag(area)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                Spacer()
            }

            // 行 3: 検出タグ一覧 (誤認識の一括クリア用、タグが1つでもあれば表示)
            if !detectedTags.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    Text("検出タグ")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(detectedTags, id: \.name) { entry in
                                Button {
                                    removeTag(entry.name)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "tag.fill")
                                            .font(.caption2)
                                        Text("\(entry.name)")
                                            .font(.caption2)
                                        Text("(\(entry.count))")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(Color.accentColor.opacity(0.7))
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .semibold))
                                            .padding(.leading, 2)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("「\(entry.name)」を全行 (\(entry.count) 件) から外す")
                            }
                        }
                    }
                    Button {
                        clearAllTags()
                    } label: {
                        Text("全クリア")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("全行のグループタグを一括で外す")
                }
            }

            // 行 4: 表示オプション
            HStack(spacing: 12) {
                Toggle(isOn: $showRawCandidates) {
                    Label("生認識結果を表示", systemImage: "text.magnifyingglass")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                Spacer()
                Text("\(selectedCount) 件選択中")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    /// 指定タグを使う全行 (タスク行) から groupName を外す。
    /// 対応する isHeader 行も外して矛盾を防ぐ (元のヘッダー行は残るがタグとして再付与されない)。
    private func removeTag(_ tagName: String) {
        for i in candidates.indices where candidates[i].groupName == tagName {
            candidates[i].groupName = nil
        }
        // 同名のヘッダー行があれば、recompute で再付与されないよう isHeader=false に戻す
        for i in candidates.indices where candidates[i].isHeader
            && sanitizeHeaderText(candidates[i].text) == tagName {
            candidates[i].isHeader = false
        }
    }

    /// 全行の groupName を一括で外す。
    private func clearAllTags() {
        for i in candidates.indices {
            candidates[i].groupName = nil
            // 全 isHeader 行もタスクに戻す (誤検出から完全リセット)
            if candidates[i].isHeader {
                candidates[i].isHeader = false
            }
        }
    }

    // MARK: - Row list

    private var rowList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach($candidates) { $row in
                    candidateRowView(row: $row)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Row (compact, 1-line layout)

    @ViewBuilder
    private func candidateRowView(row: Binding<CandidateRow>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                // 選択チェック
                Button {
                    row.wrappedValue.isSelected.toggle()
                } label: {
                    Image(systemName: leftIconName(for: row.wrappedValue))
                        .foregroundStyle(leftIconColor(for: row.wrappedValue))
                        .font(.title3)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                // タイトル: single-line + prompt 形式 (ラベル左寄せ問題回避)
                TextField(
                    "",
                    text: row.text,
                    prompt: Text(row.wrappedValue.isHeader ? "タグ名" : "タスクを入力")
                )
                .textFieldStyle(.plain)
                .font(row.wrappedValue.isHeader ? .body.weight(.semibold) : .body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!row.wrappedValue.isSelected)
                .onChange(of: row.wrappedValue.text) { _, _ in
                    if row.wrappedValue.isHeader { recomputeGroupNames() }
                }

                // 右側のメタコントロール (タスク行のみ)
                if !row.wrappedValue.isHeader {
                    compactCategoryMenu(row: row)
                }

                // 🏷 トグル
                Button {
                    row.wrappedValue.isHeader.toggle()
                    recomputeGroupNames()
                } label: {
                    Image(systemName: row.wrappedValue.isHeader ? "tag.fill" : "tag")
                        .foregroundStyle(row.wrappedValue.isHeader ? Color.accentColor : Color.secondary)
                        .font(.callout)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(row.wrappedValue.isHeader ? "タスクに戻す" : "タグ (ヘッダー) に変更")
            }

            // 補助行: グループバッジ + 生認識結果
            if !row.wrappedValue.isHeader,
               let group = row.wrappedValue.groupName, !group.isEmpty {
                HStack(spacing: 6) {
                    groupChip(group: group, row: row)
                    Spacer()
                }
                .padding(.leading, 32)
            }

            if showRawCandidates, !row.wrappedValue.rawCandidates.isEmpty {
                rawCandidatesView(row.wrappedValue.rawCandidates)
                    .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground(for: row.wrappedValue))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    row.wrappedValue.isHeader ? Color.accentColor.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func rowBackground(for row: CandidateRow) -> Color {
        if row.isHeader {
            return Color.accentColor.opacity(0.10)
        }
        return Color.gray.opacity(0.06)
    }

    // MARK: - Compact controls

    /// コンパクトなカテゴリメニュー (アイコンのみ表示、Menu で選択)
    @ViewBuilder
    private func compactCategoryMenu(row: Binding<CandidateRow>) -> some View {
        Menu {
            Button {
                row.wrappedValue.category = nil
            } label: {
                Label("デフォルトを使用", systemImage: row.wrappedValue.category == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(TaskCategory.allCasesByPriority) { cat in
                Button {
                    row.wrappedValue.category = cat
                } label: {
                    Label(cat.label, systemImage: cat.symbolName)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let c = row.wrappedValue.category {
                    Image(systemName: c.symbolName)
                        .foregroundStyle(c.color)
                    Text(c.label)
                        .foregroundStyle(c.color)
                        .font(.caption)
                } else {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 22)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(!row.wrappedValue.isSelected)
        .help("分類を選択")
    }

    /// グループ (タグ) のチップ。Menu で「既存から選ぶ / 編集 / 削除」。
    /// 既存タグに完全一致しない場合はオレンジ警告色で表示。
    @ViewBuilder
    private func groupChip(group: String, row: Binding<CandidateRow>) -> some View {
        let registered = existingTags
        let isKnown = registered.contains(group)
        let chipColor: Color = isKnown ? .accentColor : .orange
        let chipIcon = isKnown ? "tag.fill" : "exclamationmark.triangle.fill"

        Menu {
            if !registered.isEmpty {
                Section("既存タグから選ぶ") {
                    ForEach(registered.prefix(8), id: \.self) { tag in
                        Button {
                            row.wrappedValue.groupName = tag
                        } label: {
                            if tag == group {
                                Label(tag, systemImage: "checkmark")
                            } else {
                                Text(tag)
                            }
                        }
                    }
                }
                Divider()
            }
            Button {
                editingTagRowID = row.wrappedValue.id
                editingTagText = group
            } label: {
                Label("タグ名を編集…", systemImage: "pencil")
            }
            Button(role: .destructive) {
                row.wrappedValue.groupName = nil
            } label: {
                Label("タグを削除", systemImage: "trash")
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: chipIcon)
                    .font(.caption2)
                Text(group)
                    .font(.caption2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(chipColor.opacity(0.7))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(chipColor.opacity(0.14), in: Capsule())
            .foregroundStyle(chipColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(!row.wrappedValue.isSelected)
        .help(isKnown ? "登録済みタグ「\(group)」" : "⚠ 新規タグ「\(group)」(既存タグに一致しません)")
    }

    @ViewBuilder
    private func rawCandidatesView(_ rawCandidates: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(rawCandidates.enumerated()), id: \.offset) { idx, cand in
                Text("[\(idx + 1)] \(cand)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Row appearance helpers

    private func leftIconName(for row: CandidateRow) -> String {
        if row.isHeader {
            return row.isSelected ? "tag.circle.fill" : "tag.circle"
        }
        return row.isSelected ? "checkmark.circle.fill" : "circle"
    }

    private func leftIconColor(for row: CandidateRow) -> Color {
        if !row.isSelected { return .secondary }
        return row.isHeader ? Color.accentColor : .blue
    }

    // MARK: - Group recomputation

    private func recomputeGroupNames() {
        var currentTag: String? = nil
        for i in candidates.indices {
            if candidates[i].isHeader {
                let cleaned = sanitizeHeaderText(candidates[i].text)
                currentTag = cleaned.isEmpty ? nil : cleaned
                candidates[i].groupName = nil
            } else {
                candidates[i].groupName = currentTag
            }
        }
    }

    private func sanitizeHeaderText(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripChars: Set<Character> = [
            ":", "\u{FF1A}",
            "\u{30FB}", "\u{00B7}", "\u{2022}"
        ]
        while let last = t.last, stripChars.contains(last) {
            t.removeLast()
            t = t.trimmingCharacters(in: .whitespaces)
        }
        while let first = t.first, stripChars.contains(first) {
            t.removeFirst()
            t = t.trimmingCharacters(in: .whitespaces)
        }
        return t
    }

    // MARK: - Auto-correction

    /// OCR で検出された groupName を、既存タグ群と TagMatcher で照合して
    /// 近いものに自動置換する (例: "Yotube" → 既存に "YouTube" があれば "YouTube" に)。
    /// 完全一致や normalize 一致 → そのまま。Levenshtein 距離が許容内 → 既存タグに寄せる。
    /// 1 回限り (didApplyTagNormalization で多重実行防止)。
    private func applyTagNormalizationIfNeeded() {
        guard !didApplyTagNormalization else { return }
        didApplyTagNormalization = true
        let registered = existingTags
        guard !registered.isEmpty else { return }
        for i in candidates.indices {
            guard let g = candidates[i].groupName?.trimmingCharacters(in: .whitespaces),
                  !g.isEmpty else { continue }
            if let normalized = TagMatcher.bestMatch(for: g, in: registered),
               normalized != g {
                candidates[i].groupName = normalized
            }
        }
    }

    /// タグ名編集 alert の OK ボタンで呼ばれる。
    /// editingTagText の値で対象行の groupName を更新 (空なら nil)。
    private func commitTagEdit() {
        guard let id = editingTagRowID,
              let i = candidates.firstIndex(where: { $0.id == id }) else {
            editingTagRowID = nil
            return
        }
        let trimmed = editingTagText.trimmingCharacters(in: .whitespaces)
        candidates[i].groupName = trimmed.isEmpty ? nil : trimmed
        editingTagRowID = nil
    }

    private func applyDictionaryCorrectionIfNeeded() {
        guard !didApplyDictionary else { return }
        didApplyDictionary = true
        let knownTitles = OCRDictionary.knownTitles(from: allTasks)
        for i in candidates.indices {
            let raw = candidates[i].text
            let corrected = OCRDictionary.correct(raw, corrections: corrections, knownTitles: knownTitles)
            if corrected != raw {
                candidates[i].text = corrected
                candidates[i].wasAutoCorrected = true
            }
        }
    }

    private func applyAICorrectionIfAvailable() {
        guard !didApplyAI, IntelligentOCRCorrector.isAvailable else { return }
        didApplyAI = true
        let inputs = candidates.map { $0.text }
        let knownTitles = OCRDictionary.knownTitles(from: allTasks)

        isApplyingAI = true
        Task { @MainActor in
            let corrected = await IntelligentOCRCorrector.correct(
                rawTexts: inputs,
                knownTitles: knownTitles
            )
            isApplyingAI = false
            guard corrected.count == candidates.count else { return }
            for i in candidates.indices where corrected[i] != candidates[i].text {
                candidates[i].text = corrected[i]
                candidates[i].wasAutoCorrected = true
            }
        }
    }

    // MARK: - Save

    private func save() {
        let now = Date.now
        var order = 0
        let registeredTags = existingTags
        for row in candidates {
            let trimmed = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard row.isSelected, !row.isHeader, !trimmed.isEmpty else { continue }

            let tagValue: String? = {
                guard let g = row.groupName?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return nil }
                return TagMatcher.bestMatch(for: g, in: registeredTags) ?? g
            }()
            let task = TaskItem(
                title: trimmed,
                category: row.category ?? defaultCategory,
                createdAt: now.addingTimeInterval(Double(order) * 0.001),
                sortOrder: order,
                lifeArea: lifeArea,
                tag: tagValue
            )
            modelContext.insert(task)
            order += 1

            // タグ行は学習対象外 (タグ名が辞書に登録されないように isHeader 行は↑でスキップ済み)
            OCRDictionary.upsertCorrection(
                rawText: row.originalText,
                correctedText: trimmed,
                in: corrections,
                insert: { modelContext.insert($0) }
            )
        }
        dismiss()
    }
}
