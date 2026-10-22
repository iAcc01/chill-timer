import SwiftUI

// MARK: - 设置（浮窗内嵌页面，不再开独立窗口）
// 参考设计稿：标题居中 + 左上返回 + 胶囊分段控件 + 大数值行列表 + 步进子页。

struct SettingsView: View {
    enum Tab: String, CaseIterable {
        case duration = "时长"
        case alerts = "提醒"
        case behavior = "行为"
        case about = "关于"
    }

    enum Page: Equatable {
        case main
        case stepper(EditTarget)
    }

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var engine: TimerEngine
    @ObservedObject private var stats = StatsStore.shared

    /// 当前分段与子页：提升到浮窗层持有，避免切换外观重绘浮窗时被重置
    @Binding var tab: Tab
    @Binding var page: Page

    /// 点左上角返回：主设置页返回计时卡片；步进子页返回设置列表
    var onBackToTimer: () -> Void

    private var headerTitle: String {
        if case .stepper(let target) = page { return target.title }
        return "设置"
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            switch page {
            case .main:
                CapsuleSegment(options: Tab.allCases.map(\.rawValue),
                               selection: Binding(
                                   get: { Tab.allCases.firstIndex(of: tab) ?? 0 },
                                   set: { tab = Tab.allCases[$0] }
                               ))
                content
            case .stepper(let target):
                StepperBody(target: target)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: 顶栏：左上返回 + 居中标题

    private var header: some View {
        ZStack {
            Text(headerTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Design.text)
            HStack {
                Button {
                    if page == .main { onBackToTimer() } else { page = .main }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Design.text.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Design.surface))
                }
                .buttonStyle(.plain)
                .help(page == .main ? "返回" : "返回设置")
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .duration: DurationPage(onEdit: { page = .stepper($0) })
        case .alerts: AlertsPage(onEdit: { page = .stepper($0) })
        case .behavior: BehaviorPage()
        case .about: AboutPage(stats: stats)
        }
    }
}

// MARK: - 胶囊分段控件（对齐设计稿：深底容器 + 选中浅色胶囊）

private struct CapsuleSegment: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = index }
                } label: {
                    Text(options[index])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(index == selection ? Design.text : Design.text.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(index == selection ? AnyShapeStyle(Design.surface) : AnyShapeStyle(Color.clear))
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Design.track))
    }
}

// MARK: - 行组件（大数值 + 小单位 + chevron）

private struct SettingRow: View {
    let title: String
    var value: String = ""
    var unit: String = ""
    var largeValue = false
    var chevron = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.text.opacity(0.85))
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: largeValue ? 22 : 13, weight: largeValue ? .semibold : .medium, design: largeValue ? .rounded : .default))
                        .monospacedDigit()
                        .foregroundStyle(Design.text)
                }
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Design.text.opacity(0.45))
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Design.text.opacity(0.35))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, largeValue ? 10 : 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

private struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Design.surface))
    }
}

private func rowDivider() -> some View {
    Divider().overlay(Design.hairline)
}

// MARK: - 开关行（文字左 / 小号 switch 右）

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Design.text.opacity(0.85))
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Design.focusBottom)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

// MARK: - 编辑目标

enum EditTarget {
    case focus, shortBreak, longBreak, cycles
    case bubble, gate

    var title: String {
        switch self {
        case .focus: return "专注时长"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        case .cycles: return "长休间隔"
        case .bubble: return "气泡倒计时"
        case .gate: return "结束保护"
        }
    }

    var unit: String {
        switch self {
        case .cycles: return "轮"
        case .bubble, .gate: return "秒"
        default: return "分钟"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .focus: return 5...120
        case .shortBreak: return 1...15
        case .longBreak: return 5...45
        case .cycles: return 2...8
        case .bubble: return 5...120
        case .gate: return 0...60
        }
    }

    /// 步进子页下方的常用快捷值
    var presets: [Int] {
        switch self {
        case .focus: return [15, 25, 30, 45]
        case .shortBreak: return [1, 3, 5, 10]
        case .longBreak: return [10, 15, 20, 30]
        case .cycles: return [2, 3, 4, 6]
        case .bubble: return [10, 15, 30, 60]
        case .gate: return [0, 5, 10, 30]
        }
    }
}

// MARK: - 步进子页内容（- 25 +）

private struct StepperBody: View {
    @EnvironmentObject var settings: AppSettings
    let target: EditTarget

    private var value: Binding<Int> {
        switch target {
        case .focus: return $settings.workMinutes
        case .shortBreak: return $settings.breakMinutes
        case .longBreak: return $settings.longBreakMinutes
        case .cycles: return $settings.longBreakEvery
        case .bubble: return $settings.bubbleSeconds
        case .gate: return $settings.gateSeconds
        }
    }

    private var range: ClosedRange<Int> { target.range }

