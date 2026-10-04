import XCTest
import SwiftData
@testable import Daytwo

@MainActor
final class VaultServiceTests: XCTestCase {

    private var vaultDir: URL!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: VaultService!

    override func setUpWithError() throws {
        vaultDir = FileManager.default.temporaryDirectory
            .appending(component: "daytwo-vault-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: JournalEntry.self, configurations: configuration)
        context = ModelContext(container)

        let defaults = UserDefaults(suiteName: "daytwo.vault.tests.\(UUID().uuidString)")!
        service = VaultService(defaults: defaults)
    }

    override func tearDownWithError() throws {
        if let url = service.vaultURL {
            url.stopAccessingSecurityScopedResource()
        }
        try? FileManager.default.removeItem(at: vaultDir)
    }

    private func filesInVault() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: vaultDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
    }

    func testEnableVaultWritesAllEntriesAsMarkdownFiles() throws {
        let entry = JournalEntry(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: "标题",
            content: "# 标题\n正文",
            latitude: 30.0,
            longitude: 120.0,
            locationName: "杭州市 · 西湖区",
            locality: "杭州市"
        )
        context.insert(entry)
        try context.save()

        try service.enableVault(at: vaultDir, context: context)

        XCTAssertTrue(service.isVaultActive)
        XCTAssertNotNil(entry.vaultFilename)
        let files = try filesInVault()
        XCTAssertEqual(files.count, 1)
        let text = try String(contentsOf: files[0], encoding: .utf8)
        XCTAssertTrue(text.contains("# 标题\n正文"))
        XCTAssertTrue(text.contains("location: 杭州市 · 西湖区"))
    }

    func testExternalEditsAreAbsorbedOnSync() throws {
        let entry = JournalEntry(content: "原始内容")
        context.insert(entry)
        try context.save()
        try service.enableVault(at: vaultDir, context: context)

        // 模拟外部编辑器追加内容
        let fileURL = try XCTUnwrap(try filesInVault().first)
        var text = try String(contentsOf: fileURL, encoding: .utf8)
        text += "\n外部追加的内容"
        try text.write(to: fileURL, atomically: true, encoding: .utf8)

        service.syncFromFolder(context: context)
        XCTAssertTrue(entry.content.contains("外部追加的内容"))
    }

    func testExternalNewFilesAreImportedAndDeletedFilesRemoveEntries() throws {
        let entry = JournalEntry(content: "会被删除的日记")
        context.insert(entry)
        try context.save()
        try service.enableVault(at: vaultDir, context: context)

        // 外部新增一个 Markdown 文件
        let external = """
        ---
        id: \(UUID().uuidString)
        created: 2025-01-01T08:00:00Z
        ---
        外部创建的日记
        """
        try external.write(to: vaultDir.appending(path: "外部.md"), atomically: true, encoding: .utf8)
        service.syncFromFolder(context: context)
        var all = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(all.count, 2)

        // 外部删除其中文件 → 对应条目被移除
        try FileManager.default.removeItem(at: try XCTUnwrap(try filesInVault().first { $0.lastPathComponent != "外部.md" }))
        service.syncFromFolder(context: context)
        all = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.content, "外部创建的日记")
    }

    func testWriteEntryThenDeleteEntryRemovesFile() throws {
        let entry = JournalEntry(content: "删除测试")
        context.insert(entry)
        try context.save()
        try service.enableVault(at: vaultDir, context: context)
        XCTAssertEqual(try filesInVault().count, 1)

        service.deleteEntry(entry)
        XCTAssertEqual(try filesInVault().count, 0)
    }
}
