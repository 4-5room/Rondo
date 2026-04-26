//
//  ColorPalette.swift
//  PomoTaskerMac
//
//  SNS風のカラーテーマ集 + 独自テーマ「4.5room」。
//  iOS版から移植。paletteAdaptive を AppKit (NSColor) 対応に追加。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// パレット固有の背景装飾スタイル。SNSモチーフを視覚的に差別化する。
enum PaletteStyle: String, Hashable {
    case plain          // 装飾なし(パステル/プロフェッショナル等)
    case room45Aurora   // 4.5room: ティール×ゴールドのオーロラグラデ
    case blueBird       // X風: 上部にブルー水平グラデ + 控えめドット
    case gradientSNS    // Instagram風: 紫→ピンク→オレンジの斜めグラデ
    case streaming      // YouTube風: 中央に赤いプレイ三角型ハロー
    case shortVideo     // TikTok風: 鮮やかなマゼンタ×シアン2点グロー
    case music          // Spotify風: 緑の同心円リング
}

struct ColorPalette: Equatable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let subtitle: String

    // 分類別カラー
    let urgent: Color
    let important: Color
    let special: Color
    let normal: Color

    // アクセント色
    let accent: Color

    // 背景
    let bgLight: Color
    let bgDark: Color
    /// このパレット固有のカラースキーム。nilならユーザー設定に従う。
    let prefersScheme: ColorScheme?
    /// 背景装飾スタイル(SNSテーマ差別化用)
    let style: PaletteStyle

    // MARK: - API

    func color(for category: TaskCategory) -> Color {
        switch category {
        case .urgent:    return urgent
        case .important: return important
        case .special:   return special
        case .normal:    return normal
        }
    }

    /// システムのカラースキームを考慮した背景色。
    var adaptiveBackground: Color {
        if let forced = prefersScheme {
            return forced == .dark ? bgDark : bgLight
        }
        return .paletteAdaptive(light: bgLight, dark: bgDark)
    }

    // MARK: - Presets

    static let allPresets: [ColorPalette] = [
        .pastel,        // default
        .room45,        // ★ 独自
        .blueBird,
        .gradientSNS,
        .streaming,
        .shortVideo,
        .music,
        .professional
    ]

    static func preset(id: String) -> ColorPalette {
        allPresets.first { $0.id == id } ?? .pastel
    }

    // MARK: - Definitions

    /// パステル(デフォルト)
    static let pastel = ColorPalette(
        id: "pastel",
        displayName: "パステル",
        subtitle: "シンプル・淡色",
        urgent:    Color(red: 0.82, green: 0.42, blue: 0.44),
        important: Color(red: 0.38, green: 0.58, blue: 0.88),
        special:   Color(red: 0.36, green: 0.68, blue: 0.52),
        normal:    Color(red: 0.30, green: 0.33, blue: 0.37),
        accent:    Color(red: 0.38, green: 0.58, blue: 0.88),
        bgLight:   Color(red: 0.99, green: 0.98, blue: 0.95),
        bgDark:    Color(red: 0.10, green: 0.10, blue: 0.11),
        prefersScheme: nil,
        style:     .plain
    )

    /// 4.5room(黒ベース + アクアブルー + ゴールド)
    static let room45 = ColorPalette(
        id: "room45",
        displayName: "4.5room",
        subtitle: "黒 × アクアブルー × ゴールド",
        urgent:    Color(red: 0.95, green: 0.45, blue: 0.45),
        important: Color(red: 0.04, green: 0.73, blue: 0.71),   // tiffany blue
        special:   Color(red: 0.83, green: 0.69, blue: 0.22),   // gold
        normal:    Color(red: 0.72, green: 0.74, blue: 0.76),
        accent:    Color(red: 0.04, green: 0.73, blue: 0.71),
        bgLight:   .black,
        bgDark:    .black,
        prefersScheme: .dark,
        style:     .room45Aurora
    )

    /// ブルーバード(つぶやき系)
    static let blueBird = ColorPalette(
        id: "bluebird",
        displayName: "ブルーバード",
        subtitle: "つぶやき SNS 風",
        urgent:    Color(red: 0.88, green: 0.14, blue: 0.37),
        important: Color(red: 0.11, green: 0.63, blue: 0.95),
        special:   Color(red: 0.09, green: 0.75, blue: 0.39),
        normal:    Color(red: 0.40, green: 0.47, blue: 0.53),
        accent:    Color(red: 0.11, green: 0.63, blue: 0.95),
        bgLight:   Color(red: 1.00, green: 1.00, blue: 1.00),
        bgDark:    Color(red: 0.08, green: 0.13, blue: 0.17),
        prefersScheme: nil,
        style:     .blueBird
    )

    /// グラデーションSNS(Instagram風)
    static let gradientSNS = ColorPalette(
        id: "gradient_sns",
        displayName: "グラデーション",
        subtitle: "写真SNS 風",
        urgent:    Color(red: 0.88, green: 0.19, blue: 0.42),
        important: Color(red: 0.51, green: 0.30, blue: 0.71),
        special:   Color(red: 0.99, green: 0.54, blue: 0.16),
        normal:    Color(red: 0.52, green: 0.45, blue: 0.62),
        accent:    Color(red: 0.88, green: 0.19, blue: 0.42),
        bgLight:   Color(red: 0.99, green: 0.98, blue: 0.99),
        bgDark:    Color(red: 0.05, green: 0.05, blue: 0.08),
        prefersScheme: nil,
        style:     .gradientSNS
    )

    /// ストリーミング(YouTube風)
    static let streaming = ColorPalette(
        id: "streaming",
        displayName: "ストリーミング",
        subtitle: "動画配信 風",
        urgent:    Color(red: 0.92, green: 0.05, blue: 0.05),
        important: Color(red: 0.28, green: 0.28, blue: 0.28),
        special:   Color(red: 1.00, green: 0.43, blue: 0.20),
        normal:    Color(red: 0.50, green: 0.50, blue: 0.50),
        accent:    Color(red: 0.92, green: 0.05, blue: 0.05),
        bgLight:   Color(red: 0.98, green: 0.98, blue: 0.98),
        bgDark:    Color(red: 0.06, green: 0.06, blue: 0.06),
        prefersScheme: nil,
        style:     .streaming
    )

    /// ショート動画(TikTok風、強制ダーク)
    static let shortVideo = ColorPalette(
        id: "short_video",
        displayName: "ショート動画",
        subtitle: "縦動画SNS 風(ダーク固定)",
        urgent:    Color(red: 0.99, green: 0.17, blue: 0.33),
        important: Color(red: 0.14, green: 0.96, blue: 0.93),
        special:   Color(red: 0.85, green: 0.85, blue: 0.87),
        normal:    Color(red: 0.55, green: 0.55, blue: 0.58),
        accent:    Color(red: 0.99, green: 0.17, blue: 0.33),
        bgLight:   Color(red: 0.03, green: 0.03, blue: 0.04),
        bgDark:    Color(red: 0.03, green: 0.03, blue: 0.04),
        prefersScheme: .dark,
        style:     .shortVideo
    )

    /// ミュージック(Spotify風、強制ダーク)
    static let music = ColorPalette(
        id: "music",
        displayName: "ミュージック",
        subtitle: "音楽配信 風(ダーク固定)",
        urgent:    Color(red: 0.12, green: 0.73, blue: 0.33),
        important: Color(red: 0.85, green: 0.85, blue: 0.85),
        special:   Color(red: 0.11, green: 0.84, blue: 0.38),
        normal:    Color(red: 0.55, green: 0.55, blue: 0.55),
        accent:    Color(red: 0.12, green: 0.73, blue: 0.33),
        bgLight:   Color(red: 0.07, green: 0.07, blue: 0.07),
        bgDark:    Color(red: 0.07, green: 0.07, blue: 0.07),
        prefersScheme: .dark,
        style:     .music
    )

    /// プロフェッショナル(LinkedIn風)
    static let professional = ColorPalette(
        id: "professional",
        displayName: "プロフェッショナル",
        subtitle: "ビジネスSNS 風",
        urgent:    Color(red: 0.78, green: 0.25, blue: 0.18),
        important: Color(red: 0.00, green: 0.47, blue: 0.71),
        special:   Color(red: 0.05, green: 0.58, blue: 0.53),
        normal:    Color(red: 0.42, green: 0.48, blue: 0.54),
        accent:    Color(red: 0.00, green: 0.47, blue: 0.71),
        bgLight:   Color(red: 0.96, green: 0.97, blue: 0.98),
        bgDark:    Color(red: 0.11, green: 0.13, blue: 0.15),
        prefersScheme: nil,
        style:     .plain
    )
}

// MARK: - Color adaptive helper

extension Color {
    /// ライト/ダークで自動切替するColor。iOS/macOS両対応。
    static func paletteAdaptive(light: Color, dark: Color) -> Color {
        #if canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #elseif canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return light
        #endif
    }
}

// MARK: - Environment

private struct ColorPaletteKey: EnvironmentKey {
    static let defaultValue: ColorPalette = .pastel
}

extension EnvironmentValues {
    var colorPalette: ColorPalette {
        get { self[ColorPaletteKey.self] }
        set { self[ColorPaletteKey.self] = newValue }
    }
}
