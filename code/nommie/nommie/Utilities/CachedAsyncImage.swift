import SwiftUI

// Shared in-memory image cache. Survives view lifecycle but not app restarts.
// URLCache (configured in nommieApp.swift) handles disk persistence.
final class NommieImageCache {
    static let shared = NommieImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 50_000_000 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
}

// Drop-in replacement for AsyncImage that caches UIImages in NSCache.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil
    @State private var task: Task<Void, Never>? = nil

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let img = uiImage {
                content(Image(uiImage: img))
            } else {
                placeholder()
            }
        }
        .onAppear { load() }
        .onDisappear { task?.cancel() }
        .onChange(of: url) { load() }
    }

    private func load() {
        guard let url else { return }
        if let cached = NommieImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }
        task?.cancel()
        task = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let img = UIImage(data: data) else { return }
                NommieImageCache.shared.setImage(img, for: url)
                await MainActor.run { uiImage = img }
            } catch {}
        }
    }
}
