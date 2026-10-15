import SwiftUI

struct FeedView: View {
    private let client: UnsplashClient

    @State private var editorialFeed: PhotoFeed
    @State private var searchFeed: PhotoFeed?
    @State private var searchText = ""

    init(client: UnsplashClient) {
        self.client = client
        _editorialFeed = State(initialValue: PhotoFeed(client: client))
    }

    var body: some View {
        let feed = searchFeed ?? editorialFeed

        NavigationStack {
            PhotoGrid(feed: feed)
                .id(feed.id)
                .navigationTitle(searchFeed == nil ? "PicFeed" : "Results")
        }
        .searchable(text: $searchText)
        .onSubmit(of: .search) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }
            searchFeed = PhotoFeed(client: client, query: query)
        }
        .onChange(of: searchText) {
            if searchText.isEmpty { searchFeed = nil }
        }
    }
}

#Preview {
    FeedView(client: UnsplashClient(accessKey: Secrets.unsplashAccessKey))
}
