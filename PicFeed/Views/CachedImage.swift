import SwiftUI

struct CachedImage: View {
    let url: URL

    @Environment(\.imageLoader) private var loader
    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loader.cachedImage(for: url) ?? loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .animation(.easeIn(duration: 0.2), value: loadedImage)
        .task(id: url) {
            loadedImage = try? await loader.image(for: url)
        }
    }
}
