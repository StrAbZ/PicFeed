import Foundation
import Testing
@testable import PicFeed

@MainActor
struct PhotoFeedTests {
    private let client = UnsplashClient.test(session: .fixtures)

    private func recordedPage(_ page: Int) async throws -> [Photo] {
        try await client.photos(page: page).photos
    }

    private func loadEverything(_ feed: PhotoFeed) async {
        while feed.hasMore {
            await feed.loadMore()
        }
    }

    @Test func firstLoadFillsOnePage() async throws {
        let feed = PhotoFeed(client: client)

        await feed.loadMore()

        let expected = try await recordedPage(1)
        #expect(feed.photos.map(\.id) == expected.map(\.id))
        #expect(!feed.isLoading)
        #expect(feed.error == nil)
    }

    @Test func eachLoadAppendsTheNextPage() async throws {
        let feed = PhotoFeed(client: client)

        await feed.loadMore()
        await feed.loadMore()

        let expected = try await recordedPage(1) + recordedPage(2)
        #expect(feed.photos.map(\.id) == expected.map(\.id))
    }

    @Test func feedEndsOnTheFirstEmptyPage() async {
        let feed = PhotoFeed(client: client)

        await loadEverything(feed)

        // The 15 recorded pages hold 430 photos, 429 of them distinct.
        #expect(feed.photos.count == 429)
        #expect(Set(feed.photos.map(\.id)).count == feed.photos.count)
    }

    @Test func searchFeedEndsWhenTheResultsRunOut() async {
        let feed = PhotoFeed(client: client, query: "nature")

        await loadEverything(feed)

        #expect(feed.photos.count == 90)
    }

    @Test func liveFeedDoesNotClaimToShowSavedPhotos() async {
        let feed = PhotoFeed(client: client)

        await feed.loadMore()

        #expect(!feed.isShowingSavedPhotos)
    }

    @Test func nothingLoadsWhenAPhotoFarFromTheEndAppears() async throws {
        let feed = PhotoFeed(client: client)
        await feed.loadMore()

        await feed.loadMoreIfNeeded(after: try #require(feed.photos.first))

        #expect(feed.photos.count == (try await recordedPage(1)).count)
    }

    @Test func nextPageLoadsWhenOneOfTheLastPhotosAppears() async throws {
        let feed = PhotoFeed(client: client)
        await feed.loadMore()

        await feed.loadMoreIfNeeded(after: try #require(feed.photos.last))

        #expect(feed.photos.count > (try await recordedPage(1)).count)
    }
}

extension Stubbed {
    @MainActor
    @Suite struct PhotoFeedFailures {
        @Test func photoSeenOnTwoPagesIsKeptOnce() async {
            let session = StubURLProtocol.stub { request in
                request.page == 1 ? .photos(ids: ["a", "b"]) : .photos(ids: ["b", "c"])
            }
            let feed = PhotoFeed(client: .test(session: session))

            await feed.loadMore()
            await feed.loadMore()

            #expect(feed.photos.map(\.id) == ["a", "b", "c"])
        }

        @Test func failureStopsAutomaticLoadingUntilRetry() async throws {
            let session = StubURLProtocol.stub { request in
                request.page == 1 ? .photos(ids: ["a", "b"]) : .init(statusCode: 500)
            }
            let feed = PhotoFeed(client: .test(session: session))
            await feed.loadMore()
            await feed.loadMore()
            #expect(feed.error != nil)
            #expect(StubURLProtocol.requestCount == 2)

            await feed.loadMoreIfNeeded(after: try #require(feed.photos.last))
            #expect(StubURLProtocol.requestCount == 2)

            await feed.loadMore()
            #expect(StubURLProtocol.requestCount == 3)
        }

        @Test func savedPhotosAreFlaggedAndStayFlaggedWhenLaterPagesAreLive() async {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { request in
                StubURLProtocol.requestCount == 3
                    ? .init(failure: .notConnectedToInternet)
                    : .photos(ids: [request.page == 1 ? "a" : "b"])
            })
            let warmUp = PhotoFeed(client: client)
            await warmUp.loadMore()
            await warmUp.loadMore()
            #expect(!warmUp.isShowingSavedPhotos)

            let feed = PhotoFeed(client: client)
            await feed.loadMore()
            #expect(feed.isShowingSavedPhotos)

            await feed.loadMore()
            #expect(feed.photos.map(\.id) == ["a", "b"])
            #expect(feed.isShowingSavedPhotos)
        }
    }
}
