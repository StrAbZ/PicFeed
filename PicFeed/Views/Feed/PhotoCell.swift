import SwiftUI

struct PhotoCell: View {
    let photo: Photo
    let namespace: Namespace.ID
    let isSelected: Bool
    let isSource: Bool

    var body: some View {
        PhotoCard(photo: photo)
            .matchedGeometryEffect(id: photo.id, in: namespace, isSource: isSource)
            .opacity(isSelected ? 0 : 1)
    }
}