    private var unit: String { target.unit }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                CircleIconButton(systemName: "minus") { step(-1) }
                TextField("", value: value, format: .number.grouping(.never))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Design.text)
                    .frame(width: 84)
                    .onSubmit { clamp() }
                CircleIconButton(systemName: "plus") { step(1) }
            }

            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(Design.text.opacity(0.4))

            HStack(spacing: 8) {
                ForEach(target.presets, id: \.self) { preset in
                    let selected = value.wrappedValue == preset
                    Button {
                        value.wrappedValue = preset
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(selected ? Color.white : Design.text.opacity(0.75))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selected
                                    ? AnyShapeStyle(Design.focusBottom)
                                    : AnyShapeStyle(Design.surface))
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private func step(_ delta: Int) {
        clamp()
        value.wrappedValue = min(max(value.wrappedValue + delta, range.lowerBound), range.upperBound)
    }

    private func clamp() {
        value.wrappedValue = min(max(value.wrappedValue, range.lowerBound), range.upperBound)
    }
}

// MARK: - 时长页

private struct DurationPage: View {
    @EnvironmentObject var settings: AppSettings
    var onEdit: (EditTarget) -> Void

    var body: some View {
        VStack(spacing: 12) {
            RowGroup {
                SettingRow(title: "专注时长", value: "\(settings.workMinutes)", unit: "分钟", largeValue: true, chevron: true) { onEdit(.focus) }
                rowDivider()
                SettingRow(title: "短休息", value: String(format: "%02d", settings.breakMinutes), unit: "分钟", largeValue: true, chevron: true) { onEdit(.shortBreak) }
                rowDivider()
                SettingRow(title: "长休息", value: String(format: "%02d", settings.longBreakMinutes), unit: "分钟", largeValue: true, chevron: true) { onEdit(.longBreak) }
                rowDivider()
                SettingRow(title: "长休间隔", value: "\(settings.longBreakEvery)", unit: "轮", largeValue: true, chevron: true) { onEdit(.cycles) }
            }
        }
    }
}

// MARK: - 提醒页

private struct AlertsPage: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var engine: TimerEngine
    var onEdit: (EditTarget) -> Void

    var body: some View {
        VStack(spacing: 12) {
            RowGroup {
                SettingRow(title: "气泡倒计时", value: "\(settings.bubbleSeconds)", unit: "秒", largeValue: true, chevron: true) { onEdit(.bubble) }
                rowDivider()
                SettingRow(title: "结束保护", value: "\(settings.gateSeconds)", unit: "秒", largeValue: true, chevron: true) { onEdit(.gate) }
            }

            RowGroup {
                ToggleRow(title: "提示音", isOn: $settings.soundEnabled)
            }

            RowGroup {
                SettingRow(title: "立即休息", value: "", chevron: true) { engine.startBreakNow() }
            }

            Text("气泡倒计时后无操作将自动进入休息；结束保护期间不可提前结束休息。")
                .font(.caption)
                .foregroundStyle(Design.text.opacity(0.35))
                .padding(.horizontal, 6)
        }
    }
}

// MARK: - 行为页

private struct BehaviorPage: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 12) {
            RowGroup {
                SettingRow(title: "外观", value: settings.appearance.label) {
                    settings.appearanceRaw = settings.appearance.next.rawValue
                }
            }

            RowGroup {
                toggleRow("自动开始休息", $settings.autoStartBreak)
                rowDivider()
                toggleRow("自动开始下一轮", $settings.autoStartWork)
                rowDivider()
                toggleRow("休息时全屏", $settings.fullscreenOnBreak)
                rowDivider()
                toggleRow("承诺模式", $settings.commitmentMode)
            }

            Text("承诺模式开启后无法暂停、跳过或重置。")
                .font(.caption)
                .foregroundStyle(Design.text.opacity(0.35))
                .padding(.horizontal, 6)
        }
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        ToggleRow(title: title, isOn: binding)
    }
}

// MARK: - 关于页

private struct AboutPage: View {
    @ObservedObject var stats: StatsStore

    var body: some View {
        VStack(spacing: 12) {
            RowGroup {
                SettingRow(title: "今天", value: "\(stats.today)", unit: "次休息", largeValue: true)
                rowDivider()
                SettingRow(title: "近 7 天", value: "\(stats.lastSevenDays)", unit: "次", largeValue: true)
                rowDivider()
                SettingRow(title: "累计", value: "\(stats.total)", unit: "次", largeValue: true)
            }

            RowGroup {
                SettingRow(title: "版本", value: "0.1.0")
                rowDivider()
                SettingRow(title: "隐私", value: "数据全部在本机")
            }

            RowGroup {
                SettingRow(title: "退出 Chill Timer", value: "", chevron: true) { NSApp.terminate(nil) }
            }

            Text("不联网、不读取屏幕内容、不需要摄像头权限。")
                .font(.caption)
                .foregroundStyle(Design.text.opacity(0.35))
                .padding(.horizontal, 6)
        }
    }
}
