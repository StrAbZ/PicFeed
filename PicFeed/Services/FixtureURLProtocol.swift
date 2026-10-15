import Foundation

/// Serves the recorded JSON in `Fixtures/` instead of hitting the Unsplash API.
/// Pages past the recorded ones come back empty. The search query is ignored.
nonisolated final class FixtureURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url,
                                             statusCode: 200,
                                             httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let isSearch = url.path == "/search/photos"
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "page" }?.value ?? "1"
        let name = "\(isSearch ? "search" : "photos")-page-\(page)"

        let data = Bundle.main.url(forResource: name, withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            ?? Data((isSearch ? #"{"total_pages":0,"results":[]}"# : "[]").utf8)

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    static let fixtures: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return URLSession(configuration: configuration)
    }()
}
