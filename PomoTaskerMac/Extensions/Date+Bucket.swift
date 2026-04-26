//
//  Date+Bucket.swift
//  PomoTaskerMac
//
//  iOS版から必要分のみ移植。日/月境界などの便利拡張。
//

import Foundation

extension Date {
    /// その日の 00:00
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// 翌日の 00:00
    var startOfNextDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self
    }

    /// "4/26 (日)" 等の短い表記
    func shortDateWithWeekday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// "13:45" 等の時刻表記
    func hourMinute() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// その週の月曜 00:00
    var startOfWeek: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // 月曜始まり
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? startOfDay
    }

    /// その月の1日 00:00
    var startOfMonth: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps) ?? startOfDay
    }

    /// 翌月の1日 00:00
    var startOfNextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? self
    }

    /// "2026年4月" 形式
    func yearMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// "20260426_152230" 形式 (バックアップファイル名用)
    func exportFilenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
}
