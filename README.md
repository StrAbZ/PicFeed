# PicFeed

An Unsplash photo browser for iOS 17+, built with SwiftUI and no third-party dependencies: an endless masonry feed of the Editorial photos, search, and a full-screen viewer with a hero transition.

## Setup

Built with Xcode 27, deployment target iOS 17.

The Unsplash access key is not in the repository. The project reads it from `PicFeed/Secrets.swift`.
The file is gitignored, and is required for the app to compile:

```sh
cp Secrets.example.swift PicFeed/Secrets.swift
```

Then edit `PicFeed/Secrets.swift`:

```swift
enum Secrets {
    static let unsplashAccessKey = "YOUR_UNSPLASH_ACCESS_KEY"   // paste your key here
    static let useFixtures = false
}
```

### Running without a key

Since the free limit of Unsplash is 50 requests per hour, in order to be able to test without issue, I built a small fixture mode.
Set `useFixtures = true` and the app serves recorded API responses from `PicFeed/Fixtures/` instead of calling Unsplash: 15 pages of the feed (430 photos) and 3 pages of search results for "nature". The photos themselves are still downloaded from the Unsplash CDN, which doesn't count against the API limit. This is also what I used for profiling, so that results are repeatable and don't burn the quota.

### Tests

Run the `PicFeed` scheme's tests with ⌘U. They need no key and no network.


## Architecture
`UnsplashClient` fetches pages, `PhotoFeed` (an `@Observable` store) owns the pagination, and the views display it. No view models: the store is already the state, and the views only keep `@State` for UI things like the selected photo. I didn't put a protocol on the client either, it would have a single implementation. The tests stub the network with a `URLProtocol`, working on a real `URLSession`.

`PhotoFeed` removes duplicate photos (a page can repeat one from the previous page), stops on the last page, and doesn't retry by itself after an error. A bad connection shouldn't eat the 50 requests per hour.

### Search

Search runs on submit, not on every keystroke, for the same quota reason. Each search gets its own `PhotoFeed`. The editorial feed stays alive, so leaving the search brings it back instantly without a new request. One caveat: It starts at the top of the feed again, because the grid is rebuilt. To avoid that we could store the top visible photo of the `PhotoFeed`, and scroll back to it when the grid reappears. I think a production app could require that search don't disrupt browsing, so search result could be presented in their own screen in another tab or over the feed.

### Grid

It's a masonry: two `LazyVStack` columns in one `ScrollView`, each photo going to the shortest column based on its aspect ratio. A custom `Layout` could be cleaner but it isn't lazy, and with hundreds of photos that matters more. The captions are drawn on the picture rather than under it, so a cell's height only depends on the aspect ratio.

To avoid useless updates, the loading and error state live in their own view (`FeedFooter`) so a page loading doesn't re-evaluate the grid, and the cells only get plain values, they don't observe the store.

I checked it with the SwiftUI instrument, scrolling through all 430 photos, then opening and closing one. Over the whole run `PhotoGrid` updated 24 times (one per page, plus the selection changes) at 0.24 ms on average, and `FeedFooter` 33 times, so the loading state doesn't reach the grid. Opening and closing a photo is four updates of `FeedView`, `PhotoGrid` and the detail view (one per state change), and only four of `PhotoCell`: the selected cell, not the visible ones. With everything loaded, one grid update costs about 1 ms.

A photo with neither `alt_description` nor `description` shows no caption. That's on purpose: a "No description" label repeated on the grid is noise, the picture is what matters. That would be a nice discussion to have with design and product team. I leaned toward not showing a placeholder.

### Other choices

- Swift 6 language mode. The app target is main-actor by default, and what works off the main thread (models, client) is `nonisolated`.
- No third-party library.

## Image pipeline

I started with `AsyncImage` and profiled it, scrolling through the whole feed (429 photos). It made 817 network loads, so about 390 calls were repeats. Before iOS 27 `AsyncImage` doesn't cache what it downloads, so a cell coming back on screen loads its image again. iOS 27 adds caching, but the target is iOS 17 and I would still have needed my own loader, so I didn't want to keep both.

`ImageLoader` replaces it, with `CachedImage` as the view on top:

- A memory cache of decoded images (`NSCache`, 64 MB). The lookup is synchronous, so a cached image is there on the first frame of the cell. That's the reason `ImageLoader` is a main-actor class and not an `actor`: with an actor every lookup would be `async` and cells could flash empty. The download and the decoding are still off the main thread.
- One download per URL. If the cell, the detail view and the prefetcher want the same image, they share it.
- A disk cache: a separate `URLSession` with a 200 MB `URLCache` that keeps the compressed files. The memory cache stays small, the disk holds most of the feed.
- Cancellation. When a cell scrolls away its request is cancelled, unless someone else is still waiting for the same image.
- Prefetching. When a cell appears, the thumbnails of the next 10 photos start loading. Nobody cancels a prefetch, so a cell leaving doesn't stop it.

I use the URLs as Unsplash returns them, parameters untouched. The grid uses `thumb` (200 px wide) and the full screen uses `regular` (1080 px), shown on top of the thumbnail that's already there. `thumb` looks fine to me on the phones I tried. `small` would be sharper for 2 to 3 times the bytes.

### Measurements

All on a real device with the fixtures, same scroll through the whole feed.

| | `AsyncImage` | memory + one download per URL + disk | + cancellation + prefetch |
|---|---|---|---|
| Image tasks | 851 | 495 | 503 |
| Network loads (429 photos) | 817 | 429 | 429 |
| Disk cache hits | 34 | 66 | 74 |
| Hitches | 7 in 72 s | not measured | 3 in 37 s |
| Memory at the end (iPhone 13 Pro) | about 14 MiB | not measured | about 44 MiB |

