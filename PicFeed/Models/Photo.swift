import CoreGraphics
import Foundation

nonisolated struct Photo: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let description: String?
    let altDescription: String?
    let width: Int
    let height: Int
    let blurHash: String?
    let color: String?
    let urls: URLs

    struct URLs: Hashable, Sendable, Decodable {
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
        let thumb: URL
    }

    var caption: String? {
        [altDescription, description]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    var aspectRatio: CGFloat {
        height > 0 ? CGFloat(width) / CGFloat(height) : 1
    }
}

/// One page of results. `totalPages` is only known for search.
nonisolated struct PhotoPage: Sendable {
    let photos: [Photo]
    let totalPages: Int?
}
