import SwiftUI

struct FeedFooter: View {
    let feed: PhotoFeed

    var body: some View {
        if feed.isLoading {
            ProgressView().padding()
        } else if let error = feed.error {
            VStack(spacing: 8) {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await feed.loadMore() } }
            }
            .padding()
        }
    }
}
