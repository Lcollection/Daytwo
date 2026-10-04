import XCTest
@testable import Daytwo

final class MarkdownFormatterTests: XCTestCase {

    // MARK: - 行内包裹

    func testBoldWrap() {
        let edit = MarkdownFormatter.apply(.bold, to: "hello world", selectedRange: NSRange(location: 6, length: 5))
        XCTAssertEqual(edit.text, "hello **world**")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 8, length: 5))
    }

    func testBoldUnwrap() {
        let edit = MarkdownFormatter.apply(.bold, to: "hello **world**", selectedRange: NSRange(location: 6, length: 9))
        XCTAssertEqual(edit.text, "hello world")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 6, length: 5))
    }

    func testWrapEmptySelection() {
        // 空选区斜体：插入一对星号，光标落在中间
        let edit = MarkdownFormatter.apply(.italic, to: "abc", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(edit.text, "a**bc")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 2, length: 0))
    }

    // MARK: - 标题

    func testHeadingAdd() {
        let edit = MarkdownFormatter.apply(.heading(level: 1), to: "标题内容", selectedRange: NSRange(location: 0, length: 4))
        XCTAssertEqual(edit.text, "# 标题内容")
    }

    func testHeadingToggleOff() {
        let edit = MarkdownFormatter.apply(.heading(level: 2), to: "## 标题", selectedRange: NSRange(location: 0, length: 4))
        XCTAssertEqual(edit.text, "标题")
    }

    func testHeadingChangeLevel() {
        let edit = MarkdownFormatter.apply(.heading(level: 1), to: "### 标题", selectedRange: NSRange(location: 0, length: 5))
        XCTAssertEqual(edit.text, "# 标题")
    }

    func testHeadingLevelParsing() {
        XCTAssertEqual(MarkdownFormatter.headingLevel(of: "# a"), 1)
        XCTAssertEqual(MarkdownFormatter.headingLevel(of: "###### a"), 6)
        XCTAssertNil(MarkdownFormatter.headingLevel(of: "####### a"))
        XCTAssertNil(MarkdownFormatter.headingLevel(of: "#no space"))
        XCTAssertNil(MarkdownFormatter.headingLevel(of: "普通文本"))
    }

    // MARK: - 列表 / 引用 / 待办

    func testBulletListAddAndRemove() {
        let add = MarkdownFormatter.apply(.bulletList, to: "第一行\n第二行", selectedRange: NSRange(location: 0, length: 6))
        XCTAssertEqual(add.text, "- 第一行\n- 第二行")

        let remove = MarkdownFormatter.apply(.bulletList, to: add.text, selectedRange: NSRange(location: 0, length: 13))
        XCTAssertEqual(remove.text, "第一行\n第二行")
    }

    func testNumberedList() {
        let edit = MarkdownFormatter.apply(.numberedList, to: "一\n二\n三", selectedRange: NSRange(location: 0, length: 5))
        XCTAssertEqual(edit.text, "1. 一\n2. 二\n3. 三")
    }

    func testTodoList() {
        let edit = MarkdownFormatter.apply(.todoList, to: "买牛奶", selectedRange: NSRange(location: 0, length: 3))
        XCTAssertEqual(edit.text, "- [ ] 买牛奶")
    }

    func testBlockquote() {
        let edit = MarkdownFormatter.apply(.blockquote, to: "引文", selectedRange: NSRange(location: 0, length: 2))
        XCTAssertEqual(edit.text, "> 引文")
    }

    // MARK: - 链接 / 分隔线

    func testLinkWithSelection() {
        let edit = MarkdownFormatter.apply(.link, to: "点这里", selectedRange: NSRange(location: 0, length: 3))
        XCTAssertEqual(edit.text, "[点这里](https://)")
        XCTAssertEqual(edit.selectedRange.location, 7)
        XCTAssertEqual(edit.selectedRange.length, 8)
    }

    func testHorizontalRule() {
        let edit = MarkdownFormatter.apply(.horizontalRule, to: "abc", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(edit.text, "a---\nbc")
    }

    // MARK: - 派生信息

    func testTitleFromMarkdown() {
        XCTAssertEqual(MarkdownFormatter.title(from: "# 我的一天\n正文内容"), "我的一天")
        XCTAssertEqual(MarkdownFormatter.title(from: "\n\n**Hello**"), "Hello")
        XCTAssertEqual(MarkdownFormatter.title(from: ""), "")
    }

    func testPlainPreview() {
        let markdown = "# 标题\n![图片](http://x.com/a.png)\n- **要点**一\n[链接文字](http://x)\n```\ncode\n```\n第二段"
        let preview = MarkdownFormatter.plainPreview(from: markdown, limit: 200)
        XCTAssertFalse(preview.contains("#"))
        XCTAssertFalse(preview.contains("["))
        XCTAssertFalse(preview.contains("http"))
        XCTAssertTrue(preview.contains("标题"))
        XCTAssertTrue(preview.contains("要点"))
        XCTAssertTrue(preview.contains("第二段"))
    }

    func testWordCount() {
        // 中文按字数，英文按词数
        XCTAssertEqual(MarkdownFormatter.wordCount(of: "你好世界"), 4)
        XCTAssertEqual(MarkdownFormatter.wordCount(of: "hello world"), 2)
        XCTAssertEqual(MarkdownFormatter.wordCount(of: "你好 hello 世界 world 123"), 4 + 3)
        XCTAssertEqual(MarkdownFormatter.wordCount(of: ""), 0)
    }
}
