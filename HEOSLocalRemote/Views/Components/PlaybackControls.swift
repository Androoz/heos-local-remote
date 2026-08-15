import SwiftUI

struct PlaybackControls: View {
    let isPlaying: Bool
    let supportsSkipping: Bool
    let previous: () -> Void
    let toggle: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 38) {
            Button(action: previous) { Image(systemName: "backward.fill") }
                .accessibilityLabel("Föregående")
                .disabled(!supportsSkipping)
            Button(action: toggle) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
            }
            .accessibilityLabel(isPlaying ? L10n.string("Pausa") : L10n.string("Spela"))
            Button(action: next) { Image(systemName: "forward.fill") }
                .accessibilityLabel("Nästa")
                .disabled(!supportsSkipping)
        }
        .font(.system(size: 28))
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
