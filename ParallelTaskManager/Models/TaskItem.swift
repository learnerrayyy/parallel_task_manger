import Foundation
import SwiftData

/// 文档 §8：Task / Subtask / Sub-subtask 全部用同一个 Task 类型，
/// 通过 parentTaskId（这里用真实的 parentTask relationship）实现任意层级。
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var completed: Bool
    var createdAt: Date
    var completedAt: Date?
    var order: Int

    /// UI 展开/折叠状态（文档 §9 Collapse / Expand）
    var isExpanded: Bool = true

    var project: Project?

    var parentTask: TaskItem?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parentTask)
    var children: [TaskItem] = []

    init(title: String, project: Project?, parentTask: TaskItem? = nil, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.completed = false
        self.createdAt = Date()
        self.order = order
        self.project = project
        self.parentTask = parentTask
    }

    var sortedChildren: [TaskItem] {
        children.sorted {
            if $0.completed != $1.completed {
                return !$0.completed && $1.completed
            }
            return $0.order < $1.order
        }
    }

    var activeChildren: [TaskItem] {
        sortedChildren.filter { !$0.completed }
    }

    /// 从根节点到当前 Task 的路径，用于 Current 区域显示面包屑（文档 §5 示例）
    var pathFromRoot: [TaskItem] {
        var path: [TaskItem] = [self]
        var cursor = parentTask
        while let p = cursor {
            path.insert(p, at: 0)
            cursor = p.parentTask
        }
        return path
    }

    func markCompleted(_ done: Bool) {
        completed = done
        completedAt = done ? Date() : nil
    }
}
