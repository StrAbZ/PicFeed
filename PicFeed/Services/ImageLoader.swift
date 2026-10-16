import UIKit

nonisolated enum ImageLoaderError: Error, Equatable {
    case invalidResponse
    case invalidImageData
}

private struct Download {
    let task: Task<UIImage, Error>
    var waiters = 0
}

final class ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let memoryCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Download] = [:]

    init(session: URLSession = .images, memoryLimit: Int = 64 * 1024 * 1024) {
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

        var download = inFlight[url] ?? Download(task: Task { try await load(url) })
        download.waiters += 1
        inFlight[url] = download
        let task = download.task

        defer {
            if inFlight[url]?.task == task { inFlight[url] = nil }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { @MainActor in self.leave(url, task) }
        }
    }

    /// A waiter was cancelled. The download is cancelled with its last waiter, so scrolling
    /// past a cell stops its download, unless another cell (or a prefetch) still wants it.
    private func leave(_ url: URL, _ task: Task<UIImage, Error>) {
        guard var download = inFlight[url], download.task == task else { return }
        download.waiters -= 1
        if download.waiters == 0 {
            task.cancel()
            inFlight[url] = nil
        } else {
            inFlight[url] = download
        }
    }

    private func load(_ url: URL) async throws -> UIImage {
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

extension URLSession {
    nonisolated static let images: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: 0,
                                          diskCapacity: 200 * 1024 * 1024,
                                          directory: .cachesDirectory.appending(path: "Images"))
        return URLSession(configuration: configuration)
    }()
}
