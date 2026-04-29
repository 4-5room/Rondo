//
//  ThemedBackground.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし、SwiftUI のみで動作)。
//  各画面の最上位にパレット背景色 + パレット固有装飾を敷く ViewModifier。
//  PaletteStyle に応じた装飾レイヤー (4.5room オーロラ、ブルーバードドット等) を切替。
//

import SwiftUI

struct PaletteBackgroundModifier: ViewModifier {
    @Environment(\.colorPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    palette.adaptiveBackground
                    PaletteDecorationLayer(style: palette.style, palette: palette)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// 各画面の最上位に適用して、パレット背景を敷く。
    func paletteBackground() -> some View {
        modifier(PaletteBackgroundModifier())
    }
}

// MARK: - Decoration Layer

/// PaletteStyle に応じた装飾レイヤー。コンテンツ視認性を妨げないよう
/// 透明度は控えめ (0.10〜0.45 程度) に抑えている。
private struct PaletteDecorationLayer: View {
    let style: PaletteStyle
    let palette: ColorPalette

    var body: some View {
        GeometryReader { geo in
            switch style {
            case .plain:
                Color.clear

            case .room45Aurora:
                // ティール × ゴールドのオーロラ風放射グラデ
                ZStack {
                    RadialGradient(
                        colors: [palette.important.opacity(0.35), .clear],
                        center: UnitPoint(x: 0.15, y: 0.10),
                        startRadius: 10,
                        endRadius: max(geo.size.width, geo.size.height) * 0.7
                    )
                    RadialGradient(
                        colors: [palette.special.opacity(0.22), .clear],
                        center: UnitPoint(x: 0.85, y: 0.95),
                        startRadius: 10,
                        endRadius: max(geo.size.width, geo.size.height) * 0.6
                    )
                }

            case .blueBird:
                ZStack {
                    LinearGradient(
                        colors: [palette.accent.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    BlueBirdDotPattern()
                        .foregroundStyle(palette.accent.opacity(0.06))
                }

            case .gradientSNS:
                LinearGradient(
                    colors: [
                        palette.important.opacity(0.30),
                        palette.urgent.opacity(0.28),
                        palette.special.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

            case .streaming:
                ZStack {
                    RadialGradient(
                        colors: [palette.urgent.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: max(geo.size.width, geo.size.height) * 0.55
                    )
                    PlayTriangle()
                        .fill(palette.urgent.opacity(0.10))
                        .frame(
                            width: min(geo.size.width, geo.size.height) * 0.45,
                            height: min(geo.size.width, geo.size.height) * 0.45
                        )
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

            case .shortVideo:
                ZStack {
                    RadialGradient(
                        colors: [palette.urgent.opacity(0.45), .clear],
                        center: UnitPoint(x: 0.20, y: 0.20),
                        startRadius: 5,
                        endRadius: geo.size.width * 0.55
                    )
                    RadialGradient(
                        colors: [palette.important.opacity(0.40), .clear],
                        center: UnitPoint(x: 0.85, y: 0.80),
                        startRadius: 5,
                        endRadius: geo.size.width * 0.55
                    )
                }
                .blendMode(.screen)

            case .music:
                ZStack {
                    ConcentricRings(count: 5, color: palette.accent.opacity(0.18))
                        .frame(width: geo.size.width * 1.6, height: geo.size.width * 1.6)
                        .position(x: geo.size.width * 0.85, y: geo.size.height * 1.05)
                    RadialGradient(
                        colors: [palette.accent.opacity(0.18), .clear],
                        center: UnitPoint(x: 0.85, y: 1.0),
                        startRadius: 20,
                        endRadius: geo.size.width * 0.8
                    )
                }
            }
        }
    }
}

// MARK: - Shapes

/// 横方向に並んだ細かいドットパターン (X風 控えめテクスチャ)
private struct BlueBirdDotPattern: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 28
            let radius: CGFloat = 1.2
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = (y.truncatingRemainder(dividingBy: spacing * 2) == 0) ? 0 : spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.primary))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

/// プレイボタン三角形
private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 中心から放射する同心円リング
private struct ConcentricRings: View {
    let count: Int
    let color: Color
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(CGFloat(i + 1) / CGFloat(count))
            }
        }
    }
}
