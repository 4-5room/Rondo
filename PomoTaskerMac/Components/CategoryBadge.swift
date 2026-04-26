//
//  CategoryBadge.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。タスク分類を示すバッジ部品。パレット連動。
//

import SwiftUI

struct CategoryBadge: View {
    @Environment(\.colorPalette) private var palette

    let category: TaskCategory
    var style: Style = .chip

    enum Style {
        case chip    // 色付き塗り + ラベル
        case icon    // SF Symbolのみ
    }

    private var color: Color { palette.color(for: category) }

    var body: some View {
        switch style {
        case .chip:
            HStack(spacing: 4) {
                Image(systemName: category.symbolName)
                    .font(.caption2)
                Text(category.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)

        case .icon:
            Image(systemName: category.symbolName)
                .foregroundStyle(color)
                .font(.callout)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(TaskCategory.allCases) { cat in
            HStack {
                CategoryBadge(category: cat, style: .chip)
                CategoryBadge(category: cat, style: .icon)
            }
        }
    }
    .padding()
}
