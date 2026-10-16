import Foundation
import Testing
@testable import PicFeed

struct UnsplashClientTests {
    private let fixtures = UnsplashClient.test(session: .fixtures)

    @Test func decodesRecordedFeedPage() async throws {
        let page = try await fixtures.photos(page: 1)

        #expect(!page.photos.isEmpty)
        #expect(page.totalPages == nil)
        #expect(page.photos.allSatisfy { !$0.id.isEmpty && $0.width > 0 && $0.height > 0 })
    }

    @Test func decodesRecordedSearchPage() async throws {
        let page = try await fixtures.search(query: "nature", page: 1)

        #expect(page.photos.count == 30)
        #expect(page.totalPages == 334)
    }

    @Test func pastTheRecordedPagesTheFeedIsEmpty() async throws {
        #expect(try await fixtures.photos(page: 99).photos.isEmpty)
    }

    @Test func missingAccessKeyThrowsWithoutCallingTheNetwork() async {
        let client = UnsplashClient.test(accessKey: "", session: .fixtures)

        await #expect {
            try await client.photos(page: 1)
        } throws: { error in
            guard case UnsplashError.missingAccessKey = error else { return false }
            return true
        }
    }
}

extension Stubbed {
    @Suite struct UnsplashClientErrors {
        @Test func exhaustedQuotaIsReportedAsRateLimited() async {
            let session = StubURLProtocol.stub { _ in
                .init(statusCode: 403, headers: ["X-Ratelimit-Remaining": "0"])
            }
            let client = UnsplashClient.test(session: session)

            await #expect {
                try await client.photos(page: 1)
            } throws: { error in
                guard case UnsplashError.rateLimited = error else { return false }
                return true
            }
        }

        @Test func otherFailuresCarryTheStatusCode() async {
            let session = StubURLProtocol.stub { _ in .init(statusCode: 500) }
            let client = UnsplashClient.test(session: session)

            await #expect {
                try await client.photos(page: 1)
            } throws: { error in
                guard case UnsplashError.http(statusCode: 500) = error else { return false }
                return true
            }
        }
    }
}

extension Stubbed {
    @Suite struct UnsplashClientSavedPages {
        @Test func offlineServesThePageThatWasLoadedBefore() async throws {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in
                StubURLProtocol.requestCount == 1 ? .photos(ids: ["a", "b"]) : .init(failure: .notConnectedToInternet)
            })

            let live = try await client.photos(page: 1)
            let saved = try await client.photos(page: 1)

            #expect(!live.isFromCache)
            #expect(saved.isFromCache)
            #expect(saved.photos.map(\.id) == ["a", "b"])
        }

        @Test func exhaustedQuotaServesTheSavedPage() async throws {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in
                StubURLProtocol.requestCount == 1
                    ? .photos(ids: ["a"])
                    : .init(statusCode: 403, headers: ["X-Ratelimit-Remaining": "0"])
            })

            _ = try await client.photos(page: 1)
            let saved = try await client.photos(page: 1)

            #expect(saved.isFromCache)
            #expect(saved.photos.map(\.id) == ["a"])
        }

        @Test func onlineAlwaysPrefersTheNetwork() async throws {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in
                StubURLProtocol.requestCount == 1 ? .photos(ids: ["old"]) : .photos(ids: ["new"])
            })

            _ = try await client.photos(page: 1)
            let page = try await client.photos(page: 1)

            #expect(!page.isFromCache)
            #expect(page.photos.map(\.id) == ["new"])
        }

        @Test func offlineWithNothingSavedThrowsTheConnectionError() async {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in .init(failure: .notConnectedToInternet) })

            await #expect {
                try await client.photos(page: 1)
            } throws: { error in
                (error as? URLError)?.code == .notConnectedToInternet
            }
        }

        @Test func eachPageAndQueryIsSavedSeparately() async throws {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in
                StubURLProtocol.requestCount == 1 ? .photos(ids: ["a"]) : .init(failure: .notConnectedToInternet)
            })
            _ = try await client.photos(page: 1)

            await #expect(throws: URLError.self) {
                try await client.photos(page: 2)
            }
        }

        @Test func otherFailuresAreNotHiddenBySavedPages() async throws {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in
                StubURLProtocol.requestCount == 1 ? .photos(ids: ["a"]) : .init(statusCode: 500)
            })
            _ = try await client.photos(page: 1)

            await #expect {
                try await client.photos(page: 1)
            } throws: { error in
                guard case UnsplashError.http(statusCode: 500) = error else { return false }
                return true
            }
        }

        @Test func neverReadsFromTheSessionsOwnCache() async throws {
            let client = UnsplashClient.test(session: StubURLProtocol.stub { _ in .photos(ids: ["a"]) })

            _ = try await client.photos(page: 1)

            #expect(StubURLProtocol.lastRequest?.cachePolicy == .reloadIgnoringLocalCacheData)
        }
    }
}
