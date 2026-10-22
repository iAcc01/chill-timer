import SwiftUI

// MARK: - 菜单栏浮窗（计时卡片 ⇄ 设置，浮窗内切换页面）

struct MenuBarPopover: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var updater = UpdateChecker.shared

    @State private var showSettings = false
    @State private var tab: SettingsView.Tab = .duration
    @State private var page: SettingsView.Page = .main

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(tab: $tab, page: $page, onBackToTimer: {
                    withAnimation(.easeOut(duration: 0.15)) { showSettings = false }
                })
            } else {
                Text("Chill Timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.text.opacity(0.9))
                    .padding(.top, 10)
                    .padding(.bottom, 2)

                TimerCardView(onSettings: {
                    withAnimation(.easeOut(duration: 0.15)) { showSettings = true }
                })
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 256)
        .background(Design.windowBG)
        .overlay {
            if updater.dialogPresented, let release = updater.latest {
                UpdateDialog(release: release)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: updater.dialogPresented)
        // 切换外观后强制重绘（动态 NSColor 在已渲染视图上不一定即时刷新）
        .id(settings.appearanceRaw)
    }
}

// MARK: - 更新确认弹窗（浮窗内）

private struct UpdateDialog: View {
    let release: UpdateChecker.Release
    @ObservedObject private var updater = UpdateChecker.shared

    private var busy: Bool {
        updater.installState == .downloading || updater.installState == .installing
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture { updater.dismissDialog() }

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Design.brand)

                VStack(spacing: 3) {
                    Text("发现新版本 v\(release.version)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.text)
                    Text("当前版本 v\(updater.currentVersion)，是否更新？")
                        .font(.system(size: 11))
                        .foregroundStyle(Design.text.opacity(0.5))
                }

                if !release.notes.isEmpty {
                    ScrollView {
                        Text(release.notes)
                            .font(.system(size: 11))
                            .foregroundStyle(Design.text.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 72)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Design.surface))
                }

                if case .failed(let message) = updater.installState {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(Design.brand)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if busy {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(updater.installState == .downloading ? "正在下载…" : "正在安装，完成后自动重启…")
                            .font(.system(size: 12))
                            .foregroundStyle(Design.text.opacity(0.7))
                    }
                    .frame(height: 34)
                } else {
                    HStack(spacing: 8) {
                        Button { updater.remindLater() } label: {
                            Text("稍后提醒")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Design.text.opacity(0.75))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Design.surface))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button { updater.installLatest() } label: {
                            Text("立即更新")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Design.brand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Design.brand.opacity(0.15)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(width: 224)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Design.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Design.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }
}

// MARK: - 红点

struct BadgeDot: View {
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Design.cardBG, lineWidth: 1.5))
    }
}
