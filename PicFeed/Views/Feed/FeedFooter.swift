import SwiftUI

struct FeedFooter: View {
    let feed: PhotoFeed

    var body: some View {
        VStack(spacing: 8) {
            if feed.isShowingSavedPhotos {
                Text("Showing saved photos")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            status
        }
        .padding()
    }

    @ViewBuilder
    private var status: some View {
        if feed.isLoading {
            ProgressView()
        } else if let error = feed.error {
            if feed.photos.isEmpty {
                ContentUnavailableView {
                    Label("Can't load photos", systemImage: "wifi.slash")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Retry") { Task { await feed.loadMore() } }
                }
            } else {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await feed.loadMore() } }
            }
        } else if feed.photos.isEmpty && !feed.hasMore {
            ContentUnavailableView.search
        }
    }
}
