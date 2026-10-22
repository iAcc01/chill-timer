import AppKit
import Foundation
import SwiftUI

enum Phase: Equatable {
    case idle          // 未开始
    case running       // 专注中
    case paused        // 已暂停
    case waitingBreak  // 本轮专注结束，气泡确认中
    case resting       // 休息中（含拉伸指引）
    case waitingWork   // 休息结束，等待开始下一轮
}

enum BreakKind: Equatable {
    case normal
    case long
}

/// 状态机（Flow 的循环骨架 + 我们自己的内核）
///
/// Flow 的部分：专注 → 休息 → 下一轮 → N 轮后长休息 → 周期归零；自动开始、承诺模式、跳过、重置周期。
/// 我们的部分：**每一轮休息前必经气泡确认**；休息内容是全屏拉伸指引，不是空转倒计时。
@MainActor
final class TimerEngine: ObservableObject {

    static let shared = TimerEngine()

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remaining: Int = 0
    @Published private(set) var phaseTotal: Int = 0
    @Published private(set) var cycleIndex: Int = 0          // 当前第几轮专注（0 起）
    @Published private(set) var breakKind: BreakKind = .normal
    @Published private(set) var sequence: [StretchAction] = []
    @Published private(set) var actionIndex: Int = 0
    @Published private(set) var actionRemaining: Int = 0
    @Published private(set) var breaksToday: Int = 0

    private var timer: Timer?
    private var started = false
    private let settings = AppSettings.shared
    private let windows = WindowManager.shared
    private let stats = StatsStore.shared

    var currentAction: StretchAction? {
        sequence.indices.contains(actionIndex) ? sequence[actionIndex] : nil
    }

    var nextAction: StretchAction? {
        let index = actionIndex + 1
        return sequence.indices.contains(index) ? sequence[index] : nil
    }

    var breakElapsed: Int { max(0, phaseTotal - remaining) }

    /// 本轮结束后是否轮到长休息
    var isLongBreakDue: Bool {
        settings.longBreakEvery > 0 && cycleIndex > 0 &&
        cycleIndex % settings.longBreakEvery == settings.longBreakEvery - 1
    }

    var isCommitted: Bool { settings.commitmentMode }

    var currentBreakSeconds: Int {
        breakKind == .long ? settings.longBreakMinutes * 60 : settings.breakSeconds
    }

    private init() {
        breaksToday = StatsStore.shared.today
    }

