import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum AppPage: String, CaseIterable, Identifiable {
    case timeline = "Timeline"
    case projects = "Projects"
    var id: String { rawValue }
}

enum AppLayout {
    // Both pages reserve the same space below their horizontal scroll views.
    static let pageScrollBottomInset: CGFloat = 10
}

enum AppBackgroundStyle: String, CaseIterable, Identifiable {
    case system
    case cloud
    case sand
    case sky
    case sage
    case blush

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return "System"
        case .cloud: return "Cloud"
        case .sand: return "Sand"
        case .sky: return "Sky"
        case .sage: return "Sage"
        case .blush: return "Blush"
        }
    }

    var color: Color {
        switch self {
        case .system: return Color(nsColor: .windowBackgroundColor)
        case .cloud: return Color(hex: "#F7F8FA")
        case .sand: return Color(hex: "#F8F3EA")
        case .sky: return Color(hex: "#EEF5FA")
        case .sage: return Color(hex: "#EFF6F1")
        case .blush: return Color(hex: "#FBF0F0")
        }
    }
}

struct PaletteColor: Identifiable {
    let id: String
    let hex: String

    var color: Color { Color(hex: hex) }
}

enum AppColorPalette {
    // 8 rows × 8 columns：柔和浅色到饱和深色，项目颜色和背景颜色共用。
    static let colors: [PaletteColor] = [
        "#FFF1F2", "#FFE4E6", "#FDA4AF", "#FB7185", "#F43F5E", "#E11D48", "#BE123C", "#881337",
        "#FFF7ED", "#FFEDD5", "#FDBA74", "#FB923C", "#F97316", "#EA580C", "#C2410C", "#9A3412",
        "#FEFCE8", "#FEF08A", "#FDE047", "#FACC15", "#EAB308", "#CA8A04", "#A16207", "#713F12",
        "#F0FDF4", "#DCFCE7", "#86EFAC", "#4ADE80", "#22C55E", "#16A34A", "#15803D", "#166534",
        "#ECFEFF", "#CFFAFE", "#67E8F9", "#22D3EE", "#06B6D4", "#0891B2", "#0E7490", "#155E75",
        "#EFF6FF", "#DBEAFE", "#93C5FD", "#60A5FA", "#3B82F6", "#2563EB", "#1D4ED8", "#1E3A8A",
        "#FAF5FF", "#F3E8FF", "#D8B4FE", "#C084FC", "#A855F7", "#9333EA", "#7E22CE", "#581C87",
        "#F8FAFC", "#E2E8F0", "#CBD5E1", "#94A3B8", "#64748B", "#475569", "#334155", "#0F172A"
    ].map { PaletteColor(id: $0, hex: $0) }
}

struct ColorPaletteGrid: View {
    let title: String
    let selectedHex: String?
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.fixed(24), spacing: 6), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(AppColorPalette.colors) { paletteColor in
                    Button {
                        onSelect(paletteColor.hex)
                    } label: {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(paletteColor.color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(
                                        selectedHex == paletteColor.hex ? Color.primary : .clear,
                                        lineWidth: 2
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

struct ContentView: View {
    @State private var page: AppPage = .projects
    @AppStorage("app.backgroundStyle") private var backgroundStyleRaw = AppBackgroundStyle.system.rawValue
    @AppStorage("app.backgroundColorHex") private var backgroundColorHex = "#F7F8FA"
    @AppStorage("app.backgroundImagePath") private var backgroundImagePath = ""

    @State private var showingBackgroundPalette = false

    private var backgroundColor: Color {
        if backgroundStyleRaw == "custom" {
            return Color(hex: backgroundColorHex)
        }
        return (AppBackgroundStyle(rawValue: backgroundStyleRaw) ?? .system).color
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Group {
                    switch page {
                    case .timeline:
                        TimelineView()
                    case .projects:
                        ProjectsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                header
            }
        }
    }

    private var backgroundLayer: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor

                if !backgroundImagePath.isEmpty,
                   let image = NSImage(contentsOfFile: backgroundImagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.10)

                    Color.white.opacity(0.02)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        ZStack {
            Text("Parallel")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                pageButton(.timeline, shortcut: "⌘1")
                pageButton(.projects, shortcut: "⌘2")
            }
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: 220, height: 26)

            HStack {
                Spacer()

                Menu {
                    Text("Background")
                    ForEach(AppBackgroundStyle.allCases) { style in
                        Button {
                            backgroundStyleRaw = style.rawValue
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(style.color)
                                    .frame(width: 10, height: 10)
                                Text(style.name)
                            }
                        }
                    }

                    Divider()

                    Button("Choose Color Palette…") {
                        showingBackgroundPalette = true
                    }

                    Button("Choose Background Image…") {
                        chooseBackgroundImage()
                    }

                    if !backgroundImagePath.isEmpty {
                        Button("Remove Background Image") {
                            backgroundImagePath = ""
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Change background")
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(.clear)
        .popover(isPresented: $showingBackgroundPalette) {
            ColorPaletteGrid(
                title: "Background Color",
                selectedHex: backgroundColorHex
            ) { hex in
                backgroundColorHex = hex
                backgroundStyleRaw = "custom"
                showingBackgroundPalette = false
            }
        }
    }

    private func pageButton(_ target: AppPage, shortcut: String) -> some View {
        Button {
            page = target
        } label: {
            Text(target.rawValue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(page == target ? Color.accentColor : .clear)
                .foregroundStyle(page == target ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(target == .timeline ? "1" : "2", modifiers: [.command])
        .help("快捷键：\(shortcut)")
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        let startedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = appSupport.appendingPathComponent("ParallelTaskManager", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let destination = folder.appendingPathComponent("backgroundImage.\(sourceURL.pathExtension)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            backgroundImagePath = destination.path
        } catch {
            // 如果复制失败，保留当前背景，不影响软件继续使用。
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, TaskItem.self, Event.self, RecurringTask.self, ProjectContext.self], inMemory: true)
}
