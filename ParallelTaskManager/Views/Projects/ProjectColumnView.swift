import SwiftUI
import SwiftData

struct ProjectColumnView: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project
    let onNewProject: () -> Void

    @State private var showingAddRootTask = false
    @State private var newRootTaskTitle = ""
    @State private var showingAddRecurring = false
    @State private var showingContext = false
    @State private var showingProjectPalette = false
    @State private var showingRenameProject = false
    @State private var editedProjectName = ""
    @State private var showingDeleteConfirm = false
    @State private var showingCompleted = false
    @State private var showingEvents = false
    @FocusState private var focusedField: InputField?

    private enum InputField {
        case rootTask
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView(.vertical) {
                mainContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            .layoutPriority(1)

            completedAccordion
            eventAccordion
        }
        .frame(minWidth: 300, maxHeight: .infinity, alignment: .top)
        .contextMenu {
            Button("Add Task") {
                startAddingRootTask()
            }

            Button("Add Daily Task") {
                showingAddRecurring = true
            }

            Button("Add Context") {
                showingContext = true
                ensureContext()
            }

            Divider()

            Button("New Project") {
                onNewProject()
            }

            Button("Delete Project", role: .destructive) {
                showingDeleteConfirm = true
            }
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            taskTreeSection

            if project.currentTask != nil {
                CurrentTaskView(project: project)
            }

            if !project.recurringTasks.isEmpty || showingAddRecurring {
                let dueToday = project.recurringTasks(dueOn: Date())
                DailyTasksView(
                    project: project,
                    dueTasks: dueToday,
                    showingAddRecurring: $showingAddRecurring
                )
            }

            if showingContext || (project.context != nil && !(project.context?.isEmpty ?? true)) {
                ContextSection(project: project)
            }
        }
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(project.color)
                .frame(width: 8, height: 8)
            Text(project.name.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(0.5)
            Spacer()
            Menu {
                Button("Rename Project") {
                    editedProjectName = project.name
                    showingRenameProject = true
                }

                Button("Choose Project Color…") {
                    showingProjectPalette = true
                }

                Divider()

                Button("Delete Project", role: .destructive) {
                    showingDeleteConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20)
        }
        .popover(isPresented: $showingProjectPalette) {
            ColorPaletteGrid(title: "Project Color", selectedHex: project.colorHex) { hex in
                project.colorHex = hex
                try? context.save()
                showingProjectPalette = false
            }
        }
        .popover(isPresented: $showingRenameProject) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rename Project")
                    .font(.headline)

                TextField("Project name", text: $editedProjectName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingRenameProject = false
                    }
                    Button("Save") {
                        renameProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 280)
        }
        .confirmationDialog(
            "删除 \"\(project.name)\" 及其所有 Task / Event？",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                context.delete(project)
                try? context.save()
            }
        }
    }

    private var taskTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
            }

            if showingAddRootTask {
                HStack {
                    TextField("New task", text: $newRootTaskTitle, onCommit: addRootTask)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .rootTask)
                        .task { focusedField = .rootTask }
                    Button("Add", action: addRootTask)
                        .disabled(newRootTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if project.rootTasks.isEmpty {
                Text("No tasks yet — right-click to add options")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                TaskTreeView(project: project, tasks: project.rootTasks, depth: 0)
            }
        }
    }

    private var completedAccordion: some View {
        let completedEvents = project.events
            .filter { $0.completed && $0.linkedTaskId == nil }
            .sorted { ($0.completedAt ?? $0.date) > ($1.completedAt ?? $1.date) }
        let count = project.completedTasks.count + completedEvents.count

        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader("COMPLETED : \(count)", isExpanded: showingCompleted) {
                showingCompleted.toggle()
            }

            if showingCompleted {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(project.completedTasks, id: \.persistentModelID) { task in
                        archivedTaskRow(task)
                    }

                    ForEach(completedEvents, id: \.persistentModelID) { event in
                        archivedEventRow(event)
                    }
                }
            }
        }
    }

    private var eventAccordion: some View {
        let events = project.events
            .filter { !$0.completed }
            .sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader("EVENT : \(events.count)", isExpanded: showingEvents) {
                showingEvents.toggle()
            }

            if showingEvents {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events, id: \.persistentModelID) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private func sectionHeader(
        _ title: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 14)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func archivedTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(project.color)
            Text(formatArchiveDate(task.completedAt ?? task.createdAt))
                .foregroundStyle(.secondary)
            Text("-")
                .foregroundStyle(.secondary)
            Text(task.title)
                .strikethrough()
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.leading, 20)
    }

    private func archivedEventRow(_ event: Event) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(project.color)
            Text(formatArchiveDate(event.completedAt ?? event.date))
                .foregroundStyle(.secondary)
            Text("-")
                .foregroundStyle(.secondary)
            Text(event.title)
                .strikethrough()
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.leading, 20)
    }

    private func eventRow(_ event: Event) -> some View {
        HStack(spacing: 7) {
            Button {
                event.completed = true
                event.completedAt = Date()
                if let taskID = event.linkedTaskId,
                   let task = project.tasks.first(where: { $0.id == taskID }) {
                    task.markCompleted(true)
                }
                try? context.save()
            } label: {
                Image(systemName: "square")
            }
            .buttonStyle(.borderless)

            Text(formatEventDate(event.date))
                .foregroundStyle(.secondary)
            Text("-")
                .foregroundStyle(.secondary)
            Text(event.type.displayName)
                .foregroundStyle(project.color)
            Text("-")
                .foregroundStyle(.secondary)
            Text(event.title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.leading, 20)
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func formatArchiveDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func addRootTask() {
        let trimmed = newRootTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let task = TaskItem(title: trimmed, project: project, order: project.rootTasks.count)
        context.insert(task)
        try? context.save()
        newRootTaskTitle = ""
        showingAddRootTask = false
    }

    private func startAddingRootTask() {
        newRootTaskTitle = ""
        showingAddRootTask = true
        DispatchQueue.main.async {
            focusedField = .rootTask
        }
    }

    private func ensureContext() {
        if project.context == nil {
            context.insert(ProjectContext(project: project))
            try? context.save()
        }
    }

    private func renameProject() {
        let trimmed = editedProjectName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        project.name = trimmed
        try? context.save()
        showingRenameProject = false
    }
}
