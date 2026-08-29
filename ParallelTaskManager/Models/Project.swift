import Foundation
import SwiftData
import SwiftUI

enum ProjectColorOption: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case purple
    case red
    case cyan
    case yellow

    var id: String { rawValue }

    var name: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .red: return "Red"
        case .cyan: return "Cyan"
        case .yellow: return "Yellow"
        }
    }

    var hex: String {
        switch self {
        case .blue: return "#4A90D9"
        case .green: return "#3AB795"
        case .orange: return "#E0855C"
        case .purple: return "#9B72CF"
        case .red: return "#D9534F"
        case .cyan: return "#5BC0DE"
        case .yellow: return "#D6A928"
        }
    }

    var color: Color { Color(hex: hex) }
}

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var order: Int
    var colorHex: String

    /// 当前设置为 Current 的 Task id（对应文档 §18: Project.currentTaskId）
    var currentTaskId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.project)
    var tasks: [TaskItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Event.project)
    var events: [Event] = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringTask.project)
    var recurringTasks: [RecurringTask] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectContext.project)
    var context: ProjectContext?

    init(name: String, order: Int, colorHex: String = "#4A90D9") {
        self.id = UUID()
        self.name = name
        self.order = order
        self.colorHex = colorHex
    }

    /// 顶层 Task（parentTask 为 nil），按 order 排序
    var rootTasks: [TaskItem] {
        tasks
            .filter { $0.parentTask == nil && !$0.completed }
            .sorted {
                if $0.completed != $1.completed {
                    return !$0.completed && $1.completed
                }
                return $0.order < $1.order
            }
    }

    var completedTasks: [TaskItem] {
        tasks
            .filter { $0.completed }
            .sorted {
                ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt)
            }
    }

    /// 当前 Current Task 对象
    var currentTask: TaskItem? {
        guard let id = currentTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    /// 当天应该显示的 Daily / Recurring Task（文档 §6：为空则不展示 Daily 区域）
    func recurringTasks(dueOn date: Date) -> [RecurringTask] {
        recurringTasks
            .filter { $0.isDue(on: date) }
            .sorted { $0.order < $1.order }
    }
}
