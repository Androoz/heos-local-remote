import SwiftUI

struct PlayerRemoteView: View {
    @ObservedObject var repository: PlayerRepository
    let player: HEOSPlayer
    @State private var showingGroupEditor = false

    private var state: PlayerState { repository.state(for: player.pid) }
    private var group: HEOSGroup? { repository.group(for: player.pid) }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                ArtworkView(urlString: state.imageURL, sourceKind: state.sourceKind, baseHost: repository.connectedAddress)
                    .frame(maxWidth: 320)

                VStack(spacing: 7) {
                    Text(state.displayTitle).font(.title2.bold()).multilineTextAlignment(.center).lineLimit(2)
                    if let artist = state.artist, !artist.isEmpty { Text(artist).font(.headline).foregroundStyle(.secondary) }
                    if let album = state.album, !album.isEmpty { Text(album).foregroundStyle(.tertiary).lineLimit(1) }
                }

                if state.sourceKind != .television && state.sourceKind != .auxiliary && state.sourceKind != .bluetooth {
                    PlaybackControls(
                        isPlaying: state.playState == .playing,
                        supportsSkipping: state.sourceKind.supportsSkipping,
                        previous: { repository.playPrevious(pid: player.pid) },
                        toggle: { repository.togglePlayback(pid: player.pid) },
                        next: { repository.playNext(pid: player.pid) }
                    )
                }

                VolumeControl(
                    volume: state.volume,
                    isMuted: state.isMuted,
                    setVolume: { repository.setVolume(pid: player.pid, level: $0) },
                    toggleMute: { repository.toggleMute(pid: player.pid) }
                )
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                Button {
                    showingGroupEditor = true
                } label: {
                    Label(group == nil ? L10n.string("Spela även i…") : L10n.string("Hantera grupp"), systemImage: "speaker.wave.2.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let group {
                    GroupControlView(repository: repository, group: group)
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { repository.refresh(pid: player.pid) }
        .sheet(isPresented: $showingGroupEditor) {
            GroupEditorView(repository: repository, leader: player)
        }
        .overlay(alignment: .bottom) {
            if let error = repository.lastError {
                ErrorBanner(message: error, onDismiss: repository.dismissError).padding()
            }
        }
    }
}

#Preview { NavigationStack { PlayerRemoteView(repository: PlayerRepository.preview, player: MockData.players[0]) } }
