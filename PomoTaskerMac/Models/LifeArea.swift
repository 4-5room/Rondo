//
//  LifeArea.swift
//  PomoTaskerMac
//
//  iOS版から移植 (変更なし)。
//  TaskCategory(優先度軸)と直交する生活領域の分類。
//  週次/月次の「仕事 X 時間 / プライベート Y 時間」可視化に使用。
//

import SwiftUI

enum LifeArea: String, Codable, CaseIterable, Identifiable {
    case work      // 仕事
    case personal  // プライベート

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work:     return "仕事"
        case .personal: return "プライベート"
        }
    }

    var systemImage: String {
        switch self {
        case .work:     return "briefcase.fill"
        case .personal: return "house.fill"
        }
    }

    /// Stats カード等のアクセント色。環境パレット未適用の時のフォールバック。
    var tintColor: Color {
        switch self {
        case .work:     return .blue
        case .personal: return .orange
        }
    }
}
