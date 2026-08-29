import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct ParallelEntry: TimelineEntry {
    let date: Date
    let upcomingEvents: [UpcomingEventSnapshot]
    let currentTasks: [CurrentTaskSnapshot]
}

struct UpcomingEventSnapshot: Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let colorHex: String
}

struct CurrentTaskSnapshot: Identifiable {
    let id: UUID
    let projectName: String
    let colorHex: String
    let taskTitle: String?
}

// MARK: - Provider

@MainActor
struct ParallelProvider: TimelineProvider {

    func placeholder(in context: Context) -> ParallelEntry {
        ParallelEntry(date: Date(), upcomingEvents: [], currentTasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ParallelEntry) -> Void) {
        completion(placeholder(in: context))
    }

    @MainActor
    func getTimeline(in context: Context, completion: @escaping (Timeline<ParallelEntry>) -> Void) {
        let entry = fetchEntry()
        // 数据只在用户操作 App 后变化，App 端会主动调用 WidgetCenter.reloadAllTimelines()，
        // 这里再设置一个保守的每小时兜底刷新。
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    @MainActor
    private func fetchEntry() -> ParallelEntry {
        let container = SharedModelContainer.makeContainer()
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let windowEnd = Calendar.current.date(byAdding: .day, value: 14, to: today)!

        let eventDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.date >= today && $0.date <= windowEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        let events = (try? context.fetch(eventDescriptor)) ?? []
        let upcoming = events.prefix(3).map {
            UpcomingEventSnapshot(id: $0.id, title: $0.title, date: $0.date, colorHex: $0.project?.colorHex ?? "#888888")
        }

        let projectDescriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.order)])
        let projects = (try? context.fetch(projectDescriptor)) ?? []
        let currents = projects.map {
            CurrentTaskSnapshot(id: $0.id, projectName: $0.name, colorHex: $0.colorHex, taskTitle: $0.currentTask?.title)
        }

        return ParallelEntry(date: Date(), upcomingEvents: Array(upcoming), currentTasks: currents)
    }
}

// MARK: - Widget View

struct ParallelTaskWidgetEntryView: View {
    var entry: ParallelEntry

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !entry.upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UPCOMING")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    ForEach(entry.upcomingEvents) { event in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: event.colorHex)).frame(width: 6, height: 6)
                            Text(dateFormatter.string(from: event.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(event.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                ForEach(entry.currentTasks) { snapshot in
                    HStack(alignment: .top, spacing: 6) {
                        Circle().fill(Color(hex: snapshot.colorHex)).frame(width: 6, height: 6).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(snapshot.projectName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(snapshot.taskTitle ?? "—")
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .widgetURL(URL(string: "paralleltaskmanager://open"))
    }
}

// MARK: - Widget Bundle Entry Point

struct ParallelTaskWidget: Widget {
    let kind: String = "ParallelTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParallelProvider()) { entry in
            ParallelTaskWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Parallel")
        .description("Upcoming events and Current Task for each project.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#if XCODE_CANVAS_PREVIEWS
#Preview(as: .systemMedium) {
    ParallelTaskWidget()
} timeline: {
    ParallelEntry(date: .now, upcomingEvents: [], currentTasks: [])
}
#endif
