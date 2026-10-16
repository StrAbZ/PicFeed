import Foundation
@testable import PicFeed

extension UnsplashClient {
    /// Saves responses in memory, so tests neither write to nor depend on the app's disk cache.
    static func test(accessKey: String = "test", session: URLSession) -> UnsplashClient {
        UnsplashClient(accessKey: accessKey,
                       session: session,
                       cache: URLCache(memoryCapacity: 1_000_000, diskCapacity: 0))
    }
}
