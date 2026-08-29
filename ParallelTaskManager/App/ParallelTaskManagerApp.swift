import SwiftUI
import SwiftData
import WidgetKit
import AppKit

private struct WindowAspectRatio: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        AspectRatioView()
    }

    func updateNSView(_ nsView: NSView, context: Context) { }

    private final class AspectRatioView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            guard let window else { return }
            window.aspectRatio = NSSize(width: 1200, height: 760)
            window.minSize = NSSize(width: 980, height: 640)
        }
    }
}

@main
struct ParallelTaskManagerApp: App {
    let container: ModelContainer = SharedModelContainer.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 640)
                .background(WindowAspectRatio())
                .task {
                    seedDefaultProjectsIfNeeded()
                    migrateTimelineEventsToTasks()
                }
        }
        .defaultSize(width: 1200, height: 760)
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }

    /// 首次启动时按文档创建 Dissertation / OceanX / Job Search 三个默认 Project。
    /// 用户之后可以在 UI 里自由增删（文档 §1: 系统架构需要允许未来增加、删除和修改 Project）。
    @MainActor
    private func seedDefaultProjectsIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Project>()
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }

        let defaults: [(String, String)] = [
            ("Dissertation", "#4A90D9"),
            ("OceanX", "#3AB795"),
            ("Job Search", "#E0855C")
        ]

        for (index, def) in defaults.enumerated() {
            let project = Project(name: def.0, order: index, colorHex: def.1)
            context.insert(project)
            context.insert(ProjectContext(project: project))
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 将旧版本已经存在、但还没有关联普通 Task 的 Timeline Event 补成 Task。
    /// 新建普通 Task 不会反向创建 Event。
    @MainActor
    private func migrateTimelineEventsToTasks() {
        let context = container.mainContext
        guard let events = try? context.fetch(FetchDescriptor<Event>()) else { return }
        var didChange = false

        for event in events where event.linkedTaskId == nil {
            guard let project = event.project else { continue }
            let task = TaskItem(title: event.title, project: project, order: project.rootTasks.count)
            task.markCompleted(event.completed)
            context.insert(task)
            event.linkedTaskId = task.id
            didChange = true
        }

        if didChange {
            try? context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
