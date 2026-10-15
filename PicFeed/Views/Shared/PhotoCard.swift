import SwiftUI

/// The picture with its caption: what the grid shows, and what flies to full screen.
struct PhotoCard: View {
    let photo: Photo
    var cornerRadius = 12.0
    /// `nil` in the grid. The detail loads the full-size image on top of the thumbnail.
    var fullImageOpacity: Double?
    var showsCaption = true

    var body: some View {
        placeholderColor
            .aspectRatio(photo.aspectRatio, contentMode: .fit)
            .overlay {
                CachedImage(url: photo.urls.thumb)
                if let fullImageOpacity {
                    CachedImage(url: photo.urls.regular)
                        .opacity(fullImageOpacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .bottom) { caption }
    }

    private var placeholderColor: Color {
        Color(hex: photo.color) ?? Color(.secondarySystemFill)
    }

    @ViewBuilder
    private var caption: some View {
        if let text = photo.caption {
            CaptionLabel(text: text)
                .opacity(showsCaption ? 1 : 0)
                .animation(showsCaption ? .easeIn(duration: 0.25) : .easeOut(duration: 0.12),
                           value: showsCaption)
        }
    }
}

private struct CaptionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground()
            .padding(8)
    }
}
