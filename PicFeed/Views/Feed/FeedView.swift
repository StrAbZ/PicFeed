import SwiftUI

struct FeedView: View {
    private let client: UnsplashClient

    @State private var editorialFeed: PhotoFeed
    @State private var searchFeed: PhotoFeed?
    @State private var searchText = ""
    @State private var selectedPhoto: Photo?
    @State private var isExpanded = false
    @Namespace private var namespace

    init(client: UnsplashClient) {
        self.client = client
        _editorialFeed = State(initialValue: PhotoFeed(client: client))
    }

    private func finishDismissal() {
        guard selectedPhoto != nil, !isExpanded else { return }
        withAnimation(.easeOut(duration: 0.15)) { selectedPhoto = nil }
    }

    var body: some View {
        let feed = searchFeed ?? editorialFeed

        NavigationStack {
            PhotoGrid(feed: feed,
                      namespace: namespace,
                      selectedID: selectedPhoto?.id,
                      isExpanded: isExpanded,
                      onScroll: finishDismissal) { photo in
                if selectedPhoto?.id == photo.id {
                    withAnimation(PhotoDetailView.animation) {
                        isExpanded = true
                    }
                } else {
                    selectedPhoto = photo
                }
            }
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
            if searchText.isEmpty {
                searchFeed = nil
            }
        }
        .overlay {
            if let photo = selectedPhoto {
                PhotoDetailView(photo: photo,
                                namespace: namespace,
                                isExpanded: $isExpanded) {
                    if selectedPhoto?.id == photo.id, !isExpanded {
                        selectedPhoto = nil
                    }
                }
                .id(photo.id)
            }
        }
    }
}

#Preview {
    FeedView(client: UnsplashClient(accessKey: Secrets.unsplashAccessKey))
}
