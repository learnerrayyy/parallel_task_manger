import Foundation
import SwiftData

/// App 与 Widget Extension 共用的 SwiftData 容器。
///
/// 主 App 与自己的 Widget 使用同一个 App Group，共享 SwiftData 数据。
enum SharedModelContainer {

    // Replace this with an App Group registered to your own Apple Developer Team
    // when signing the app and widget together.
    static let appGroupID = "group.com.example.ParallelTaskManager"

    /// 整个 App 用到的 SwiftData 模型集合
    static let schema = Schema([
        Project.self,
        TaskItem.self,
        Event.self,
        RecurringTask.self,
        ProjectContext.self
    ])

    /// 主 App 和 Widget 都调用这个方法拿到同一个容器
    static func makeContainer() -> ModelContainer {
        let sharedConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID)
        )
        do {
            return try ModelContainer(for: schema, configurations: [sharedConfig])
        } catch {
            // App Group 尚未签名或用户拒绝访问时，主 App 仍可使用本地数据；
            // Widget 在这种情况下不会看到共享数据，但也不应导致主 App 闪退。
            let localConfig = ModelConfiguration(schema: schema)
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("无法创建 SwiftData 容器：\(error)")
            }
        }
    }
}
