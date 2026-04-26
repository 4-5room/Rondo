//
//  UserSettings.swift
//  PomoTaskerMac
//
//  アプリ全体の設定。シングルトン(1レコード想定)。
//  iOS固有フィールド (dynamicIslandEnabled / landscapeAutoStartEnabled / calendarSync*) を削除し、
//  Mac固有の menuBarEnabled を追加。
//

import Foundation
import SwiftData
import SwiftUI

enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "システム"
        case .light:  return "ライト"
        case .dark:   return "ダーク"
        }
    }

    /// SwiftUI の preferredColorScheme に渡す値。system 時は nil(=パレット側に委譲)。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID = UUID()
    var defaultPomodoroMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var autoBreakEnabled: Bool = true
    var themeRaw: String = ThemePreference.system.rawValue

    /// カラーパレットID(ColorPalette.allPresets から選択)
    var paletteID: String = "pastel"

    /// メニューバー常駐(Mac固有)。OFFにするとメインウィンドウのみ。
    var menuBarEnabled: Bool = true

    init(
        id: UUID = UUID(),
        defaultPomodoroMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        autoBreakEnabled: Bool = true,
        theme: ThemePreference = .system,
        paletteID: String = "pastel",
        menuBarEnabled: Bool = true
    ) {
        self.id = id
        self.defaultPomodoroMinutes = defaultPomodoroMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.autoBreakEnabled = autoBreakEnabled
        self.themeRaw = theme.rawValue
        self.paletteID = paletteID
        self.menuBarEnabled = menuBarEnabled
    }

    var theme: ThemePreference {
        get { ThemePreference(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    var palette: ColorPalette {
        get { ColorPalette.preset(id: paletteID) }
        set { paletteID = newValue.id }
    }
}
