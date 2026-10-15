import SwiftUI

struct FeedView: View {
    @State private var feed: PhotoFeed

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

    init(client: UnsplashClient) {
        _feed = State(initialValue: PhotoFeed(client: client))
    }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("PicFeed")
            .task {
                if feed.photos.isEmpty { await feed.loadMore() }
            }
        }
    }
}

#Preview {
    FeedView(client: UnsplashClient(accessKey: Secrets.unsplashAccessKey))
}
