import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.order) private var projects: [Project]

    @State private var showingAddProject = false
    @State private var newProjectName = ""
    @State private var newProjectColorHex = "#4A90D9"

    var body: some View {
        GeometryReader { geometry in
            let minimumColumnWidth: CGFloat = 300
            let equalColumnWidth = max(
                minimumColumnWidth,
                geometry.size.width / CGFloat(max(projects.count, 1))
            )
            let scrollViewHeight = max(
                geometry.size.height - AppLayout.pageScrollBottomInset,
                0
            )

            ZStack {
                if projects.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("右键此处新建 Project")
                            .font(.headline)
                        Text("删除所有 Project 后，这里仍然可以添加新的 Project。")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(projects, id: \.persistentModelID) { project in
                                ProjectColumnView(project: project, onNewProject: {
                                    showingAddProject = true
                                })
                                .frame(width: equalColumnWidth, height: scrollViewHeight)
                                Divider()
                                    .frame(height: scrollViewHeight)
                            }
                        }
                        .frame(minHeight: scrollViewHeight, alignment: .top)
                    }
                    .frame(height: scrollViewHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
                Button("New Project") {
                    showingAddProject = true
                }
            }
            .popover(isPresented: $showingAddProject) {
                newProjectPopover
            }
        }
        .background(.clear)
    }

    private var newProjectPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Project").font(.headline)
            TextField("Name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            ColorPaletteGrid(
                title: "Project Color",
                selectedHex: newProjectColorHex
            ) { hex in
                newProjectColorHex = hex
            }
            HStack {
                Spacer()
                Button("Cancel") { showingAddProject = false }
                Button("Create") { createProject() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    private func createProject() {
        let palette = ["#4A90D9", "#3AB795", "#E0855C", "#9B72CF", "#D9534F", "#5BC0DE"]
        let project = Project(
            name: newProjectName,
            order: projects.count,
            colorHex: newProjectColorHex.isEmpty
                ? palette[projects.count % palette.count]
                : newProjectColorHex
        )
        context.insert(project)
        context.insert(ProjectContext(project: project))
        try? context.save()
        newProjectName = ""
        newProjectColorHex = "#4A90D9"
        showingAddProject = false
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: [Project.self, TaskItem.self, Event.self, RecurringTask.self, ProjectContext.self], inMemory: true)
}
