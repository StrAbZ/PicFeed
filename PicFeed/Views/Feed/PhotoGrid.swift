import SwiftUI

struct PhotoGrid: View {
    let feed: PhotoFeed
    let namespace: Namespace.ID
    let selectedID: Photo.ID?
    let isExpanded: Bool
    let onScroll: () -> Void
    let onSelect: (Photo) -> Void

    private let columnCount = 2
    private let spacing: CGFloat = 12

    var body: some View {
        let columns = masonryColumns(for: feed.photos)

        ScrollView {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(columns.indices, id: \.self) { index in
                    LazyVStack(spacing: spacing) {
                        ForEach(columns[index]) { photo in
                            cell(for: photo)
                        }
                    }
                }
            }
            .padding(.horizontal, spacing)

            FeedFooter(feed: feed)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in
            onScroll()
        })
        .task {
            if feed.photos.isEmpty { await feed.loadMore() }
        }
    }

    private func cell(for photo: Photo) -> some View {
        let isSelected = photo.id == selectedID

        return Button {
            onSelect(photo)
        } label: {
            PhotoCell(photo: photo,
                      namespace: namespace,
                      isSelected: isSelected,
                      isSource: !(isSelected && isExpanded))
        }
        .buttonStyle(.plain)
        .task { await feed.loadMoreIfNeeded(after: photo) }
    }

    /// Each photo goes to the currently shortest column. Heights only depend on aspect ratios,
    /// so appending a page never moves a photo that is already placed.
    private func masonryColumns(for photos: [Photo]) -> [[Photo]] {
        var columns = Array(repeating: [Photo](), count: columnCount)
        var heights = Array(repeating: CGFloat.zero, count: columnCount)

        for photo in photos {
            let shortest = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[shortest].append(photo)
            heights[shortest] += 1 / max(photo.aspectRatio, 0.1)
        }
        return columns
    }
}
