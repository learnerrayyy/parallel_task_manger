import SwiftUI
import SwiftData
import WidgetKit

struct AddEventSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let defaultDate: Date
    let existingEvent: Event?

    @State private var title = ""
    @State private var type: EventType = .deadline
    @State private var completed = false

    init(project: Project, defaultDate: Date, event: Event? = nil) {
        self.project = project
        self.defaultDate = defaultDate
        self.existingEvent = event
        _title = State(initialValue: event?.title ?? "")
        _type = State(initialValue: event?.type ?? .deadline)
        _completed = State(initialValue: event?.completed ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existingEvent == nil ? "Add Event" : "Edit Event")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Circle()
                    .fill(project.color)
                    .frame(width: 9, height: 9)
                Text(project.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Picker("Type", selection: $type) {
                ForEach(EventType.allCases) { t in
                    Text(t.displayName).tag(t)
                }
            }

            if existingEvent != nil {
                Toggle(isOn: $completed) {
                    Label("Completed", systemImage: "checkmark.circle")
                }
            }

            HStack {
                if existingEvent != nil {
                    Button("Delete", role: .destructive) {
                        deleteEvent()
                    }
                }

                Spacer()
                Button("Cancel") { dismiss() }
                Button(existingEvent == nil ? "Add" : "Save") { saveEvent() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func saveEvent() {
        if let existingEvent {
            existingEvent.title = title
            existingEvent.type = type
            existingEvent.completed = completed
            existingEvent.completedAt = completed ? (existingEvent.completedAt ?? Date()) : nil

            // Timeline Event 对应一个普通 Task；编辑 Event 时同步更新它。
            if let linkedTask = linkedTask(for: existingEvent) {
                linkedTask.title = title
                linkedTask.markCompleted(completed)
                existingEvent.completedAt = linkedTask.completedAt
            } else {
                // 兼容旧版本已经存在、但还没有关联 Task 的 Event。
                let task = TaskItem(title: title, project: project, order: project.rootTasks.count)
                task.markCompleted(completed)
                context.insert(task)
                existingEvent.linkedTaskId = task.id
            }
        } else {
            let event = Event(title: title, date: defaultDate, type: type, project: project)
            let task = TaskItem(title: title, project: project, order: project.rootTasks.count)
            context.insert(event)
            context.insert(task)
            event.linkedTaskId = task.id
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }

    private func deleteEvent() {
        guard let existingEvent else { return }
        if let linkedTask = linkedTask(for: existingEvent) {
            context.delete(linkedTask)
        }
        context.delete(existingEvent)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }

    private func linkedTask(for event: Event) -> TaskItem? {
        guard let taskID = event.linkedTaskId else { return nil }
        return project.tasks.first { $0.id == taskID }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: defaultDate)
    }
}
