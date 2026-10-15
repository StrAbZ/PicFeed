import SwiftUI

struct PhotoDetailView: View {
    let photo: Photo
    let namespace: Namespace.ID
    @Binding var isExpanded: Bool
    let onDismiss: () -> Void

    static let animation = Animation.spring(duration: 0.2, bounce: 0.15)

    @Environment(\.imageLoader) private var loader
    @State private var showsFullImage = false
    @State private var isUIHidden = false
    @State private var dragOffset = CGSize.zero

    private var dragProgress: Double {
        1 - min(abs(dragOffset.height) / 300, 1)
    }

    private var controlsOpacity: Double {
        isExpanded && !isUIHidden ? dragProgress : 0
    }

    private var cornerRadius: Double {
        isExpanded ? (1 - dragProgress) * 36 : 12
    }

    var body: some View {
        content
            .overlay(alignment: .top) {
                if isExpanded && !isUIHidden {
                    closeControl
                        .opacity(dragProgress)
                        .transition(.opacity)
                }
            }
    }

    private var content: some View {
        ZStack {
            backdrop
                .contentShape(Rectangle())
                .onTapGesture(perform: toggleUI)
                .allowsHitTesting(isExpanded)

            image
                .matchedGeometryEffect(id: photo.id, in: namespace, isSource: isExpanded)
                .shadow(color: .black.opacity(isExpanded ? 0.45 : 0), radius: 28, y: 14)
                .scaleEffect(0.85 + 0.15 * dragProgress)
                .offset(dragOffset)
                .onTapGesture { isExpanded ? toggleUI() : expand() }
                .gesture(dismissGesture, isEnabled: isExpanded)
        }
        .overlay(alignment: .bottom) { caption }
        .statusBarHidden(isUIHidden)
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
        .onAppear(perform: expand)
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            (Color(hex: photo.color) ?? .clear).opacity(0.3)
        }
        .opacity(isExpanded ? dragProgress : 0)
        .ignoresSafeArea()
    }

    private var image: some View {
        let isFullImageCached = loader.cachedImage(for: photo.urls.regular) != nil

        return ZStack {
            Color(hex: photo.color) ?? Color(.secondarySystemFill)
            CachedImage(url: photo.urls.thumb)
            CachedImage(url: photo.urls.regular)
                .opacity(showsFullImage || isFullImageCached ? 1 : 0)
        }
        .aspectRatio(photo.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var closeControl: some View {
        if #available(iOS 26, *) {
            NavigationStack {
                Color.clear
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .close, action: dismiss)
                        }
                    }
                    .containerBackground(.clear, for: .navigation)
            }
            .frame(height: 120)
        } else {
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        }
    }

    @ViewBuilder
    private var caption: some View {
        if let caption = photo.caption {
            Text(caption)
                .font(.callout)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 24)
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.6)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
                .opacity(controlsOpacity)
                .offset(y: isExpanded ? 0 : 24)
                .animation(Self.animation.delay(0.1), value: isExpanded)
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if abs(value.translation.height) > 120 || abs(value.predictedEndTranslation.height) > 300 {
                    dismiss()
                } else {
                    withAnimation(Self.animation) { dragOffset = .zero }
                }
            }
    }

    private func toggleUI() {
        withAnimation(.easeInOut(duration: 0.25)) { isUIHidden.toggle() }
    }

    private func expand() {
        withAnimation(Self.animation, completionCriteria: .removed) {
            isExpanded = true
        } completion: {
            withAnimation(.easeIn(duration: 0.25)) { showsFullImage = true }
        }
    }

    private func dismiss() {
        withAnimation(Self.animation, completionCriteria: .removed) {
            isExpanded = false
            dragOffset = .zero
        } completion: {
            onDismiss()
        }
    }
}
