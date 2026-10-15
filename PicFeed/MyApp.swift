import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            FeedView(client: UnsplashClient(accessKey: Secrets.unsplashAccessKey))
        }
    }
}
