//
//  PaletteCard.swift
//  PomoTaskerMac
//
//  カラーパレットを **カード形式** で表示するコンポーネント。
//  Settings の「デザイン」セクションでグリッド配置して使う。
//  - 4分類色のプレビューバー (緊急/重要/特殊/通常)
//  - 背景色 (Light/Dark) のミニサンプル
//  - 名前 + サブタイトル
//  - 選択時はアクセント色のボーダー + シャドウ + ✓
//

import SwiftUI

struct PaletteCard: View {
    let palette: ColorPalette
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            colorPreview

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(palette.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.accent)
                            .font(.caption)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(palette.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? palette.accent : Color.gray.opacity(0.18),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? palette.accent.opacity(0.25) : .black.opacity(0.04),
            radius: isSelected ? 6 : 2,
            y: isSelected ? 2 : 1
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    /// 上段: 4分類色のグラデバー / 下段: 背景 Light/Dark プレビュー
    private var colorPreview: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach([palette.urgent, palette.important, palette.special, palette.normal], id: \.self) { c in
                    Rectangle()
                        .fill(c)
                        .frame(height: 32)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            HStack(spacing: 0) {
                Rectangle()
                    .fill(palette.bgLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 14)
                Rectangle()
                    .fill(palette.bgDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
        ForEach(ColorPalette.allPresets) { palette in
            PaletteCard(palette: palette, isSelected: palette.id == "room45")
        }
    }
    .padding()
    .frame(width: 600)
}
