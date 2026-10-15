import Testing
@testable import PicFeed

struct UnsplashClientTests {
    private let fixtures = UnsplashClient(accessKey: "test", session: .fixtures)

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
        let client = UnsplashClient(accessKey: "", session: .fixtures)

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
            let client = UnsplashClient(accessKey: "test", session: session)

            await #expect {
                try await client.photos(page: 1)
            } throws: { error in
                guard case UnsplashError.rateLimited = error else { return false }
                return true
            }
        }

        @Test func otherFailuresCarryTheStatusCode() async {
            let session = StubURLProtocol.stub { _ in .init(statusCode: 500) }
            let client = UnsplashClient(accessKey: "test", session: session)

            await #expect {
                try await client.photos(page: 1)
            } throws: { error in
                guard case UnsplashError.http(statusCode: 500) = error else { return false }
                return true
            }
        }
    }
}
