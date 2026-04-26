//
//  AddGoalSheet.swift
//  PomoTaskerMac
//
//  月次目標の新規作成シート (Mac版)。
//

import SwiftUI
import SwiftData

struct AddGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let targetMonth: Date

    @State private var title: String = ""
    @State private var detail: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("目標タイトル", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .textFieldStyle(.roundedBorder)

                    TextField("詳細・メモ (任意)", text: $detail, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    sectionHeader(targetMonth.yearMonthString() + " の目標", systemImage: "target")
                } footer: {
                    Text("月単位の目標を立てて、必要に応じて日次のタスクへ流し込めます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新規目標")
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
            .frame(minWidth: 480, minHeight: 380)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let goal = MonthlyGoal(
            title: trimmed,
            detail: detail.isEmpty ? nil : detail,
            targetMonth: targetMonth.startOfMonth
        )
        modelContext.insert(goal)
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
