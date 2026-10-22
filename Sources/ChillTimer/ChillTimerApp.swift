import AppKit
import SwiftUI

@MainActor
@main
struct ChillTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var engine = TimerEngine.shared
    @StateObject private var updater = UpdateChecker.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(engine)
                .environmentObject(settings)
        } label: {
            let resting = engine.phase == .resting
            if updater.showBadge {
                // 有新版本：图标右上角红点（非模板图，红色才不会被菜单栏着色抹掉）
                Image(nsImage: MenuBarIcon.badged(symbol: resting ? "figure.walk" : "timer"))
            } else {
                Image(systemName: resting ? "figure.walk" : "timer")
                    .foregroundStyle(resting && settings.menuBarHighlightOnBreak ? Color.green : Color.primary)
            }
            if settings.menuBarShowsTime {
                Text(engine.menuBadge)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppSettings.applyAppearance(AppSettings.shared.appearanceRaw)
        TimerEngine.shared.start()
        UpdateChecker.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowManager.shared.hideOverlay()
        WindowManager.shared.hideBubble()
    }
}
