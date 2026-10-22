import SwiftUI

/// 实心按钮。macOS 26 的 borderedProminent 不再可靠地吃 tint，
/// 这里自己画，保证 Flow 式的实心色块按钮。
struct FilledButtonStyle: ButtonStyle {
    var color: Color = .green
    var maxWidth: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: maxWidth)
            .background(
                color.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}
