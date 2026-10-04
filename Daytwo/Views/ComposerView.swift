import SwiftUI
import SwiftData
import MarkdownUI

/// 新建 / 编辑日记
struct ComposerView: View {
    enum Mode: String, CaseIterable {
        case edit = "编辑"
        case preview = "预览"
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// 传入即为编辑已有日记，nil 为新建
    let entry: JournalEntry?

    init(entry: JournalEntry? = nil) {
        self.entry = entry
    }

    @State private var text = ""
    @State private var initialText = ""
    @State private var mode: Mode = .edit
    @State private var hasLocation = false
    @State private var snapshot: LocationSnapshot?
    @State private var showDiscardConfirm = false
    @State private var locationService = LocationService.shared
    @StateObject private var controller = MarkdownEditorController()

    /// 位置快照，保存时写入模型
    struct LocationSnapshot {
        var name: String?
        var locality: String?
        var latitude: Double?
        var longitude: Double?
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.top, 8)

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
            .navigationTitle(entry == nil ? "新日记" : "编辑日记")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", role: .cancel) { cancelTapped() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(entry == nil ? "保存" : "完成") { save() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog(
                "放弃未保存的修改？",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
        }
        .onAppear(perform: setup)
        .onChange(of: locationService.locationName) {
            syncSnapshotFromService()
        }
        .onChange(of: locationService.currentLocation) {
            syncSnapshotFromService()
        }
    }

    private var hasUnsavedChanges: Bool {
        text != initialText
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
            if hasLocation {
                if locationService.isLocating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                }
                Text(locationService.locationName ?? snapshot?.name ?? "正在获取位置…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        hasLocation = false
                        snapshot = nil
                        locationService.clear()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("移除位置")
            } else {
                Button {
                    hasLocation = true
                    locationService.captureCurrentLocation()
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

    // MARK: - 逻辑

    private func setup() {
        if let entry {
            text = entry.content
            initialText = entry.content
            if entry.hasLocation {
                hasLocation = true
                snapshot = LocationSnapshot(
                    name: entry.locationName,
                    locality: entry.locality,
                    latitude: entry.latitude,
                    longitude: entry.longitude
                )
            }
        } else {
            // 新建日记时像 Day One 一样自动记录当前位置
            hasLocation = true
            locationService.captureCurrentLocation()
        }
    }

    private func syncSnapshotFromService() {
        guard hasLocation,
              let location = locationService.currentLocation else { return }
        snapshot = LocationSnapshot(
            name: locationService.locationName,
            locality: locationService.localityGroup,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func save() {
        let snap = effectiveSnapshot()
        if let entry {
            entry.content = text
            entry.title = MarkdownFormatter.title(from: text)
            entry.modifiedAt = .now
            entry.latitude = snap?.latitude
            entry.longitude = snap?.longitude
            entry.locationName = snap?.name
            entry.locality = snap?.locality
        } else {
            let newEntry = JournalEntry(
                title: MarkdownFormatter.title(from: text),
                content: text,
                latitude: snap?.latitude,
                longitude: snap?.longitude,
                locationName: snap?.name,
                locality: snap?.locality
            )
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
        dismiss()
    }

    /// 编辑已有日记且没有重新定位时，沿用原位置
    private func effectiveSnapshot() -> LocationSnapshot? {
        guard hasLocation else { return nil }
        if let snap = snapshot, snap.latitude != nil {
            return snap
        }
        if let entry, entry.hasLocation {
            return LocationSnapshot(
                name: entry.locationName,
                locality: entry.locality,
                latitude: entry.latitude,
                longitude: entry.longitude
            )
        }
        return nil
    }

    private func cancelTapped() {
        if hasUnsavedChanges {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }
}
