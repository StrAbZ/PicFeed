import SwiftUI

struct PhotoGrid: View {
    let feed: PhotoFeed

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(feed.photos) { photo in
                    PhotoCell(photo: photo)
                        .task { await feed.loadMoreIfNeeded(after: photo) }
                }
            }
            .padding(.horizontal, 12)

            FeedFooter(feed: feed)
        }
        .task {
            if feed.photos.isEmpty { await feed.loadMore() }
        }
    }
}
