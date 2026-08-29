import Foundation
import SwiftData

/// 文档 §20 MVP -> Context: Current state / Problem / Next step / Resources
/// 用途：帮用户"恢复上下文"——很久没碰这个 Project 时，快速回忆进度和卡点。
@Model
final class ProjectContext {
    @Attribute(.unique) var id: UUID
    var currentState: String
    var problem: String
    var nextStep: String
    var resources: String
    var updatedAt: Date

    var project: Project?

    init(project: Project?,
         currentState: String = "",
         problem: String = "",
         nextStep: String = "",
         resources: String = "") {
        self.id = UUID()
        self.project = project
        self.currentState = currentState
        self.problem = problem
        self.nextStep = nextStep
        self.resources = resources
        self.updatedAt = Date()
    }

    var isEmpty: Bool {
        currentState.isEmpty && problem.isEmpty && nextStep.isEmpty && resources.isEmpty
    }
}
