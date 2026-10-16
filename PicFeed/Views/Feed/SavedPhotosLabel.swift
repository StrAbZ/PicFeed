import SwiftUI

struct SavedPhotosLabel: View {
    let feed: PhotoFeed

    var body: some View {
        Group {
            if feed.isShowingSavedPhotos {
                Text("Showing saved photos")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassBackground()
                    .padding()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: feed.isShowingSavedPhotos)
    }
}
