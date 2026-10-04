import SwiftUI
import AppKit

/// 编辑器控制器：桥接 SwiftUI 工具栏按钮与 NSTextView 的选区操作
@MainActor
final class MarkdownEditorController: ObservableObject {
    var getText: () -> String = { "" }
    var getSelectedRange: () -> NSRange = { NSRange(location: 0, length: 0) }
    var applyEdit: (MarkdownEdit) -> Void = { _ in }

    func perform(_ command: MarkdownCommand) {
        let edit = MarkdownFormatter.apply(command, to: getText(), selectedRange: getSelectedRange())
        applyEdit(edit)
    }
}

/// Markdown 编辑器：封装 NSTextView 以支持选区操作与等宽/衬线排版
struct MarkdownEditorView: View {
    @Binding var text: String
    let controller: MarkdownEditorController

    var body: some View {
        MacEditor(text: $text, controller: controller)
    }
}

private struct MacEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: MarkdownEditorController

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.font = Self.editorFont
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.string = text
        scrollView.documentView = textView

        controller.getText = { [weak textView] in textView?.string ?? "" }
        controller.getSelectedRange = { [weak textView] in
            textView?.selectedRange ?? NSRange(location: 0, length: 0)
        }
        controller.applyEdit = { [weak textView, weak coordinator = context.coordinator] edit in
            guard let textView else { return }
            textView.string = edit.text
            textView.selectedRanges = [NSValue(range: edit.selectedRange)]
            coordinator?.parent.text = edit.text
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    static var editorFont: NSFont {
        let size = NSFont.systemFontSize + 2
        let baseDescriptor = NSFont.systemFont(ofSize: size).fontDescriptor
        if let serifDescriptor = baseDescriptor.withDesign(.serif),
           let serifFont = NSFont(descriptor: serifDescriptor, size: size) {
            return serifFont
        }
        return NSFont.systemFont(ofSize: size)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditor
        init(_ parent: MacEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
