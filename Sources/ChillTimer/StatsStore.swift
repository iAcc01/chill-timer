import Foundation
import SwiftUI

/// 休息完成次数。按天存在本机 UserDefaults，不出设备。
@MainActor
final class StatsStore: ObservableObject {

    static let shared = StatsStore()

    private enum Key {
        static let history = "breaksHistory"   // ["yyyy-MM-dd": 次数]
    }

    @Published private(set) var history: [String: Int] = [:]

    private init() {
        history = (UserDefaults.standard.dictionary(forKey: Key.history) as? [String: Int]) ?? [:]
    }

    func recordBreak() {
        history[Self.dayKey(for: Date()), default: 0] += 1
        UserDefaults.standard.set(history, forKey: Key.history)
    }

    var today: Int { history[Self.dayKey(for: Date())] ?? 0 }
    var lastSevenDays: Int { lastSevenDaysSeries().reduce(0) { $0 + $1.count } }
    var total: Int { history.values.reduce(0, +) }

    /// 最近 7 天（含今天），从最早到今天
    func lastSevenDaysSeries() -> [(label: String, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            return (Self.weekdayLabel(for: date), history[Self.dayKey(for: date)] ?? 0)
        }
    }

    func reset() {
        history = [:]
        UserDefaults.standard.removeObject(forKey: Key.history)
    }

    // MARK: -

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static func dayKey(for date: Date) -> String { dayFormatter.string(from: date) }
    private static func weekdayLabel(for date: Date) -> String { weekdayFormatter.string(from: date) }
}
