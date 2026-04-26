//
//  RondoLogo.swift
//  PomoTaskerMac
//
//  iOS版アイコンを SwiftUI で再現したベクター描画ロゴ。
//  ラスター画像と違い任意サイズで鮮明に表示される。
//  - 黒い円ループ (タイマーリング)
//  - アクアブルーの小さなドット (右上、タイマーの針位置)
//

import SwiftUI

struct RondoLogo: View {
    /// ロゴ全体のサイズ。
    var size: CGFloat = 64
    /// 角丸背景を表示するか (Settings のAbout など、Macアイコン風に見せたい時用)。
    var withRoundedBackground: Bool = false

    private var ringColor: Color {
        Color(red: 0.18, green: 0.20, blue: 0.22)
    }
    private var dotColor: Color {
        Color(red: 0.04, green: 0.73, blue: 0.71)  // Tiffany blue (4.5room palette)
    }
    private var bgColor: Color {
        Color.white
    }

    var body: some View {
        ZStack {
            if withRoundedBackground {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
            }

            // 黒い円リング
            let lineWidth = size * 0.07
            let inset = size * 0.18
            Circle()
                .stroke(ringColor, lineWidth: lineWidth)
                .padding(inset)

            // 右上のアクアブルードット (タイマーの針位置イメージ)
            let dotSize = size * 0.18
            // 円の中心: (size/2, size/2)
            // リングの半径: size/2 - inset - lineWidth/2
            // ドットの位置: 中心から右上 45° の所
            let radius = size / 2 - inset - lineWidth / 2
            let angle = -CGFloat.pi / 4  // -45° (時計の3時の少し上)
            let dotX = size / 2 + radius * cos(angle)
            let dotY = size / 2 + radius * sin(angle)

            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .position(x: dotX, y: dotY)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 24) {
        RondoLogo(size: 22)
        RondoLogo(size: 32)
        RondoLogo(size: 64)
        RondoLogo(size: 64, withRoundedBackground: true)
        RondoLogo(size: 128, withRoundedBackground: true)
    }
    .padding()
    .background(Color(white: 0.95))
}
