import Foundation

nonisolated enum UnsplashError: LocalizedError {
    case missingAccessKey
    case rateLimited
    case http(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAccessKey:
            "Unsplash access key is missing. See the README for setup."
        case .rateLimited:
            "Unsplash rate limit reached (50 requests/hour). Try again later."
        case .http(let statusCode):
            "Unsplash request failed (HTTP \(statusCode))."
        case .invalidResponse:
            "Unexpected response from Unsplash."
        }
    }
}

nonisolated struct UnsplashClient: Sendable {
    var accessKey: String
    var session: URLSession = .shared
    var cache: URLCache = .api

    private let perPage = 30
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func photos(page: Int) async throws -> PhotoPage {
        let (data, isFromCache) = try await get("/photos", query: pageQuery(page))
        let photos = try decoder.decode([Photo].self, from: data)
        return PhotoPage(photos: photos, totalPages: nil, isFromCache: isFromCache)
    }

    func search(query: String, page: Int) async throws -> PhotoPage {
        let items = [URLQueryItem(name: "query", value: query)] + pageQuery(page)
        let (data, isFromCache) = try await get("/search/photos", query: items)
        let response = try decoder.decode(SearchResponse.self, from: data)
        return PhotoPage(photos: response.results, totalPages: response.totalPages, isFromCache: isFromCache)
    }

    // MARK: - Private

    private struct SearchResponse: Decodable {
        let totalPages: Int
        let results: [Photo]
    }

    private func pageQuery(_ page: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
    }

    /// Every successful response is saved. When the network can't be reached, or the quota is
    /// used up, the saved copy of the same request is served instead, if there is one.
    private func get(_ path: String, query: [URLQueryItem]) async throws -> (data: Data, isFromCache: Bool) {
        guard !accessKey.isEmpty else { throw UnsplashError.missingAccessKey }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.unsplash.com"
        components.path = path
        components.queryItems = query

        guard let url = components.url else { throw UnsplashError.invalidResponse }

        // The saved copy below is the only cache, so a response is either live or marked as saved.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        do {
            return (try await fetch(request), false)
        } catch where canServeSavedCopy(after: error) {
            guard let saved = cache.cachedResponse(for: request) else { throw error }
            return (saved.data, true)
        }
    }

    private func fetch(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UnsplashError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            cache.storeCachedResponse(CachedURLResponse(response: http, data: data), for: request)
            return data
        case 403 where http.value(forHTTPHeaderField: "X-Ratelimit-Remaining") == "0":
            throw UnsplashError.rateLimited
        default:
            throw UnsplashError.http(statusCode: http.statusCode)
        }
    }

    private func canServeSavedCopy(after error: Error) -> Bool {
        if case UnsplashError.rateLimited = error { return true }
        guard let urlError = error as? URLError else { return false }
        return urlError.code != .cancelled
    }
}

extension URLCache {
    nonisolated static let api = URLCache(memoryCapacity: 0,
                                          diskCapacity: 10_000_000,
                                          directory: .cachesDirectory.appending(path: "API"))
}
