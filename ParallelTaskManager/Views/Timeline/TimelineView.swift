import SwiftUI
import SwiftData

struct TimelineView: View {
    private struct EventEditorTarget: Identifiable {
        let id: UUID
        let date: Date
        let project: Project
        let event: Event?
    }

    @Query(sort: \Project.order) private var projects: [Project]
    @Query(sort: \Event.date) private var allEvents: [Event]

    @State private var editorTarget: EventEditorTarget?

    private let projectLabelWidth: CGFloat = 150
    private let daySpacing: CGFloat = 112
    private let axisHeight: CGFloat = 72
    private let minimumLaneHeight: CGFloat = 88
    private let eventLabelWidth: CGFloat = 118

    private var windowStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var days: [Date] {
        (0...14).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: windowStart)
        }
    }

    private var chartWidth: CGFloat {
        max(900, CGFloat(max(days.count - 1, 1)) * daySpacing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            Divider()

            if projects.isEmpty {
                emptyState
            } else {
                timeline
            }
        }
        .background(.clear)
        .sheet(item: $editorTarget) { target in
            AddEventSheet(project: target.project, defaultDate: target.date, event: target.event)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 12) {
            Text("Timeline")
                .font(.title2.weight(.semibold))

            Text("Next 15 Days")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var timeline: some View {
        GeometryReader { geometry in
            let scrollViewHeight = max(
                geometry.size.height - AppLayout.pageScrollBottomInset,
                0
            )
            let availableHeight = max(scrollViewHeight - axisHeight, 0)
            let laneHeight = max(
                minimumLaneHeight,
                availableHeight / CGFloat(max(projects.count, 1))
            )

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    timeAxis

                    ForEach(projects, id: \.persistentModelID) { project in
                        projectLane(project, laneHeight: laneHeight)
                    }
                }
                .padding(.bottom, 24)
            }
            .frame(height: scrollViewHeight)
        }
    }

    private var timeAxis: some View {
        HStack(spacing: 0) {
            Text("PROJECTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: projectLabelWidth, height: axisHeight, alignment: .leading)
                .padding(.leading, 20)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: chartWidth, height: 1)
                    .offset(y: 54)

                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let x = xPosition(forDayIndex: index)
                    let isToday = Calendar.current.isDateInToday(day)

                    VStack(spacing: 2) {
                        Text(weekdayLabel(for: day))
                            .font(.caption2.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)
                            .lineLimit(1)

                        Text(dayMonthLabel(for: day))
                            .font(.caption.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)
                            .lineLimit(1)

                        Rectangle()
                            .fill(isToday ? Color.accentColor : Color.secondary.opacity(0.45))
                            .frame(width: 1, height: 9)
                    }
                    .frame(width: 100)
                    .position(x: clampedLabelPosition(x), y: 28)
                }
            }
            .frame(width: chartWidth, height: axisHeight)
        }
        .frame(height: axisHeight)
    }

    private func projectLane(_ project: Project, laneHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(project.color)
                    .frame(width: 9, height: 9)

                Text(project.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .frame(width: projectLabelWidth, height: laneHeight, alignment: .leading)
            .padding(.leading, 20)

            ZStack(alignment: .topLeading) {
                // This is the clickable area, not a visible table cell.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                addEvent(for: project, at: date(forX: value.location.x))
                            }
                    )

                Rectangle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: chartWidth, height: 1)
                    .offset(y: laneHeight * 0.62)
                    .allowsHitTesting(false)

                ForEach(Array(events(for: project).enumerated()), id: \.element.persistentModelID) { index, event in
                    eventMarker(event, project: project, index: index, laneHeight: laneHeight)
                }
            }
            .frame(width: chartWidth, height: laneHeight)
        }
        .frame(height: laneHeight)
    }

    private func eventMarker(_ event: Event, project: Project, index: Int, laneHeight: CGFloat) -> some View {
        let dayIndex = days.firstIndex {
            Calendar.current.isDate($0, inSameDayAs: event.date)
        } ?? 0
        let x = xPosition(forDayIndex: dayIndex)
        let sameDayEvents = events(for: project).filter {
            Calendar.current.isDate($0.date, inSameDayAs: event.date)
        }
        let indexInDay = sameDayEvents.firstIndex {
            $0.persistentModelID == event.persistentModelID
        } ?? index
        // 事件从横线的上方开始垂直排列，避免文字/圆点被横线穿过。
        let y = laneHeight * 0.62 - 16 - CGFloat(indexInDay) * 23

        return ZStack(alignment: .leading) {
            Button {
                editEvent(event, project: project)
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(project.color)
                        .frame(width: 8, height: 8)

                    Text(event.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.plain)

            if event.completed {
                Text("✅")
                    .font(.caption)
                    .offset(x: -20)
                    .allowsHitTesting(false)
            }
        }
        // 外层宽度只负责把小圆点的左边缘锁在日期 x 上；
        // 真正的 Button 仍然只有圆点和文字那么大，不会扩大添加区域。
        .frame(width: eventLabelWidth, height: 20, alignment: .leading)
        .position(x: eventMarkerCenter(for: x), y: y)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("先在 Projects 中创建一个项目")
                .font(.headline)
            Text("创建项目后，点击时间线上的位置即可添加 Event。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func events(for project: Project) -> [Event] {
        allEvents
            .filter {
                $0.project?.persistentModelID == project.persistentModelID &&
                $0.date >= windowStart &&
                $0.date <= days.last!
            }
            .sorted { $0.date < $1.date }
    }

    private func addEvent(for project: Project, at date: Date) {
        editorTarget = EventEditorTarget(
            id: UUID(),
            date: date,
            project: project,
            event: nil
        )
    }

    private func editEvent(_ event: Event, project: Project) {
        editorTarget = EventEditorTarget(
            id: event.id,
            date: event.date,
            project: project,
            event: event
        )
    }

    private func date(forX x: CGFloat) -> Date {
        let ratio = min(max(x / chartWidth, 0), 1)
        let index = Int((ratio * CGFloat(days.count - 1)).rounded())
        return days[min(max(index, 0), days.count - 1)]
    }

    private func xPosition(forDayIndex index: Int) -> CGFloat {
        guard days.count > 1 else { return 0 }
        return CGFloat(index) * chartWidth / CGFloat(days.count - 1)
    }

    private func clampedLabelPosition(_ x: CGFloat) -> CGFloat {
        min(max(x, 40), chartWidth - 40)
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func dayMonthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func eventMarkerCenter(for x: CGFloat) -> CGFloat {
        let leading = min(max(x, 0), chartWidth - eventLabelWidth)
        return leading + eventLabelWidth / 2
    }

}

#Preview {
    TimelineView()
        .modelContainer(for: [Project.self, TaskItem.self, Event.self, RecurringTask.self, ProjectContext.self], inMemory: true)
}
