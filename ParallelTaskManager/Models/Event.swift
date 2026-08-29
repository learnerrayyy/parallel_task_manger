import Foundation
import SwiftData
import SwiftUI

enum EventType: String, Codable, CaseIterable, Identifiable {
    case deadline
    case meeting
    case interview
    case onlineAssessment
    case submission
    case milestone
    case appointment
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deadline: return "Deadline"
        case .meeting: return "Meeting"
        case .interview: return "Interview"
        case .onlineAssessment: return "Online Assessment"
        case .submission: return "Submission"
        case .milestone: return "Milestone"
        case .appointment: return "Appointment"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .deadline: return "flag.fill"
        case .meeting: return "person.2.fill"
        case .interview: return "bubble.left.and.bubble.right.fill"
        case .onlineAssessment: return "laptopcomputer"
        case .submission: return "paperplane.fill"
        case .milestone: return "star.fill"
        case .appointment: return "calendar"
        case .other: return "circle.fill"
        }
    }
}

/// 文档 §3.3：第一版只需要单日 Event
@Model
final class Event {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var time: Date?
    private var typeRaw: String
    var note: String?
    var completed: Bool
    var completedAt: Date?

    /// 可选：链接到某个具体 Task（文档 §3.3 note 字段说明：
    /// "只有将特定任务链接到某 ddl 事件的时候，ddl 下才能看到相关的任务"）
    var linkedTaskId: UUID?

    var project: Project?

    var type: EventType {
        get { EventType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(title: String, date: Date, time: Date? = nil, type: EventType, project: Project?, note: String? = nil) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.time = time
        self.typeRaw = type.rawValue
        self.note = note
        self.completed = false
        self.completedAt = nil
        self.project = project
    }
}

extension Project {
    var color: Color {
        Color(hex: colorHex)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: 1)
    }
}
