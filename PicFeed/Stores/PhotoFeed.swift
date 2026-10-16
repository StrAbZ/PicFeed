import Foundation
import Observation

@Observable
final class PhotoFeed: Identifiable {
    let id = UUID()

    private(set) var photos: [Photo] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    private(set) var isShowingSavedPhotos = false
    private(set) var error: Error?

    private let client: UnsplashClient
    private let query: String?
    private let prefetchThreshold = 6
    private var lastLoadedPage = 0
    private var loadedIDs = Set<Photo.ID>()

    init(client: UnsplashClient, query: String? = nil) {
        self.client = client
        self.query = query
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let nextPage = lastLoadedPage + 1
            let page = if let query {
                try await client.search(query: query, page: nextPage)
            } else {
                try await client.photos(page: nextPage)
            }
            lastLoadedPage += 1
            if page.isFromCache { isShowingSavedPhotos = true }
            photos += page.photos.filter { loadedIDs.insert($0.id).inserted }
            hasMore = page.totalPages.map { lastLoadedPage < $0 } ?? !page.photos.isEmpty
        } catch {
            if !Task.isCancelled { self.error = error }
        }
    }

    /// Called as cells appear. Does nothing after a failure, so a broken
    /// connection can't burn through the hourly API quota; the user retries.
    func loadMoreIfNeeded(after photo: Photo) async {
        guard error == nil, photos.suffix(prefetchThreshold).contains(where: { $0.id == photo.id })
        else { return }
        await loadMore()
    }
}
