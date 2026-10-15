import SwiftUI

@main struct MyApp: App {
    private let client = Secrets.useFixtures
        ? UnsplashClient(accessKey: "fixtures", session: .fixtures)
        : UnsplashClient(accessKey: Secrets.unsplashAccessKey)

    var body: some Scene {
        WindowGroup {
            FeedView(client: client)
        }
    }
}
