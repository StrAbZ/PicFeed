import SwiftUI

struct PhotoCell: View {
    let photo: Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            placeholderColor
                .aspectRatio(photo.aspectRatio, contentMode: .fit)
                .overlay {
                    CachedImage(url: photo.urls.thumb)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

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
