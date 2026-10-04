import Foundation

/// 编辑器工具栏可执行的 Markdown 命令
enum MarkdownCommand {
    case bold
    case italic
    case strikethrough
    case inlineCode
    case link
    case heading(level: Int)
    case blockquote
    case bulletList
    case numberedList
    case todoList
    case horizontalRule
}

/// 一次文本编辑的结果：新文本 + 编辑后的选区
struct MarkdownEdit: Equatable {
    let text: String
    let selectedRange: NSRange
}

/// 纯函数式 Markdown 文本变换，iOS / macOS 编辑器共用。
enum MarkdownFormatter {

    // MARK: - 命令应用

    static func apply(_ command: MarkdownCommand, to text: String, selectedRange range: NSRange) -> MarkdownEdit {
        let nsText = text as NSString
        let sel = safeRange(range, in: nsText)

        switch command {
        case .bold:
            return wrap(nsText: nsText, range: sel, marker: "**")
        case .italic:
            return wrap(nsText: nsText, range: sel, marker: "*")
        case .strikethrough:
            return wrap(nsText: nsText, range: sel, marker: "~~")
        case .inlineCode:
            return wrap(nsText: nsText, range: sel, marker: "`")
        case .link:
            return makeLink(nsText: nsText, range: sel)
        case .heading(let level):
            return setHeading(nsText: nsText, range: sel, level: level)
        case .blockquote:
            return toggleLinePrefix(nsText: nsText, range: sel, prefix: "> ")
        case .bulletList:
            return toggleLinePrefix(nsText: nsText, range: sel, prefix: "- ")
        case .todoList:
            return toggleLinePrefix(nsText: nsText, range: sel, prefix: "- [ ] ")
        case .numberedList:
            return numberLines(nsText: nsText, range: sel)
        case .horizontalRule:
            return insertHorizontalRule(nsText: nsText, at: sel)
        }
    }

    // MARK: - 行内包裹（加粗 / 斜体 / 删除线 / 行内代码）

    private static func wrap(nsText: NSString, range: NSRange, marker: String) -> MarkdownEdit {
        let selected = nsText.substring(with: range)
        let markerLen = (marker as NSString).length

        // 已包裹则取消
        if selected.hasPrefix(marker), selected.hasSuffix(marker), selected.count >= marker.count * 2 {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            let newText = nsText.replacingCharacters(in: range, with: inner)
            return MarkdownEdit(text: newText, selectedRange: NSRange(location: range.location, length: (inner as NSString).length))
        }

        let wrapped = marker + selected + marker
        let newText = nsText.replacingCharacters(in: range, with: wrapped)
        return MarkdownEdit(
            text: newText,
            selectedRange: NSRange(location: range.location + markerLen, length: (selected as NSString).length)
        )
    }

    private static func makeLink(nsText: NSString, range: NSRange) -> MarkdownEdit {
        let selected = nsText.substring(with: range)
        if selected.isEmpty {
            let label = "文本"
            let snippet = "[\(label)](https://)"
            let newText = nsText.replacingCharacters(in: range, with: snippet)
            return MarkdownEdit(
                text: newText,
                selectedRange: NSRange(location: range.location + 1, length: (label as NSString).length)
            )
        } else {
            let snippet = "[\(selected)](https://)"
            let newText = nsText.replacingCharacters(in: range, with: snippet)
            let urlStart = range.location + 1 + (selected as NSString).length + 3
            return MarkdownEdit(
                text: newText,
                selectedRange: NSRange(location: urlStart, length: ("https://" as NSString).length)
            )
        }
    }

    // MARK: - 标题

    private static func setHeading(nsText: NSString, range: NSRange, level: Int) -> MarkdownEdit {
        let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
        let line = nsText.substring(with: lineRange)
        let hasNewline = line.hasSuffix("\n")
        let body = hasNewline ? String(line.dropLast()) : line

        let newBody: String
        if let existing = headingLevel(of: body) {
            newBody = existing == level ? stripHeading(body) : String(repeating: "#", count: level) + " " + stripHeading(body)
        } else {
            newBody = String(repeating: "#", count: level) + " " + stripHeading(body)
        }

        let newLine = hasNewline ? newBody + "\n" : newBody
        let newText = nsText.replacingCharacters(in: lineRange, with: newLine)
        let cursor = lineRange.location + (newBody as NSString).length
        return MarkdownEdit(text: newText, selectedRange: NSRange(location: cursor, length: 0))
    }

