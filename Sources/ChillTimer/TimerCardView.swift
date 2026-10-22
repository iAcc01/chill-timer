import SwiftUI

// MARK: - 计时卡片（设计稿主体形态）
// 深黑圆角卡：环形进度 + 环内(图标/大倒计时/周期圆点/阶段标签) + 底部(重置/胶囊主按钮/设置)。

struct TimerCardView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var updater = UpdateChecker.shared

    var showFooterButtons = true   // 菜单栏浮窗与主窗口共用；气泡等场景可关
    var onSettings: () -> Void = {}

    private var isRest: Bool { engine.phase == .resting }

    /// 环形进度：已流逝比例
    private var progress: Double {
        guard engine.phaseTotal > 0 else { return 0 }
        switch engine.phase {
        case .running, .resting:
            return Double(engine.phaseTotal - engine.remaining) / Double(engine.phaseTotal)
        case .waitingBreak:
            return 1
        case .paused:
            return Double(engine.phaseTotal - engine.remaining) / Double(engine.phaseTotal)
        default:
            return 0
        }
    }

    /// 环内大数字
    private var bigTime: String {
        switch engine.phase {
        case .idle:
            return engine.clock(settings.workMinutes * 60)
        case .waitingWork:
            return engine.clock(settings.workMinutes * 60)
        default:
            return engine.clock(engine.remaining)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ringArea
            if showFooterButtons { footer }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Design.cardBG)
        )
    }

    // MARK: 环 + 内容

    private var ringArea: some View {
        ZStack {
            RingProgress(progress: progress, isRest: isRest)

            VStack(spacing: 8) {
                Image(systemName: Design.phaseSymbol(engine: engine))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isRest ? Design.restTop : Design.focusTop)

                Text(bigTime)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Design.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                CycleDots()

                Text(Design.phaseCaption(engine: engine))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Design.text.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // 我们的内核：休息时显示当前动作
                if engine.phase == .resting, let action = engine.currentAction {
                    HStack(spacing: 4) {
                        Image(systemName: action.symbol)
                        Text(action.name)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Design.restTop.opacity(0.9))
                    .minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, 30)
        }
        .frame(width: 176, height: 176)
    }

    // MARK: 底部三键

    private var footer: some View {
        HStack {
            CircleIconButton(systemName: "arrow.uturn.backward") {
                engine.resetCycle()
            }
            .disabled(engine.phase == .idle)
            .opacity(engine.phase == .idle ? 0.35 : 1)
            .help("重置周期")

            Spacer()

            PillButton(title: primaryTitle,
                       disabled: engine.isCommitted && (engine.phase == .running || engine.phase == .resting)) {
                switch engine.phase {
                case .waitingBreak: engine.startBreakNow()
                case .resting: engine.endBreakEarly()
                default: engine.toggleStartPause()
                }
            }

            Spacer()

            CircleIconButton(systemName: "gearshape") {
                onSettings()
            }
            .overlay(alignment: .topTrailing) {
                if updater.showBadge { BadgeDot().offset(x: -1, y: 1) }
            }
            .help("设置")
        }
    }

    private var primaryTitle: String {
        switch engine.phase {
        case .idle, .waitingWork: return "START"
        case .running: return "PAUSE"
        case .paused: return "RESUME"
        case .waitingBreak: return "BREAK"
        case .resting: return "END"
        }
    }
}
