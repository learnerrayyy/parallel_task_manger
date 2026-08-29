import Foundation
import SwiftData

/// 文档 §6：Every day / Weekdays / Specific weekdays / X times per week
nonisolated enum RecurrenceRule: Codable, Equatable, Hashable {
    case everyDay
    case weekdays
    case everyNDays(Int)
    /// weekday: 1 = Sunday ... 7 = Saturday（对应 Calendar.component(.weekday, from:)）
    case specificWeekdays(Set<Int>)
    case timesPerWeek(Int)

    var displayName: String {
        switch self {
        case .everyDay: return "Every day"
        case .weekdays: return "Weekdays"
        case .everyNDays(let n): return "Every \(n) days"
        case .specificWeekdays(let days):
            let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return days.sorted().map { symbols[$0] }.joined(separator: " / ")
        case .timesPerWeek(let n):
            return "\(n)x / week"
        }
    }
}

@Model
final class RecurringTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var order: Int
    var startDate: Date?
    private var ruleData: Data

    /// 记录已完成的日期（"yyyy-MM-dd" 字符串集合，编码为 JSON），
    /// 用于判断"今天是否已完成"以及未来做 streak 统计。
    private var completedDatesData: Data

    var project: Project?

    var rule: RecurrenceRule {
        get {
            (try? JSONDecoder().decode(RecurrenceRule.self, from: ruleData)) ?? .everyDay
        }
        set {
            ruleData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private var completedDates: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: completedDatesData)) ?? []
        }
        set {
            completedDatesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var lastCompleted: Date? {
        completedDates.compactMap(Self.dayFormatter.date(from:)).max()
    }

    init(title: String, rule: RecurrenceRule, project: Project?, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.order = order
        self.startDate = Date()
        self.project = project
        self.ruleData = (try? JSONEncoder().encode(rule)) ?? Data()
        self.completedDatesData = (try? JSONEncoder().encode(Set<String>())) ?? Data()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    /// 该 recurring task 在指定日期是否应该出现
    func isDue(on date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch rule {
        case .everyDay:
            return true
        case .weekdays:
            return (2...6).contains(weekday) // Mon(2)...Fri(6)
        case .everyNDays(let n):
            let interval = max(n, 1)
            let anchor = Calendar.current.startOfDay(for: startDate ?? Date())
            let target = Calendar.current.startOfDay(for: date)
            let days = Calendar.current.dateComponents([.day], from: anchor, to: target).day ?? 0
            return days >= 0 && days % interval == 0
        case .specificWeekdays(let days):
            return days.contains(weekday)
        case .timesPerWeek:
            // "每周 N 次"没有固定日期，只要本周还没完成够 N 次，今天就算 due
            return timesCompletedThisWeek(referenceDate: date) < timesPerWeekTarget
        }
    }

    private var timesPerWeekTarget: Int {
        if case .timesPerWeek(let n) = rule { return n }
        return Int.max
    }

    private func timesCompletedThisWeek(referenceDate: Date) -> Int {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: referenceDate) else { return 0 }
        return completedDates
            .compactMap(Self.dayFormatter.date(from:))
            .filter { weekInterval.contains($0) }
            .count
    }

    func isCompleted(on date: Date) -> Bool {
        completedDates.contains(Self.dayFormatter.string(from: date))
    }

    func toggleCompletion(on date: Date) {
        var dates = completedDates
        let key = Self.dayFormatter.string(from: date)
        if dates.contains(key) {
            dates.remove(key)
        } else {
            dates.insert(key)
        }
        completedDates = dates
    }
}
