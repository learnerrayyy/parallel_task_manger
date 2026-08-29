import SwiftUI
import SwiftData
import WidgetKit

struct CurrentTaskView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if let current = project.currentTask {
                VStack(alignment: .leading, spacing: 4) {
                    // 面包屑：Task └ Subtask └ Sub-subtask
                    let path = current.pathFromRoot
                    if path.count > 1 {
                        Text(path.dropLast().map(\.title).joined(separator: " › "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(current.title)
                        .font(.body.weight(.medium))
                        .strikethrough(current.completed)

                    HStack(spacing: 12) {
                        Button {
                            toggleComplete(current)
                        } label: {
                            Label(current.completed ? "Reopen" : "Mark Complete",
                                  systemImage: current.completed ? "arrow.uturn.backward" : "checkmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        Button("Clear") {
                            project.currentTaskId = nil
                            try? context.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(project.color.opacity(0.12)))
            } else {
                Text("从下方 Task Tree 中选一个作为 Current")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
            }
        }
    }

    private func toggleComplete(_ task: TaskItem) {
        task.markCompleted(!task.completed)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
