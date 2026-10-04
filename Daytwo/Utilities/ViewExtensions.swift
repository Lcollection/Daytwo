import SwiftUI

extension View {
    /// 主窗口最小尺寸
    func appMinFrame() -> some View {
        frame(minWidth: 940, minHeight: 600)
    }

    /// 圆角小胶囊背景（用于位置等信息条）
    func chipStyle() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            .foregroundStyle(Color.accentColor)
    }
}
