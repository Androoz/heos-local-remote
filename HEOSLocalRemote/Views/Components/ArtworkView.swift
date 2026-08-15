import SwiftUI

struct ArtworkView: View {
    let urlString: String?
    let sourceKind: PlaybackSourceKind
    let baseHost: String?

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: placeholder
                    default: ZStack { placeholder; ProgressView() }
                    }
                }
            } else { placeholder }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 7)
    }

    private var resolvedURL: URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if let url = URL(string: urlString), url.scheme != nil { return url }
        guard let baseHost, let base = URL(string: "http://\(baseHost)") else { return nil }
        return URL(string: urlString, relativeTo: base)?.absoluteURL
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.92), .gray.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                Image(systemName: sourceKind.systemImage).font(.system(size: 68)).foregroundStyle(.white.opacity(0.92))
                if sourceKind != .unknown { Text(sourceKind.label).font(.headline).foregroundStyle(.white.opacity(0.82)) }
            }
        }
    }
}
