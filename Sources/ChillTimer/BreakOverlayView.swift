import SwiftUI

/// 全屏休息界面：按主界面设计语言。
/// 单栏圆角卡片（cardBG）：参考插画 + 动作名/秒数 + 设置页同款步骤行组 + 胶囊主按钮（PillButton）。
/// 主色统一为品牌橙红。
struct BreakOverlayView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var settings: AppSettings

    private var canEnd: Bool { engine.breakElapsed >= settings.gateSeconds }

    var body: some View {
        ZStack {
            Design.windowBG.ignoresSafeArea()

            card
                .frame(width: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 主卡片

    private var card: some View {
        VStack(spacing: 28) {
            if let action = engine.currentAction {
                actionArea(action)
            }
            footer
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Design.cardBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Design.hairline, lineWidth: 1)
        )
    }

    // MARK: 右侧：参考图 + 动作名 + 步骤行组

    private func actionArea(_ action: StretchAction) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 参考插画
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Design.surface)
                if let image = Self.actionImage(action.id) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: action.symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(Design.brand)
                }
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // 动作名 + 部位 + 当前动作倒计时
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Design.text)
                    Text(action.target)
                        .font(.system(size: 12))
                        .foregroundStyle(Design.text.opacity(0.45))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(engine.actionRemaining)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Design.brand)
                    Text("秒")
                        .font(.system(size: 12))
                        .foregroundStyle(Design.text.opacity(0.45))
                }
            }

            // 步骤：设置页同款行组
            VStack(spacing: 0) {
                ForEach(Array(action.steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 {
                        Divider().overlay(Design.hairline)
                    }
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Design.brand)
                            .frame(width: 16)
                        Text(step)
                            .font(.system(size: 13))
                            .foregroundStyle(Design.text.opacity(0.85))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Design.surface)
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 底部：下一个 / 胶囊主按钮 / 结束提示

    private var footer: some View {
        ZStack {
            HStack {
                if let next = engine.nextAction {
                    HStack(spacing: 10) {
                        if let image = Self.actionImage(next.id) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(Design.text.opacity(0.45))
                            Text(next.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Design.text)
                        }
                    }
                }
                Spacer()
                Text(canEnd ? "按 Esc 也可结束" : "\(settings.gateSeconds - engine.breakElapsed) 秒后可结束")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Design.text.opacity(0.45))
            }

            // 主按钮：与主卡片休息态同款「END」
            PillButton(title: "END", disabled: !canEnd || engine.isCommitted) {
                engine.endBreakEarly()
            }
        }
    }

    // MARK: 资源加载（App Bundle Contents/Resources/Actions/<id>.png）

    private static let imageCache: [String: NSImage] = {
        var cache: [String: NSImage] = [:]
        for action in StretchLibrary.all {
            if let url = Bundle.main.url(forResource: action.id, withExtension: "png", subdirectory: "Actions"),
               let image = NSImage(contentsOf: url) {
                cache[action.id] = image
            }
        }
        return cache
    }()

    private static func actionImage(_ id: String) -> NSImage? {
        imageCache[id]
    }
}
