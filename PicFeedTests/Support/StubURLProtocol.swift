import Testing
import UIKit
import Foundation

/// Answers every request from `handler`. It holds global state, so the tests that use it
/// live in the `Stubbed` suite, which runs serially.
nonisolated final class StubURLProtocol: URLProtocol {
    struct Reply {
        var statusCode = 200
        var headers: [String: String] = [:]
        var body = Data()
        /// The request stays open until it is cancelled.
        var neverCompletes = false
        /// The request fails like a connection error, without any response.
        var failure: URLError.Code?
    }

    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) -> Reply)?
    nonisolated(unsafe) private(set) static var requestCount = 0
    nonisolated(unsafe) private(set) static var cancelledCount = 0
    nonisolated(unsafe) private(set) static var lastRequest: URLRequest?
    private var neverCompletes = false

    static func stub(_ handler: @escaping @Sendable (URLRequest) -> Reply) -> URLSession {
        self.handler = handler
        requestCount = 0
        cancelledCount = 0
        lastRequest = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        Self.lastRequest = request
        if let failure = Self.handler?(request).failure {
            client?.urlProtocol(self, didFailWithError: URLError(failure))
            return
        }
        guard let url = request.url,
              let reply = Self.handler?(request),
              let response = HTTPURLResponse(url: url,
                                             statusCode: reply.statusCode,
                                             httpVersion: nil,
                                             headerFields: reply.headers)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if reply.neverCompletes {
            neverCompletes = true
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        if neverCompletes { Self.cancelledCount += 1 }
    }
}

/// Parent of every suite that uses `StubURLProtocol`: nested suites inherit `.serialized`.
@Suite(.serialized) enum Stubbed {}

extension StubURLProtocol.Reply {
    static func photos(ids: [String]) -> Self {
        let photos = ids.map { id -> [String: Any] in
            let url = "https://images.unsplash.com/\(id)"
            return ["id": id,
                    "width": 300,
                    "height": 200,
                    "urls": ["raw": url, "full": url, "regular": url, "small": url, "thumb": url]]
        }
        let body = (try? JSONSerialization.data(withJSONObject: photos)) ?? Data()
        return Self(body: body)
    }
}

extension URLRequest {
    var page: Int {
        guard let url,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "page" })?.value
        else { return 1 }
        return Int(value) ?? 1
    }
}

extension StubURLProtocol.Reply {
    static func image() -> Self {
        let size = CGSize(width: 8, height: 8)
        let data = UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return Self(body: data)
    }
}
