import SwiftUI

struct PhotoGrid: View {
    let feed: PhotoFeed
    let namespace: Namespace.ID
    let selectedID: Photo.ID?
    let isExpanded: Bool
    let onScroll: () -> Void
    let onSelect: (Photo) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(feed.photos) { photo in
                    Button {
                        onSelect(photo)
                    } label: {
                        let isSelected = photo.id == selectedID
                        PhotoCell(photo: photo,
                                  namespace: namespace,
                                  isSelected: isSelected,
                                  isSource: !(isSelected && isExpanded))
                    }
                    .buttonStyle(.plain)
                    .task { await feed.loadMoreIfNeeded(after: photo) }
                }
            }
            .padding(.horizontal, 12)

            FeedFooter(feed: feed)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in
            onScroll()
        })
        .task {
            if feed.photos.isEmpty { await feed.loadMore() }
        }
    }
}
