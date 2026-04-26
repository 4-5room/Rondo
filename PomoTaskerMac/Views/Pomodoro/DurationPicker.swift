//
//  DurationPicker.swift
//  PomoTaskerMac
//
//  作業時間 / 休憩時間 を選ぶピッカー (Mac版)。
//  iOS版から compact レイアウトを削除して Portrait のみに。
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct DurationPicker: View {
    let label: String
    let symbolName: String
    let tint: Color
    let range: ClosedRange<Int>
    let presets: [Int]
    @Binding var minutes: Int

    init(
        label: String,
        symbolName: String,
        tint: Color = .accentColor,
        range: ClosedRange<Int> = 1...180,
        presets: [Int],
        minutes: Binding<Int>
    ) {
        self.label = label
        self.symbolName = symbolName
        self.tint = tint
        self.range = range
        self.presets = presets
        self._minutes = minutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                valuePill
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { m in
                    Button {
                        minutes = m
                    } label: {
                        Text("\(m)")
                            .font(.subheadline)
                            .fontWeight(minutes == m ? .semibold : .regular)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                minutes == m ? tint : Color(NSColor.controlBackgroundColor),
                                in: Capsule()
                            )
                            .foregroundStyle(minutes == m ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }

                Stepper(value: $minutes, in: range, step: 1) { EmptyView() }
                    .labelsHidden()
                    .padding(.leading, 4)
            }
        }
    }

    private var valuePill: some View {
        Text("\(minutes) 分")
            .font(.caption.monospacedDigit())
            .foregroundStyle(tint)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.15), value: minutes)
    }
}

#Preview {
    struct Demo: View {
        @State var work = 25
        @State var brk = 5
        var body: some View {
            VStack(spacing: 24) {
                DurationPicker(
                    label: "作業時間",
                    symbolName: "brain.head.profile",
                    tint: .blue,
                    presets: [15, 25, 45, 60],
                    minutes: $work
                )
                DurationPicker(
                    label: "休憩時間",
                    symbolName: "cup.and.saucer.fill",
                    tint: .green,
                    range: 1...60,
                    presets: [3, 5, 10, 15],
                    minutes: $brk
                )
            }
            .padding()
        }
    }
    return Demo()
}
