import UIKit

nonisolated enum ImageLoaderError: Error, Equatable {
    case invalidResponse
    case invalidImageData
}

final class ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let memoryCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init(session: URLSession = .shared, memoryLimit: Int = 64 * 1024 * 1024) {
        self.session = session
        memoryCache.totalCostLimit = memoryLimit
    }

    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cachedImage(for: url) {
            return cached
        }
        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task { try await load(url) }
        inFlight[url] = task
        return try await task.value
    }

    private func load(_ url: URL) async throws -> UIImage {
        defer { inFlight[url] = nil }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImageLoaderError.invalidResponse
        }
        // Decoded off the main thread, so drawing the image later is cheap.
        guard let image = await UIImage(data: data)?.byPreparingForDisplay() else {
            throw ImageLoaderError.invalidImageData
        }

        memoryCache.setObject(image, forKey: url as NSURL, cost: image.decodedByteCount)
        return image
    }
}

private extension UIImage {
    var decodedByteCount: Int {
        cgImage.map { $0.bytesPerRow * $0.height } ?? 0
    }
}
