import AppKit
import SwiftUI

@MainActor
@main
struct ChillTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var engine = TimerEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(engine)
                .environmentObject(settings)
        } label: {
            let resting = engine.phase == .resting
            Image(systemName: resting ? "figure.walk" : "timer")
                .foregroundStyle(resting && settings.menuBarHighlightOnBreak ? Color.green : Color.primary)
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowManager.shared.hideOverlay()
        WindowManager.shared.hideBubble()
    }
}
