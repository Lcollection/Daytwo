import XCTest
@testable import Daytwo

final class VaultMarkdownTests: XCTestCase {

    private func makeEntry() -> JournalEntry {
        JournalEntry(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            modifiedAt: Date(timeIntervalSince1970: 1_700_050_000),
            title: "西湖边的半日闲",
            content: "# 西湖边的半日闲\n\n- 断桥人还是多\n> 很美",
            favorite: true,
            latitude: 30.2530,
            longitude: 120.1399,
            locationName: "杭州市 · 西湖区",
            locality: "杭州市"
        )
    }

    func testVaultMarkdownRoundTrip() throws {
        let entry = makeEntry()
        let text = entry.vaultMarkdown()

        XCTAssertTrue(text.hasPrefix("---\nid: \(entry.id.uuidString)"))
        XCTAssertTrue(text.contains("favorite: true"))
        XCTAssertTrue(text.contains("location: 杭州市 · 西湖区"))
        XCTAssertTrue(text.contains("coordinates: 30.253, 120.1399"))

        let parsed = try XCTUnwrap(JournalEntry.parse(vaultMarkdown: text))
        XCTAssertEqual(parsed.id, entry.id)
        XCTAssertEqual(parsed.title, entry.title)
        XCTAssertEqual(parsed.content, entry.content)
        XCTAssertEqual(parsed.createdAt, entry.createdAt)
        XCTAssertEqual(parsed.modifiedAt, entry.modifiedAt)
        XCTAssertEqual(parsed.favorite, entry.favorite)
        XCTAssertEqual(parsed.latitude, entry.latitude)
        XCTAssertEqual(parsed.longitude, entry.longitude)
        XCTAssertEqual(parsed.locationName, entry.locationName)
        XCTAssertEqual(parsed.locality, entry.locality)
    }

    func testRoundTripWithoutOptionalFields() throws {
        let entry = JournalEntry(content: "只有正文")
        let parsed = try XCTUnwrap(JournalEntry.parse(vaultMarkdown: entry.vaultMarkdown()))
        XCTAssertEqual(parsed.id, entry.id)
        XCTAssertEqual(parsed.content, "只有正文")
        XCTAssertNil(parsed.title)
        XCTAssertNil(parsed.latitude)
        XCTAssertFalse(parsed.favorite)
    }

    func testParseRejectsInvalidDocuments() {
        XCTAssertNil(JournalEntry.parse(vaultMarkdown: "普通文本，没有 front matter"))
        XCTAssertNil(JournalEntry.parse(vaultMarkdown: "---\ncreated: 2025-10-04T00:00:00Z\n---\n缺少 id"))
        XCTAssertNil(JournalEntry.parse(vaultMarkdown: "---\nid: not-a-uuid\n---\n正文"))
    }

    func testParseToleratesTitleWithColon() throws {
        let text = """
        ---
        id: \(UUID().uuidString)
        created: 2025-10-04T08:00:00Z
        title: 读《夜航船》：一些笔记
        ---
        正文
        """
        let parsed = try XCTUnwrap(JournalEntry.parse(vaultMarkdown: text))
        XCTAssertEqual(parsed.title, "读《夜航船》：一些笔记")
        XCTAssertEqual(parsed.content, "正文")
    }
}
