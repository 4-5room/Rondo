//
//  AddTimelineEntrySheet.swift
//  PomoTaskerMac
//
//  手動でタイムラインにログを追加/編集するシート (Mac版)。
//

import SwiftUI
import SwiftData

struct AddTimelineEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let editingEntry: TimelineEntry?
    let referenceDate: Date

    @State private var title: String = ""
    @State private var category: TaskCategory = .normal
    @State private var lifeArea: LifeArea = .work
    @State private var startAt: Date
    @State private var endAt: Date
    @FocusState private var titleFocused: Bool

    init(editingEntry: TimelineEntry? = nil, referenceDate: Date = .now) {
        self.editingEntry = editingEntry
        self.referenceDate = referenceDate

        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: referenceDate)
        let baseDay = cal.date(from: components) ?? referenceDate

        if let e = editingEntry {
            _title = State(initialValue: e.title)
            _category = State(initialValue: e.category)
            _lifeArea = State(initialValue: e.lifeArea)
            _startAt = State(initialValue: e.startAt)
            _endAt = State(initialValue: e.endAt)
        } else {
            let end = min(Date.now, cal.date(byAdding: .day, value: 1, to: baseDay) ?? Date.now)
            let start = cal.date(byAdding: .minute, value: -30, to: end) ?? end
            _title = State(initialValue: "")
            _category = State(initialValue: .normal)
            _lifeArea = State(initialValue: .work)
            _startAt = State(initialValue: start)
            _endAt = State(initialValue: end)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    sectionHeader("内容", systemImage: "text.alignleft")
                }

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
                } header: {
                    sectionHeader("分類", systemImage: "tag.fill")
                }

                Section {
                    LabeledContent("開始") {
                        DatePicker("開始", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                    LabeledContent("終了") {
                        DatePicker("終了", selection: $endAt, in: startAt..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                } header: {
                    sectionHeader("時間帯", systemImage: "clock")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editingEntry == nil ? "ログを追加" : "ログを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || endAt <= startAt)
                }
            }
            .onAppear {
                if editingEntry == nil { titleFocused = true }
            }
            .frame(minWidth: 520, minHeight: 480)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, endAt > startAt else { return }

        if let editing = editingEntry {
            editing.title = trimmed
            editing.category = category
            editing.lifeArea = lifeArea
            editing.startAt = startAt
            editing.endAt = endAt
        } else {
            let entry = TimelineEntry(
                startAt: startAt,
                endAt: endAt,
                title: trimmed,
                category: category,
                source: .manual,
                lifeArea: lifeArea
            )
            modelContext.insert(entry)
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
