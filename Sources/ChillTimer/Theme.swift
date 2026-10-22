import SwiftUI

// MARK: - 设计令牌（黑色卡片 / 橙红渐变环 / 大数字）
// 依据设计稿：深黑圆角卡、灰色轨道环、橙红进度、白色大数字、小号全大写标签。

enum Design {

    // MARK: 动态取色（系统/浅色/深色 自动切换）

    /// 生成一个随 NSAppearance 自动切换的 SwiftUI Color
    static func dyn(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { app in
            app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    private static let nearBlack = NSColor(calibratedRed: 0.043, green: 0.043, blue: 0.047, alpha: 1)

    /// 卡片底色：深色近黑 / 浅色纯白
    static let cardBG = dyn(light: NSColor(calibratedWhite: 1.0, alpha: 1), dark: nearBlack)
    /// 浮窗/窗口底色：浅色下比卡片略深，让卡片边界可见
    static let windowBG = dyn(light: NSColor(calibratedWhite: 0.945, alpha: 1), dark: nearBlack)
    /// 次级表面（行、分段控件、按钮底）：由前景色低透明度叠加而来，两种模式下语义一致
    static let surface = dyn(light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
                             dark: NSColor(calibratedWhite: 1.0, alpha: 0.07))
    /// 更淡的凹槽底（分段控件容器）
    static let track = dyn(light: NSColor(calibratedWhite: 0.0, alpha: 0.06),
                           dark: NSColor(calibratedWhite: 1.0, alpha: 0.05))
    /// 环轨道
    static let ringTrack = dyn(light: NSColor(calibratedWhite: 0.0, alpha: 0.12),
                               dark: NSColor(calibratedWhite: 1.0, alpha: 0.14))
    /// 主文字色
    static let text = dyn(light: NSColor(calibratedWhite: 0.10, alpha: 1),
                          dark: NSColor(calibratedWhite: 1.0, alpha: 1))
    /// 分隔线
    static let hairline = dyn(light: NSColor(calibratedWhite: 0.0, alpha: 0.09),
                              dark: NSColor(calibratedWhite: 1.0, alpha: 0.08))

    /// 品牌色（文字/淡底按钮用）：深色用亮橙红，浅色压深保证对比度
    static let brand = dyn(light: NSColor(calibratedRed: 0.90, green: 0.28, blue: 0.12, alpha: 1),
                           dark: NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.22, alpha: 1))
    /// 主色：橙红（专注进度）
    static let focusTop = Color(red: 1.0, green: 0.42, blue: 0.22)
    static let focusBottom = Color(red: 0.90, green: 0.13, blue: 0.10)
    /// 休息用绿色：浅色下压深以保证对比度
    static let restTop = dyn(light: NSColor(calibratedRed: 0.09, green: 0.60, blue: 0.28, alpha: 1),
                             dark: NSColor(calibratedRed: 0.36, green: 0.85, blue: 0.45, alpha: 1))
    static let restBottom = dyn(light: NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.24, alpha: 1),
                                dark: NSColor(calibratedRed: 0.13, green: 0.66, blue: 0.32, alpha: 1))

    /// 全屏休息遮罩底色：深色近黑蓝 / 浅色浅灰
    static func overlayBG(isDark: Bool) -> [Color] {
        isDark ? [Color(red: 0.07, green: 0.08, blue: 0.11), Color(red: 0.11, green: 0.13, blue: 0.17)]
               : [Color(red: 0.96, green: 0.965, blue: 0.98), Color(red: 0.91, green: 0.92, blue: 0.94)]
    }

    static func gradient(isRest: Bool) -> LinearGradient {
        LinearGradient(colors: isRest ? [restTop, restBottom] : [focusTop, focusBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 阶段名（卡片环下方的小字，全大写）
    @MainActor
    static func phaseCaption(engine: TimerEngine) -> String {
        switch engine.phase {
        case .idle, .running, .paused: return "FOCUS"
        case .waitingBreak: return "TIME FOR A BREAK"
        case .resting: return engine.breakKind == .long ? "LONG BREAK" : "SHORT BREAK"
        case .waitingWork: return "NEXT ROUND"
        }
    }

    /// 环内图标（专注=闹铃，休息=咖啡杯，长休=行走）
    @MainActor
    static func phaseSymbol(engine: TimerEngine) -> String {
        switch engine.phase {
        case .idle, .running, .paused, .waitingBreak, .waitingWork: return "alarm"
        case .resting: return engine.breakKind == .long ? "figure.walk" : "cup.and.saucer"
        }
    }
}

// MARK: - 环形进度

struct RingProgress: View {
    /// 0...1，已进行比例（从顶部顺时针）
    let progress: Double
    let isRest: Bool
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .stroke(Design.ringTrack, style: StrokeStyle(lineWidth: lineWidth))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Design.gradient(isRest: isRest),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
        }
    }
}

// MARK: - 圆形图标按钮（左下重置 / 右下设置）

struct CircleIconButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.text.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Design.surface))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 胶囊主按钮（START / PAUSE）

struct PillButton: View {
    let title: String
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Design.text)
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(Capsule().fill(Design.surface))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - 周期圆点

struct CycleDots: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        let total = max(1, settings.longBreakEvery)
        let filled: Int = engine.phase == .idle ? 0 : min(engine.cycleIndex + 1, total)
        return HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < filled
                          ? AnyShapeStyle(Design.gradient(isRest: engine.phase == .resting))
                          : AnyShapeStyle(Design.ringTrack))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

