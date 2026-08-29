import SwiftUI
import SwiftData

/// 递归渲染任意层级的 Task Tree。
/// UI 第一版建议控制在 3-4 层以维持可读性（文档 §8），但数据结构本身不限制层级。
struct TaskTreeView: View {
    let project: Project
    let tasks: [TaskItem]
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(tasks, id: \.persistentModelID) { task in
                TaskRowView(project: project, task: task, depth: depth)
            }
        }
    }
}
