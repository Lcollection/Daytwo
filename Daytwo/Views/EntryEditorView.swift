import SwiftUI
import SwiftData
import MarkdownUI

/// Day One 式编辑器：条目在打开前已创建（创建时间 = 点击"+" 的瞬间），
/// 输入内容自动保存，没有"保存/取消"按钮。
/// 关闭时若内容为空且无位置，草稿会被自动丢弃。
struct EntryEditorView: View {
    enum Mode: String, CaseIterable {
        case edit = "编辑"
        case preview = "预览"
    }

    @Environment(\.modelContext) private var modelContext

    /// 正在编辑的条目（已存在于数据库）
    let entry: JournalEntry
    /// 新建日记时为 true：自动把定位结果挂到该条目上
    private let autoCaptureLocation: Bool

    @State private var text: String
    @State private var mode: Mode = .edit
    @State private var wantsLocation: Bool
    @State private var saveTask: Task<Void, Never>?
    @State private var locationService = LocationService.shared
    @StateObject private var controller = MarkdownEditorController()

    init(entry: JournalEntry, autoCaptureLocation: Bool = false) {
        self.entry = entry
        self.autoCaptureLocation = autoCaptureLocation
        _text = State(initialValue: entry.content)
        _wantsLocation = State(initialValue: autoCaptureLocation)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("视图", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            .padding(.top, 10)

            if mode == .edit {
                MarkdownEditorView(text: $text, controller: controller)
            } else {
                ScrollView {
                    Markdown(text.isEmpty ? "*（暂无内容）*" : text)
                        .markdownTheme(.gitHub)
                        .padding(20)
                        .frame(maxWidth: 720, alignment: .leading)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if mode == .edit {
                    markdownToolbar
                    Divider()
                }
                locationBar
            }
            .background(.bar)
        }
        .navigationTitle(entry.title.isEmpty ? "新日记" : entry.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    entry.favorite.toggle()
                    try? modelContext.save()
                    VaultService.shared.writeEntry(entry)
                } label: {
                    Image(systemName: entry.favorite ? "star.fill" : "star")
                }
                .help(entry.favorite ? "取消收藏" : "收藏")
            }
        }
        .onChange(of: text) { scheduleAutosave() }
        .onChange(of: locationService.locationName) { attachLocationIfWaiting() }
        .onChange(of: locationService.currentLocation) { attachLocationIfWaiting() }
        .onDisappear(perform: finishEditing)
    }

    // MARK: - Markdown 工具栏

    private var markdownToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                toolButton("bold", tip: "加粗 **") { controller.perform(.bold) }
                toolButton("italic", tip: "斜体 *") { controller.perform(.italic) }
                toolButton("strikethrough", tip: "删除线 ~~") { controller.perform(.strikethrough) }
                toolButton("curlybraces.square", tip: "行内代码 `") { controller.perform(.inlineCode) }
                toolButton("link", tip: "链接") { controller.perform(.link) }

                Divider().frame(height: 16)

                Button { controller.perform(.heading(level: 1)) } label: {
                    Text("H1").font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("一级标题")

                Button { controller.perform(.heading(level: 2)) } label: {
                    Text("H2").font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("二级标题")

                Divider().frame(height: 16)

                toolButton("text.quote", tip: "引用 >") { controller.perform(.blockquote) }
                toolButton("list.bullet", tip: "无序列表") { controller.perform(.bulletList) }
                toolButton("list.number", tip: "有序列表") { controller.perform(.numberedList) }
                toolButton("checklist", tip: "待办事项") { controller.perform(.todoList) }
                toolButton("minus", tip: "分隔线") { controller.perform(.horizontalRule) }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 40)
    }

    private func toolButton(_ symbol: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    // MARK: - 位置栏

    private var locationBar: some View {
        HStack(spacing: 8) {
            if entry.hasLocation {
                if wantsLocation && locationService.isLocating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                }
                Text(entry.locationName ?? "定位中…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    refreshLocation()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("重新定位当前位置")
                Button {
                    removeLocation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("移除位置")
            } else if wantsLocation {
                ProgressView().controlSize(.small)
                Text(progressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    wantsLocation = false
                    locationService.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("不记录位置")
            } else {
                Button {
                    wantsLocation = true
                    locationService.capture()
                } label: {
                    Label("添加位置", systemImage: "location")
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                Spacer()
                if let status = locationService.statusText {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var progressText: String {
        if let status = locationService.statusText { return status }
        if let name = locationService.locationName { return name }
        return locationService.isLocating ? "正在定位当前位置…" : "正在解析地点…"
    }

    // MARK: - 自动保存

    private func scheduleAutosave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            persistContent()
        }
    }

    /// 把当前文本写入模型，并同步日记文件夹（幂等）
    private func persistContent() {
        if entry.content != text {
            entry.content = text
            entry.title = MarkdownFormatter.title(from: text)
            entry.modifiedAt = .now
            try? modelContext.save()
        }
        VaultService.shared.writeEntry(entry)
    }

    /// 立即落盘；空草稿（无内容且无位置）自动丢弃
    private func finishEditing() {
        saveTask?.cancel()
        persistContent()
        wantsLocation = false

        if entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !entry.hasLocation {
            VaultService.shared.deleteEntry(entry)
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    // MARK: - 位置

    /// 定位结果到达时挂到条目上（新建自动记录 / 手动添加 / 手动刷新）
    private func attachLocationIfWaiting() {
        guard wantsLocation else { return }
        guard let location = locationService.currentLocation else { return }

        if entry.latitude == nil {
            applyLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                name: locationService.locationName,
                locality: locationService.localityGroup
            )
        } else if entry.locationName != locationService.locationName {
            // 坐标已挂上，地名解析完成后补充
            entry.locationName = locationService.locationName
            entry.locality = locationService.localityGroup
            entry.modifiedAt = .now
            try? modelContext.save()
            VaultService.shared.writeEntry(entry)
        }
    }

    private func applyLocation(latitude: Double, longitude: Double, name: String?, locality: String?) {
        entry.latitude = latitude
        entry.longitude = longitude
        entry.locationName = name
        entry.locality = locality
        entry.modifiedAt = .now
        try? modelContext.save()
        VaultService.shared.writeEntry(entry)
    }

    private func refreshLocation() {
        entry.latitude = nil
        entry.longitude = nil
        entry.locationName = nil
        entry.locality = nil
        wantsLocation = true
        locationService.capture()
        try? modelContext.save()
    }

    private func removeLocation() {
        entry.latitude = nil
        entry.longitude = nil
        entry.locationName = nil
        entry.locality = nil
        wantsLocation = false
        locationService.clear()
        entry.modifiedAt = .now
        try? modelContext.save()
        VaultService.shared.writeEntry(entry)
    }
}
