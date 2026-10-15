import Foundation
@testable import PicFeed

extension Photo {
    static func stub(id: String = "id",
                     description: String? = nil,
                     altDescription: String? = nil,
                     width: Int = 300,
                     height: Int = 200) -> Photo {
        let url = URL(filePath: "/image.jpg")
        return Photo(id: id,
                     description: description,
                     altDescription: altDescription,
                     width: width,
                     height: height,
                     blurHash: nil,
                     color: nil,
                     urls: URLs(raw: url, full: url, regular: url, small: url, thumb: url))
    }
}
