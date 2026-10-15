import SwiftUI

extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
