import SwiftUI
import SwiftData

@main
struct DaytwoApp: App {
    let container: ModelContainer

    init() {
        do {
            // 本地优先：显式禁用 CloudKit，数据只保存在设备本地。
            let configuration = ModelConfiguration(cloudKitDatabase: .none)
            container = try ModelContainer(for: JournalEntry.self, configurations: configuration)
        } catch {
            fatalError("无法创建本地数据库：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