    /// 解析一行文字的标题级别，不是标题则返回 nil
    static func headingLevel(of line: String) -> Int? {
        var hashes = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#" {
            hashes += 1
            idx = line.index(after: idx)
        }
        guard hashes >= 1, hashes <= 6 else { return nil }
        if idx == line.endIndex { return hashes }              // 整行都是 #
        return line[idx] == " " ? hashes : nil                  // "# 标题"
    }

    /// 去掉行首的标题标记
    static func stripHeading(_ line: String) -> String {
        guard let level = headingLevel(of: line) else { return line }
        var s = line.dropFirst(level)
        while s.first == " " { s = s.dropFirst() }
        return String(s)
    }

    // MARK: - 多行前缀（引用 / 列表 / 待办）

    private static func toggleLinePrefix(nsText: NSString, range sel: NSRange, prefix: String) -> MarkdownEdit {
        let fullLineRange = nsText.lineRange(for: NSRange(location: sel.location, length: sel.length))
        let block = nsText.substring(with: fullLineRange)
        let lines = block.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.isEmpty }
        let allHave = !nonEmpty.isEmpty && nonEmpty.allSatisfy { $0.hasPrefix(prefix) }

        let newLines = lines.map { line -> String in
            if line.isEmpty { return line }
            return allHave ? String(line.dropFirst(prefix.count)) : prefix + line
        }
        let newBlock = newLines.joined(separator: "\n")
        let newText = nsText.replacingCharacters(in: fullLineRange, with: newBlock)
        let cursor = fullLineRange.location + (newBlock as NSString).length
        return MarkdownEdit(text: newText, selectedRange: NSRange(location: cursor, length: 0))
    }

    private static func numberLines(nsText: NSString, range sel: NSRange) -> MarkdownEdit {
        let fullLineRange = nsText.lineRange(for: NSRange(location: sel.location, length: sel.length))
        let block = nsText.substring(with: fullLineRange)
        let lines = block.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.isEmpty }
        let alreadyNumbered = !nonEmpty.isEmpty && nonEmpty.allSatisfy { numberPrefix(of: $0) != nil }

        var counter = 0
        let newLines = lines.map { line -> String in
            if line.isEmpty { return line }
            if alreadyNumbered {
                let stripped = String(line.dropFirst(numberPrefix(of: line)!.count))
                return stripped
            } else {
                counter += 1
                return "\(counter). " + line
            }
        }
        let newBlock = newLines.joined(separator: "\n")
        let newText = nsText.replacingCharacters(in: fullLineRange, with: newBlock)
        let cursor = fullLineRange.location + (newBlock as NSString).length
        return MarkdownEdit(text: newText, selectedRange: NSRange(location: cursor, length: 0))
    }

    private static func numberPrefix(of line: String) -> String? {
        guard let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression), match.lowerBound == line.startIndex else {
            return nil
        }
        return String(line[match])
    }

    // MARK: - 分隔线

    private static func insertHorizontalRule(nsText: NSString, at sel: NSRange) -> MarkdownEdit {
        let snippet = "---\n"
        let newText = nsText.replacingCharacters(in: sel, with: snippet)
        let cursor = sel.location + (snippet as NSString).length
        return MarkdownEdit(text: newText, selectedRange: NSRange(location: cursor, length: 0))
    }

    // MARK: - 工具

    private static func safeRange(_ r: NSRange, in nsText: NSString) -> NSRange {
        guard r.location != NSNotFound else { return NSRange(location: nsText.length, length: 0) }
        let loc = max(0, min(r.location, nsText.length))
        let len = max(0, min(r.length, nsText.length - loc))
        return NSRange(location: loc, length: len)
    }

    // MARK: - 派生信息

    /// 从 Markdown 提取标题：第一个非空行，去掉标记符号
    static func title(from markdown: String) -> String {
        for rawLine in markdown.components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            line = stripHeading(line)
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "#>*_`~[]()!-+ "))
            if line.isEmpty { continue }
            if line.count > 60 {
                line = String(line.prefix(60)) + "…"
            }
            return line
        }
        return ""
    }

    /// 去掉 Markdown 标记后的纯文本预览
    static func plainPreview(from markdown: String, limit: Int) -> String {
        var collected: [String] = []
        var total = 0
        var inFence = false

        for rawLine in markdown.components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence {
                continue
            }
            if line.isEmpty { continue }
            line = stripHeading(line)
            // 图片与链接
            line = line.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            line = line.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "#>*_`~[]()!-+ "))
            if line.isEmpty { continue }
            collected.append(line)
            total += line.count
            if total >= limit { break }
        }

        var text = collected.joined(separator: " ")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if text.count > limit {
            text = String(text.prefix(limit)) + "…"
        }
        return text
    }

    /// 字数统计：CJK 按字符，拉丁字母/数字按单词
    static func wordCount(of text: String) -> Int {
        var cjkCount = 0
        var latinWords = 0
        var currentLatinRun = 0

        func flushLatin() {
            if currentLatinRun > 0 {
                latinWords += 1
                currentLatinRun = 0
            }
        }

        for scalar in text.unicodeScalars {
            if isCJK(scalar) {
                flushLatin()
                cjkCount += 1
            } else if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                currentLatinRun += 1
            } else {
                flushLatin()
            }
        }
        flushLatin()
        return cjkCount + latinWords
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x2E80...0x2EFF,       // 部首
             0x3400...0x4DBF,       // 汉字扩展 A
             0x4E00...0x9FFF,       // 汉字基本区
             0xF900...0xFAFF,       // 兼容表意文字
             0x20000...0x2FA1F,     // 汉字扩展 B+
             0x3040...0x30FF,       // 平假名 / 片假名
             0xAC00...0xD7AF:       // 谚文
            return true
        default:
            return false
        }
    }
}