    func start() {
        guard !started else { return }
        started = true
        beginIdle()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - 状态迁移

    private func tick() {
        guard phase != .paused else { return }
        guard phase != .idle, phase != .waitingWork else { return }

        let before = remaining
        remaining = max(0, remaining - 1)

        switch phase {
        case .running:
            if remaining == 0 { finishWork() }
        case .waitingBreak:
            // 倒计时归零：开了自动就开始，没开就等用户确认（气泡始终在）
            if remaining == 0, before > 0, settings.autoStartBreak { beginBreak() }
        case .resting:
            actionRemaining = max(0, actionRemaining - 1)
            if actionRemaining == 0 { advanceAction() }
        case .idle, .paused, .waitingWork:
            break
        }
    }

    private func beginIdle() {
        windows.hideBubble()
        windows.hideOverlay()
        phase = .idle
        remaining = 0
        phaseTotal = 0
    }

    func startWork() {
        windows.hideBubble()
        phase = .running
        phaseTotal = max(60, settings.workMinutes * 60)
        remaining = phaseTotal
    }

    /// 一轮专注结束：**总是弹气泡确认**（这是我们与 Flow 的分歧点，保留）
    private func finishWork() {
        if settings.soundEnabled { NSSound(named: NSSound.Name("Glass"))?.play() }
        phase = .waitingBreak
        phaseTotal = max(5, settings.bubbleSeconds)
        remaining = phaseTotal
        windows.showBubble(engine: self)
    }

    func beginBreak() {
        windows.hideBubble()
        breakKind = isLongBreakDue ? .long : .normal
        sequence = StretchLibrary.buildSequence(
            duration: currentBreakSeconds,
            includeStanding: settings.alwaysStanding,
            includeEyeCare: settings.alwaysEyeCare
        )
        actionIndex = 0
        actionRemaining = sequence.first?.duration ?? 30
        phaseTotal = sequence.reduce(0) { $0 + $1.duration }
        remaining = phaseTotal
        phase = .resting
        if settings.fullscreenOnBreak {
            windows.showOverlay(engine: self)
        }
    }

    private func advanceAction() {
        let next = actionIndex + 1
        if sequence.indices.contains(next) {
            actionIndex = next
            actionRemaining = sequence[next].duration
        } else {
            finishBreak(counted: true)
        }
    }

    private func finishBreak(counted: Bool, userInitiated: Bool = false) {
        windows.hideOverlay()
        if counted {
            stats.recordBreak()
            breaksToday = stats.today
        }
        if settings.soundEnabled { NSSound(named: NSSound.Name("Ping"))?.play() }

        cycleIndex += 1
        if breakKind == .long { cycleIndex = 0 }

        // 用户主动点「结束休息」= 明确要开始下一轮，无视「自动开始下一轮」设置
        if settings.autoStartWork || userInitiated {
            startWork()
        } else {
            phase = .waitingWork
            phaseTotal = 0
            remaining = 0
        }
    }

    // MARK: - 用户操作

    func toggleStartPause() {
        switch phase {
        case .idle, .waitingWork: startWork()
        case .running where !isCommitted: phase = .paused
        case .paused: phase = .running
        default: break
        }
    }

    /// 跳过当前阶段（Flow：Skip session or break）。承诺模式下禁用。
    func skipCurrent() {
        guard !isCommitted else { return }
        switch phase {
        case .running:
            remaining = 0
            finishWork()
        case .waitingBreak:
            skipBreak()
        case .resting:
            finishBreak(counted: false, userInitiated: true)
        case .idle, .paused, .waitingWork:
            break
        }
    }

    /// 气泡：跳过本次休息，直接进入下一轮
    func skipBreak() {
        guard phase == .waitingBreak else { return }
        windows.hideBubble()
        cycleIndex += 1
        if isLongBreakDue { cycleIndex = 0 }
        beginIdle()
        if settings.autoStartWork { startWork() }
    }

    /// 气泡：延后——关掉气泡，重新计时一段短专注
    func snooze() {
        guard phase == .waitingBreak else { return }
        windows.hideBubble()
        phase = .running
        phaseTotal = max(60, settings.snoozeMinutes * 60)
        remaining = phaseTotal
    }

    /// 重置整个周期（Flow：Restart cycle）。承诺模式下禁用。
    func resetCycle() {
        guard !isCommitted else { return }
        windows.hideBubble()
        windows.hideOverlay()
        cycleIndex = 0
        beginIdle()
    }

    func stopAll() { resetCycle() }

    /// 休息提前结束：受结束保护与承诺模式约束（用户主动结束 → 直接开始下一轮）
    func endBreakEarly() {
        guard phase == .resting, !isCommitted, breakElapsed >= settings.gateSeconds else { return }
        finishBreak(counted: true, userInitiated: true)
    }

    /// 设置页 / 气泡：立刻开始休息（未在计时则直接休；专注中则打断当前专注）
    func startBreakNow() {
        guard phase != .resting else { return }
        if phase == .waitingBreak {
            beginBreak()
        } else {
            // 丢弃当前专注进度（不计入统计），直接进入休息
            beginIdle()
            beginBreak()
        }
    }

    /// 预览提醒气泡
    func requestBreak() {
        guard phase != .resting else { return }
        phase = .waitingBreak
        phaseTotal = max(5, settings.bubbleSeconds)
        remaining = phaseTotal
        windows.showBubble(engine: self)
    }

    /// Esc：休息中请求结束；气泡中视为跳过
    func handleEscape() {
        switch phase {
        case .resting: endBreakEarly()
        case .waitingBreak: skipBreak()
        default: break
        }
    }

    // MARK: - 展示用

    var phaseTitle: String {
        switch phase {
        case .idle: return "准备开始"
        case .running: return "专注中"
        case .paused: return "已暂停"
        case .waitingBreak: return "该休息了"
        case .resting: return breakKind == .long ? "长休息" : "休息中"
        case .waitingWork: return "休息结束"
        }
    }

    var menuBadge: String {
        switch phase {
        case .idle: return clock(settings.workMinutes * 60)
        case .running, .resting: return clock(remaining)
        case .paused: return "暂停"
        case .waitingBreak: return "该休息了"
        case .waitingWork: return clock(settings.workMinutes * 60)
        }
    }

    var statusText: String {
        switch phase {
        case .idle: return "未开始 · 点「开始专注」"
        case .running: return "专注中 · 剩余 \(clock(remaining))"
        case .paused: return "已暂停 · 剩余 \(clock(remaining))"
        case .waitingBreak: return "本轮结束 · \(clock(remaining)) 后自动休息"
        case .resting: return "\(phaseTitle) · 剩余 \(clock(remaining))"
        case .waitingWork: return "休息结束 · 点「开始专注」进入下一轮"
        }
    }

    func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
