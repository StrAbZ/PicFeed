import SwiftUI

struct PhotoCell: View {
    let photo: Photo
    let namespace: Namespace.ID
    let isSelected: Bool
    let isSource: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            placeholderColor
                .aspectRatio(photo.aspectRatio, contentMode: .fit)
                .overlay {
                    CachedImage(url: photo.urls.thumb)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .matchedGeometryEffect(id: photo.id, in: namespace, isSource: isSource)
                .opacity(isSelected ? 0 : 1)

            if let caption = photo.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var placeholderColor: Color {
        Color(hex: photo.color) ?? Color(.secondarySystemFill)
    }
}
