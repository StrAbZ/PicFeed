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

    private let perPage = 30
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func photos(page: Int) async throws -> PhotoPage {
        let data = try await get("/photos", query: pageQuery(page))
        let photos = try decoder.decode([Photo].self, from: data)
        return PhotoPage(photos: photos, totalPages: nil)
    }

    func search(query: String, page: Int) async throws -> PhotoPage {
        let items = [URLQueryItem(name: "query", value: query)] + pageQuery(page)
        let data = try await get("/search/photos", query: items)
        let response = try decoder.decode(SearchResponse.self, from: data)
        return PhotoPage(photos: response.results, totalPages: response.totalPages)
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

    private func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard !accessKey.isEmpty else { throw UnsplashError.missingAccessKey }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.unsplash.com"
        components.path = path
        components.queryItems = query

        guard let url = components.url else { throw UnsplashError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UnsplashError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            return data
        case 403 where http.value(forHTTPHeaderField: "X-Ratelimit-Remaining") == "0":
            throw UnsplashError.rateLimited
        default:
            throw UnsplashError.http(statusCode: http.statusCode)
        }
    }
}
