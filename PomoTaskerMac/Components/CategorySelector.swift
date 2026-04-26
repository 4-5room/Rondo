//
//  CategorySelector.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  分類を選ぶカラー付きチップ選択UI。色ルール:
//  緊急=赤 / 重要=青 / 特殊=緑 / 通常=グレー。
//  常に優先度順(緊急→重要→特殊→通常)で表示。
//

import SwiftUI

struct CategorySelector: View {
    @Binding var selection: TaskCategory
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(TaskCategory.allCasesByPriority) { cat in
                chip(cat)
            }
        }
    }

    private func chip(_ cat: TaskCategory) -> some View {
        let isSelected = selection == cat
        return Button {
            selection = cat
        } label: {
            HStack(spacing: 4) {
                Image(systemName: cat.symbolName)
                Text(cat.label)
            }
            .font(compact ? .caption2 : .caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(cat.color)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 5 : 7)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? cat.color.opacity(0.18) : Color.clear,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? cat.color : Color.secondary.opacity(0.25),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct Demo: View {
        @State var cat: TaskCategory = .important
        var body: some View {
            VStack(spacing: 16) {
                CategorySelector(selection: $cat)
                CategorySelector(selection: $cat, compact: true)
                Text("選択中: \(cat.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    return Demo()
}
