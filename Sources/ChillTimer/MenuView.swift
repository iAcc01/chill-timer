import SwiftUI

// MARK: - 菜单栏浮窗（计时卡片 ⇄ 设置，浮窗内切换页面）

struct MenuBarPopover: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var settings: AppSettings

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
        // 切换外观后强制重绘（动态 NSColor 在已渲染视图上不一定即时刷新）
        .id(settings.appearanceRaw)
    }
}
