// Copy this file to PicFeed/Secrets.swift (gitignored) and paste your Unsplash access key.
//
//   cp Secrets.example.swift PicFeed/Secrets.swift

enum Secrets {
    static let unsplashAccessKey = "YOUR_UNSPLASH_ACCESS_KEY"

    /// Serve the recorded responses in Fixtures/ instead of calling the API.
    static let useFixtures = false
}
