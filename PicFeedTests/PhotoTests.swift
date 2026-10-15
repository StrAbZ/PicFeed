import CoreGraphics
import Testing
@testable import PicFeed

struct PhotoTests {
    @Test func captionPrefersAltDescription() {
        let photo = Photo.stub(description: "description", altDescription: "alt")
        #expect(photo.caption == "alt")
    }

    @Test func captionFallsBackToDescription() {
        let photo = Photo.stub(description: "description", altDescription: nil)
        #expect(photo.caption == "description")
    }

    @Test func captionIsNilWithoutAnyDescription() {
        #expect(Photo.stub().caption == nil)
    }

    @Test func blankDescriptionsAreIgnored() {
        #expect(Photo.stub(description: "description", altDescription: "  \n").caption == "description")
        #expect(Photo.stub(description: " ", altDescription: "").caption == nil)
    }

    @Test func aspectRatioIsWidthOverHeight() {
        #expect(Photo.stub(width: 300, height: 200).aspectRatio == 1.5)
    }

    @Test func aspectRatioDefaultsToSquareWithoutHeight() {
        #expect(Photo.stub(width: 300, height: 0).aspectRatio == 1)
    }
}
