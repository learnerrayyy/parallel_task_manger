import SwiftUI
import SwiftData

struct ContextSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Project

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("CONTEXT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let ctx = ensuredContext() {
                VStack(alignment: .leading, spacing: 8) {
                    field("Current state", text: bindingFor(ctx, \.currentState))
                    field("Problem", text: bindingFor(ctx, \.problem))
                    field("Next step", text: bindingFor(ctx, \.nextStep))
                    field("Resources", text: bindingFor(ctx, \.resources))
                }
            } else if !isExpanded, let ctx = project.context, !ctx.isEmpty {
                Text(ctx.nextStep.isEmpty ? ctx.currentState : ctx.nextStep)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.caption)
                .frame(height: 40)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
        }
    }

    private func ensuredContext() -> ProjectContext? {
        if let ctx = project.context { return ctx }
        let ctx = ProjectContext(project: project)
        context.insert(ctx)
        try? context.save()
        return ctx
    }

    private func bindingFor(_ ctx: ProjectContext, _ keyPath: ReferenceWritableKeyPath<ProjectContext, String>) -> Binding<String> {
        Binding(
            get: { ctx[keyPath: keyPath] },
            set: { newValue in
                ctx[keyPath: keyPath] = newValue
                ctx.updatedAt = Date()
                try? context.save()
            }
        )
    }
}
