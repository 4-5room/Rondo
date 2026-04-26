//
//  TaskCategory.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。タスクの分類。
//

import SwiftUI

/// タスクの分類。重要 / 緊急 / 特殊 / 通常 の4種。
enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case important   // 重要
    case urgent      // 緊急
    case special     // 特殊
    case normal      // 通常

    var id: String { rawValue }

    /// 画面表示用の日本語ラベル
    var label: String {
        switch self {
        case .important: return "重要"
        case .urgent:    return "緊急"
        case .special:   return "特殊"
        case .normal:    return "通常"
        }
    }

    /// 分類カラー(フォールバック。環境パレット未適用View向け)。
    /// パレット切替をサポートしている View では
    /// `@Environment(\.colorPalette).color(for: category)` を優先使用してください。
    var color: Color {
        ColorPalette.pastel.color(for: self)
    }

    /// SF Symbols アイコン名
    var symbolName: String {
        switch self {
        case .important: return "exclamationmark.circle.fill"
        case .urgent:    return "flame.fill"
        case .special:   return "star.fill"
        case .normal:    return "circle"
        }
    }

    /// 優先度(小さいほど高優先)。緊急 > 重要 > 特殊 > 通常。
    var priority: Int {
        switch self {
        case .urgent:    return 0
        case .important: return 1
        case .special:   return 2
        case .normal:    return 3
        }
    }

    /// 優先度順(緊急→重要→特殊→通常)
    static var allCasesByPriority: [TaskCategory] {
        allCases.sorted { $0.priority < $1.priority }
    }
}
