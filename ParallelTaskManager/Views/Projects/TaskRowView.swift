import SwiftUI
import SwiftData
import WidgetKit

struct TaskRowView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    @Bindable var task: TaskItem
    let depth: Int

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isAddingChild = false
    @State private var newChildTitle = ""

    private var isCurrent: Bool { project.currentTaskId == task.id }

    private var linkedEvent: Event? {
        project.events.first { $0.linkedTaskId == task.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row

            if isAddingChild {
                HStack {
                    TextField("Subtask", text: $newChildTitle, onCommit: addChild)
                        .textFieldStyle(.roundedBorder)
                    Button("Add", action: addChild)
                        .disabled(newChildTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, indent + 20)
            }

            if task.isExpanded && !task.activeChildren.isEmpty {
                TaskTreeView(project: project, tasks: task.activeChildren, depth: depth + 1)
            }
        }
    }

    private var indent: CGFloat { CGFloat(depth) * 18 }

    private var row: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: indent, height: 1)

            Button {
                task.markCompleted(!task.completed)
                linkedEvent?.completed = task.completed
                linkedEvent?.completedAt = task.completedAt
                try? context.save()
                WidgetCenter.shared.reloadAllTimelines()
            } label: {
                Image(systemName: task.completed ? "checkmark.square.fill" : "square")
                    .foregroundStyle(task.completed ? project.color : .secondary)
            }
            .buttonStyle(.borderless)

            taskTitle

            if isCurrent {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(project.color.opacity(0.2)))
                    .foregroundStyle(project.color)
            }

            if !task.activeChildren.isEmpty {
                Button {
                    task.isExpanded.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: task.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 20, height: 20)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }

            Spacer(minLength: 4)

            Menu {
                Button("Set as Current") { setAsCurrent() }
                Button("Add Subtask") { startAddingChild() }
                Button("Rename") { editedTitle = task.title; isEditingTitle = true }
                Divider()
                Button("Delete", role: .destructive) { deleteTask() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24, height: 22)
            .opacity(0.7)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("Set as Current") { setAsCurrent() }
            Button("Add Subtask") { startAddingChild() }
            Button("Rename") { editedTitle = task.title; isEditingTitle = true }
            Divider()
            Button("Delete", role: .destructive) { deleteTask() }
        }
    }

    @ViewBuilder
    private var taskTitle: some View {
        if isEditingTitle {
            TextField("Title", text: $editedTitle, onCommit: commitTitleEdit)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        } else {
            Text(task.title)
                .font(.callout)
                .strikethrough(task.completed)
                .foregroundStyle(task.completed ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) {
                    editedTitle = task.title
                    isEditingTitle = true
                }
        }
    }

    private func setAsCurrent() {
        project.currentTaskId = task.id
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func commitTitleEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            task.title = trimmed
            linkedEvent?.title = trimmed
        }
        isEditingTitle = false
        try? context.save()
    }

    private func addChild() {
        let trimmed = newChildTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let child = TaskItem(title: trimmed, project: project, parentTask: task, order: task.children.count)
        context.insert(child)
        task.isExpanded = true
        try? context.save()
        newChildTitle = ""
        isAddingChild = false
    }

    private func startAddingChild() {
        newChildTitle = ""
        isAddingChild = true
    }

    private func deleteTask() {
        if isCurrent { project.currentTaskId = nil }
        if let linkedEvent {
            context.delete(linkedEvent)
        }
        context.delete(task)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
