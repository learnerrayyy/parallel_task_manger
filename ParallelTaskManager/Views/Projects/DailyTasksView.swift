import SwiftUI
import SwiftData
import WidgetKit

private enum RecurrenceChoice: String, CaseIterable, Identifiable {
    case everyDay
    case weekdays
    case everyNDays

    var id: String { rawValue }
}

struct DailyTasksView: View {
    @Environment(\.modelContext) private var context
    let project: Project
    let dueTasks: [RecurringTask]

    @Binding var showingAddRecurring: Bool
    @State private var newTitle = ""
    @State private var recurrenceChoice: RecurrenceChoice = .everyDay
    @State private var everyNDaysText = "2"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DAILY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
            }

            if dueTasks.isEmpty {
                Text("No recurring tasks today")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dueTasks, id: \.persistentModelID) { rt in
                    HStack {
                        Button {
                            rt.toggleCompletion(on: Date())
                            try? context.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Image(systemName: rt.isCompleted(on: Date()) ? "checkmark.square.fill" : "square")
                        }
                        .buttonStyle(.borderless)

                        Text(rt.title)
                            .strikethrough(rt.isCompleted(on: Date()))
                        Spacer()
                    }
                }
            }
        }
        .popover(isPresented: $showingAddRecurring) {
            addRecurringForm
        }
    }

    private var addRecurringForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Recurring Task").font(.headline)
            TextField("Title", text: $newTitle)
                .textFieldStyle(.roundedBorder)

            Picker("Repeats", selection: $recurrenceChoice) {
                Text("Every day").tag(RecurrenceChoice.everyDay)
                Text("Weekdays").tag(RecurrenceChoice.weekdays)
                Text("Every N days").tag(RecurrenceChoice.everyNDays)
            }
            .pickerStyle(.radioGroup)

            if recurrenceChoice == .everyNDays {
                HStack {
                    Text("Every")
                    TextField("N", text: $everyNDaysText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 52)
                    Text("days")
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { showingAddRecurring = false }
                Button("Add") { addRecurring() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func addRecurring() {
        let rule: RecurrenceRule
        switch recurrenceChoice {
        case .everyDay:
            rule = .everyDay
        case .weekdays:
            rule = .weekdays
        case .everyNDays:
            rule = .everyNDays(max(Int(everyNDaysText) ?? 1, 1))
        }

        let rt = RecurringTask(title: newTitle, rule: rule, project: project, order: project.recurringTasks.count)
        context.insert(rt)
        try? context.save()
        newTitle = ""
        recurrenceChoice = .everyDay
        everyNDaysText = "2"
        showingAddRecurring = false
        WidgetCenter.shared.reloadAllTimelines()
    }
}
