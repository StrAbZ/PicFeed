import SwiftUI

/// The system close button on iOS 26 and later, a frosted circle before.
struct CloseControl: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            NavigationStack {
                Color.clear
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .close, action: action)
                        }
                    }
                    .containerBackground(.clear, for: .navigation)
            }
            .frame(height: 120)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        }
    }
}
