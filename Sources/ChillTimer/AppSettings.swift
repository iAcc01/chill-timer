import Combine
import Foundation
import SwiftUI

/// 全部配置存在本机 UserDefaults，无账号、无网络。
/// 修改后从下一轮开始生效。
@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private enum Key {
        static let workMinutes = "workMinutes"
        static let breakMinutes = "breakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let longBreakEvery = "longBreakEvery"
        static let bubbleSeconds = "bubbleSeconds"
        static let snoozeMinutes = "snoozeMinutes"
        static let gateSeconds = "gateSeconds"
        static let soundEnabled = "soundEnabled"
        static let menuBarShowsTime = "menuBarShowsTime"
        static let alwaysStanding = "alwaysStanding"
        static let alwaysEyeCare = "alwaysEyeCare"
        static let menuBarHighlightOnBreak = "menuBarHighlightOnBreak"
        static let autoStartBreak = "autoStartBreak"
        static let autoStartWork = "autoStartWork"
        static let fullscreenOnBreak = "fullscreenOnBreak"
        static let commitmentMode = "commitmentMode"
        static let appearance = "appearance"
    }

    @Published var workMinutes: Int { didSet { UserDefaults.standard.set(workMinutes, forKey: Key.workMinutes) } }
    @Published var breakMinutes: Int { didSet { UserDefaults.standard.set(breakMinutes, forKey: Key.breakMinutes) } }
    @Published var longBreakMinutes: Int { didSet { UserDefaults.standard.set(longBreakMinutes, forKey: Key.longBreakMinutes) } }
    @Published var longBreakEvery: Int { didSet { UserDefaults.standard.set(longBreakEvery, forKey: Key.longBreakEvery) } }
    @Published var bubbleSeconds: Int { didSet { UserDefaults.standard.set(bubbleSeconds, forKey: Key.bubbleSeconds) } }
    @Published var snoozeMinutes: Int { didSet { UserDefaults.standard.set(snoozeMinutes, forKey: Key.snoozeMinutes) } }
    @Published var gateSeconds: Int { didSet { UserDefaults.standard.set(gateSeconds, forKey: Key.gateSeconds) } }
    @Published var soundEnabled: Bool { didSet { UserDefaults.standard.set(soundEnabled, forKey: Key.soundEnabled) } }
    @Published var menuBarShowsTime: Bool { didSet { UserDefaults.standard.set(menuBarShowsTime, forKey: Key.menuBarShowsTime) } }
    @Published var alwaysStanding: Bool { didSet { UserDefaults.standard.set(alwaysStanding, forKey: Key.alwaysStanding) } }
    @Published var alwaysEyeCare: Bool { didSet { UserDefaults.standard.set(alwaysEyeCare, forKey: Key.alwaysEyeCare) } }
    @Published var menuBarHighlightOnBreak: Bool { didSet { UserDefaults.standard.set(menuBarHighlightOnBreak, forKey: Key.menuBarHighlightOnBreak) } }
    @Published var autoStartBreak: Bool { didSet { UserDefaults.standard.set(autoStartBreak, forKey: Key.autoStartBreak) } }
    @Published var autoStartWork: Bool { didSet { UserDefaults.standard.set(autoStartWork, forKey: Key.autoStartWork) } }
    @Published var fullscreenOnBreak: Bool { didSet { UserDefaults.standard.set(fullscreenOnBreak, forKey: Key.fullscreenOnBreak) } }
    @Published var commitmentMode: Bool { didSet { UserDefaults.standard.set(commitmentMode, forKey: Key.commitmentMode) } }
    @Published var appearanceRaw: String {
        didSet {
            UserDefaults.standard.set(appearanceRaw, forKey: Key.appearance)
            Self.applyAppearance(appearanceRaw)
        }
    }

    // MARK: 外观（系统 / 浅色 / 深色）

    enum Appearance: String, CaseIterable {
        case system, light, dark

        var label: String {
            switch self {
            case .system: return "系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }

        var nsAppearance: NSAppearance? {
            switch self {
            case .system: return nil          // 跟随系统
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }

        var next: Appearance {
            let index = Self.allCases.firstIndex(of: self) ?? 0
            return Self.allCases[(index + 1) % Self.allCases.count]
        }
    }

    var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }

    static func applyAppearance(_ raw: String) {
        NSApp.appearance = (Appearance(rawValue: raw) ?? .system).nsAppearance
    }

    private init() {
        Self.migrateLegacyDefaults()
        let ud = UserDefaults.standard
        workMinutes = ud.object(forKey: Key.workMinutes) as? Int ?? 30
        breakMinutes = ud.object(forKey: Key.breakMinutes) as? Int ?? 3
        longBreakMinutes = ud.object(forKey: Key.longBreakMinutes) as? Int ?? 15
        longBreakEvery = ud.object(forKey: Key.longBreakEvery) as? Int ?? 4
        bubbleSeconds = ud.object(forKey: Key.bubbleSeconds) as? Int ?? 30
        snoozeMinutes = ud.object(forKey: Key.snoozeMinutes) as? Int ?? 5
        gateSeconds = ud.object(forKey: Key.gateSeconds) as? Int ?? 10
        soundEnabled = ud.object(forKey: Key.soundEnabled) as? Bool ?? true
        menuBarShowsTime = ud.object(forKey: Key.menuBarShowsTime) as? Bool ?? true
        alwaysStanding = ud.object(forKey: Key.alwaysStanding) as? Bool ?? true
        alwaysEyeCare = ud.object(forKey: Key.alwaysEyeCare) as? Bool ?? true
        menuBarHighlightOnBreak = ud.object(forKey: Key.menuBarHighlightOnBreak) as? Bool ?? true
        autoStartBreak = ud.object(forKey: Key.autoStartBreak) as? Bool ?? true
        autoStartWork = ud.object(forKey: Key.autoStartWork) as? Bool ?? false
        fullscreenOnBreak = ud.object(forKey: Key.fullscreenOnBreak) as? Bool ?? true
        commitmentMode = ud.object(forKey: Key.commitmentMode) as? Bool ?? false
        appearanceRaw = ud.string(forKey: Key.appearance) ?? Appearance.system.rawValue
    }

    // MARK: 改名迁移（Unwind → Chill Timer，Bundle ID 变更后沿用旧设置与统计）

    private static func migrateLegacyDefaults() {
        let ud = UserDefaults.standard
        let flag = "migratedFromUnwind"
        guard !ud.bool(forKey: flag) else { return }
        if let legacy = ud.persistentDomain(forName: "com.unwind.app") {
            for (key, value) in legacy where ud.object(forKey: key) == nil {
                ud.set(value, forKey: key)
            }
        }
        ud.set(true, forKey: flag)
    }

    // MARK: 预设值（对齐 Flow：以选择为主，不让人自己填数字）

    static let workPresets = [15, 20, 25, 30, 45, 50, 60, 90]
    static let breakPresets = [1, 2, 3, 5, 10]
    static let longBreakPresets = [10, 15, 20, 30]
    static let longBreakEveryPresets = [2, 3, 4, 6]
    static let bubblePresets = [10, 15, 20, 30, 45, 60]
    static let snoozePresets = [3, 5, 10, 15]
    static let gatePresets = [0, 5, 10, 20, 30]

    /// 历史值不在预设里时补进去，避免 Picker 选不中
    static func options(_ presets: [Int], current: Int) -> [Int] {
        presets.contains(current) ? presets : (presets + [current]).sorted()
    }

    var breakSeconds: Int { max(60, breakMinutes * 60) }
}
