import AppKit
import SwiftUI

/// 负责两个窗口：气泡提醒面板（NSPanel）与全屏遮罩（每个屏幕一个 NSWindow）。
@MainActor
final class WindowManager {

    static let shared = WindowManager()

    private var bubble: BubblePanel?
    private var overlays: [NSWindow] = []
    private var keyMonitor: Any?

    private init() {}

    // MARK: 气泡

    func showBubble(engine: TimerEngine) {
        let panel = bubble ?? BubblePanel()
        bubble = panel
        panel.contentView = NSHostingView(
            rootView: BubbleView()
                .environmentObject(engine)
                .environmentObject(AppSettings.shared)
        )
        position(panel)
        panel.orderFrontRegardless()
    }

    func hideBubble() {
        bubble?.orderOut(nil)
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(x: visible.midX - size.width / 2,
                    y: visible.maxY - size.height - 4)
        )
    }

    // MARK: 全屏遮罩

    func showOverlay(engine: TimerEngine) {
        hideOverlay()
        for screen in NSScreen.screens {
            let window = OverlayWindow(frame: screen.frame)
            window.contentView = NSHostingView(
                rootView: BreakOverlayView()
                    .environmentObject(engine)
                    .environmentObject(AppSettings.shared)
            )
            window.orderFrontRegardless()
            overlays.append(window)
        }
        overlays.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installEscapeMonitor(engine: engine)
    }

    func hideOverlay() {
        removeEscapeMonitor()
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
    }

    private func installEscapeMonitor(engine: TimerEngine) {
        removeEscapeMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                Task { @MainActor in engine.handleEscape() }
                return nil
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

// MARK: - 窗口子类

final class BubblePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 372, height: 96),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .transient]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OverlayWindow: NSWindow {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = true
        // 深色深蓝黑 / 浅色浅灰：跟随外观，避免窗口出现时的闪色
        backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.055, green: 0.065, blue: 0.085, alpha: 1)
                : NSColor(calibratedWhite: 0.96, alpha: 1)
        }
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
