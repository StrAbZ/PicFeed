import Testing
import UIKit
@testable import PicFeed

extension Stubbed {
    @MainActor
    @Suite struct ImageLoaderTests {
        @Test func concurrentRequestsForOneURLShareOneDownload() async throws {
            let url = try #require(URL(string: "https://images.test/a.jpg"))
            let loader = ImageLoader(session: StubURLProtocol.stub { _ in .image() })

            async let first = loader.image(for: url)
            async let second = loader.image(for: url)
            let images = try await [first, second]

            #expect(StubURLProtocol.requestCount == 1)
            #expect(images[0] === images[1])
        }

        @Test func secondRequestIsServedFromMemory() async throws {
            let url = try #require(URL(string: "https://images.test/a.jpg"))
            let loader = ImageLoader(session: StubURLProtocol.stub { _ in .image() })
            #expect(loader.cachedImage(for: url) == nil)

            let first = try await loader.image(for: url)
            let second = try await loader.image(for: url)

            #expect(StubURLProtocol.requestCount == 1)
            #expect(loader.cachedImage(for: url) === first)
            #expect(second === first)
        }

        @Test func differentURLsDownloadSeparately() async throws {
            let first = try #require(URL(string: "https://images.test/a.jpg"))
            let second = try #require(URL(string: "https://images.test/b.jpg"))
            let loader = ImageLoader(session: StubURLProtocol.stub { _ in .image() })

            _ = try await loader.image(for: first)
            _ = try await loader.image(for: second)

            #expect(StubURLProtocol.requestCount == 2)
        }

        @Test func failedDownloadThrowsIsNotCachedAndCanBeRetried() async throws {
            let url = try #require(URL(string: "https://images.test/a.jpg"))
            let loader = ImageLoader(session: StubURLProtocol.stub { _ in
                StubURLProtocol.requestCount == 1 ? .init(statusCode: 500) : .image()
            })

            await #expect(throws: ImageLoaderError.invalidResponse) {
                try await loader.image(for: url)
            }
            #expect(loader.cachedImage(for: url) == nil)

            _ = try await loader.image(for: url)
            #expect(StubURLProtocol.requestCount == 2)
            #expect(loader.cachedImage(for: url) != nil)
        }

        @Test func bytesThatAreNotAnImageThrow() async throws {
            let url = try #require(URL(string: "https://images.test/a.jpg"))
            let loader = ImageLoader(session: StubURLProtocol.stub { _ in
                .init(body: Data("not an image".utf8))
            })

            await #expect(throws: ImageLoaderError.invalidImageData) {
                try await loader.image(for: url)
            }
        }
    }
}