Hitches: while scrolling there are two dropped frames (12.5 ms each). The only big one, 167 ms, is at launch, in the first frame. In Instruments our own view bodies take 1.6 ms of the 66 ms of SwiftUI updates at that moment, the rest is SwiftUI and UIKit (navigation bar, search, glass), so I left it. Duration of the runs are not identical, so hitches are more indicative than comparable.

Memory goes from 14 to 44 MiB because we keep decoded thumbnails now (27 MiB, under the 64 MB cap) and `AsyncImage` dropped them as soon as a cell left the screen. On an iPhone 12 mini it ends at 66 MiB. The images are the same 27 MiB. My guess is the rows `LazyVStack` keeps, but I didn't check.

The network trace shows the cancellation working: some photos have a request and no response.

### Tests

`ImageLoaderTests` covers what could break without anyone noticing: two requests for the same URL share one download, the second one is served from memory, a failed download isn't cached and can be retried, data that isn't an image throws, cancelling the only waiter cancels the request but cancelling one of two doesn't, and a prefetch is reused and survives a cell leaving.

## Offline

I wanted to be able to browse what was already loaded without writing a database for it, so there are only the two caches.

The images are in the disk cache already, and a cached image is served even without a connection. For the data, `UnsplashClient` saves every successful response in a small disk `URLCache` (10 MB), under the request URL, so each page and each search query is kept separately. It always asks the network first (the requests ignore the `URLSession` cache, otherwise a response could come from it without the app knowing, and the saved-photos label would never show). If that fails with a connection error, or the quota is used up, it serves the saved copy of the same request, if there is one. Otherwise the error is thrown as before. 

The feed shows "Showing saved photos" as soon as one of its pages came from the saved copy. It stays on for that feed, so it doesn't flicker when the connection comes and goes. With nothing to show, there's an empty state with a retry button.

Since it only serves what's been loaded before, a first launch with no connection shows the empty state. To try it: run once online, then turn on airplane mode and relaunch. With `useFixtures = true` the API never fails, so it can't be tried this way, the unit tests cover it.

## Full screen

Tapping a photo makes it grow from its cell to full screen, and it goes back the same way. Tap to hide or show the close button and the caption, drag down to dismiss.

SwiftUI has no custom push transition on iOS 17. `.navigationTransition(.zoom)` does this natively but it's iOS 18. I tried a second `NavigationStack` for the detail and the geometry broke (the image started from the side of the screen), so I dropped it. What's left is an overlay on top of the feed, animated with `matchedGeometryEffect`. UIKit would give full control (a custom presentation and an interactive dismissal), but it's a lot more code, so I stayed in SwiftUI.

On iOS 26 the captions and the close button use Liquid Glass. Before that they fall back to a material (`.ultraThinMaterial`). That's `glassBackground()` and `CloseControl`.

There are no UI tests for this part. 

## Trade-offs and what's missing

- **Memory of the feed itself.** The image cache is capped, but `LazyVStack` doesn't reuse cells, so the memory of the view hierarchy grows with how far you scroll. It's fine for a few hundred photos (see the measurements). For a feed that really never ends I'd move the grid to a `UICollectionView` with cell reuse, wrapped for SwiftUI. That would be the case where UIKit is justified.
- **Prefetching is simple.** It looks 10 photos ahead in feed order. At a page change the first photos of the new page aren't prefetched, they load when their cells appear.
- **Disk cache.** 200 MB, and `URLCache` decides what to evict. No expiry and no way to clear it from the app.
- **Search** only runs on submit, so no live results. That's the price of the 50 requests per hour.
- **Offline** is only what you already browsed. There's no store of my own, just the two caches, so there's no expiry and a search you never ran has nothing to show.
- **Full screen.** No pinch to zoom. 
- **Layout.** iPhone only, two columns, portrait was the only thing I checked. No iPad or landscape work.
- **Localization and accessibility.** Not done. The UI strings are plain SwiftUI literals, so a String Catalog can be added, but the captions come from the API in English anyway. For accessibility the next steps would be VoiceOver labels on the cells and the full-screen view, and a simpler transition when Reduce Motion is on.
- **API key.** It's a gitignored Swift file, so the project doesn't compile until you create it. 
- **Tested** on an iPhone 13 Pro and an iPhone 12 mini, and the unit tests in the simulator. I didn't test iOS 17 on a real device, so the material fallbacks are only checked by build.

## How I used AI

I used Claude Code, step by step. Most of the design came out of a discussion with it: the masonry, search on submit only, the hero transition and the image pipeline were options we talked through, and I kept the ones that fit the brief and the size of a take home. I reviewed and committed every step myself, so the git history is the review history.

My part was mostly judgment on scope and proof:

- **Cutting what was too much.** I turned down a closure-based client, protocols with a single implementation, extra actors, files and nested types, and comments that repeat the code. Several proposals were sound in general but more than this assignment needed. I also ask it to follow my coding style (we all have preferences :)).
- **Tests that mean something.** Tests first for the image pipeline. I deleted one that only checked a constant, and decided against UI tests, which I judged too much for a take home.
- **Measuring before building.** I profiled the `AsyncImage` baseline first and ran Instruments on the device myself. The numbers decided what to build (the duplicate downloads, so a cache and one download per URL) and what not to (no downsampling, memory wasn't a problem). Cancellation and prefetching came last, with a baseline to compare against.
- **The transition.** I rejected the approaches that didn't feel right (`scrollDisabled` during a dismissal, the nested `NavigationStack` that broke the geometry) and tuned the spring and the timings by hand on the device.

What it did: wrote the first version of most of the code and the tests, a throwaway script to record the fixtures. I also used it to read instruments results, providing it screenshots, my assumptions and possible solutions.
