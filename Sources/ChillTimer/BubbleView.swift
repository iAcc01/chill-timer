import SwiftUI

/// 气泡提醒（对齐设计稿）：左侧粗环倒计时 + 标题/副标题 + 右侧 × 与「开始」胶囊。
/// 配色全部走外观语义色（浅色/深色自动切换）。
struct BubbleView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var settings: AppSettings

    private var progress: Double {
        guard engine.phaseTotal > 0 else { return 0 }
        return Double(engine.remaining) / Double(engine.phaseTotal)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 环形倒计时（12px 粗环）
            ZStack {
                Circle()
                    .stroke(Design.ringTrack, style: StrokeStyle(lineWidth: 6))
                Circle()
                    .trim(from: 0, to: max(0.001, progress))
                    .stroke(Design.gradient(isRest: false),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(engine.remaining)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Design.text)
            }
            .frame(width: 58, height: 58)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("起身吧，别卷了")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Design.text)
                Text("已专注\(settings.workMinutes)分钟，休息一下")
                    .font(.system(size: 12))
                    .foregroundStyle(Design.text.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // 关闭：跳过本次休息
            Button {
                engine.skipBreak()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Design.text.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Design.surface))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("跳过本次休息")

            // 开始休息
            Button {
                engine.startBreakNow()
            } label: {
                Text("休息")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Design.brand)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Design.brand.opacity(0.15)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("开始休息")
        }
        .padding(.horizontal, 14)
        .frame(width: 372, height: 96)
        .background(Design.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Design.hairline, lineWidth: 1)
        )
    }
}
