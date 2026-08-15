import SwiftUI

struct PlayerListView: View {
    @ObservedObject var repository: PlayerRepository
    @State private var showingAddressSettings = false

    private var groupedPlayerIDs: Set<String> {
        repository.groups.reduce(into: []) { $0.formUnion($1.playerIDs) }
    }

    private var ungroupedPlayers: [HEOSPlayer] {
        repository.players.filter { !groupedPlayerIDs.contains($0.pid) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if repository.isLoadingPlayers && repository.players.isEmpty {
                    ProgressView("Hämtar HEOS-spelare…")
                } else if repository.players.isEmpty {
                    ContentUnavailableView("Inga HEOS-spelare hittades", systemImage: "hifispeaker.slash", description: Text("Kontrollera att spelarna är påslagna och uppdatera listan."))
                } else {
                    List {
                        ForEach(repository.groups) { group in
                            GroupRoomCard(repository: repository, group: group)
                                .roomListRowStyle()
                        }
                        ForEach(ungroupedPlayers) { player in
                            PlayerRoomCard(repository: repository, player: player)
                                .roomListRowStyle()
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { repository.refreshAll() }
                }
            }
            .navigationTitle("Rum")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ConnectionStatusView(state: repository.connectionState, compact: true)
                    Button("Uppdatera", systemImage: "arrow.clockwise") { repository.refreshAll() }
                    Menu {
                        Button("Sök efter HEOS-enheter", systemImage: "dot.radiowaves.left.and.right") { repository.searchForDevices() }
                        Button("Byt HEOS-adress…", systemImage: "network") { showingAddressSettings = true }
                        Button("Koppla från", systemImage: "xmark.circle", role: .destructive) { repository.disconnect() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showingAddressSettings) {
                ControllerAddressView(repository: repository)
            }
            .overlay(alignment: .bottom) {
                if let error = repository.lastError {
                    ErrorBanner(message: error, onDismiss: repository.dismissError).padding()
                }
            }
        }
    }
}

private struct PlayerRoomCard: View {
    @ObservedObject var repository: PlayerRepository
    let player: HEOSPlayer

    private var state: PlayerState { repository.state(for: player.pid) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink {
                    PlayerRemoteView(repository: repository, player: player)
                        .onAppear { repository.selectedPlayerID = player.pid }
                } label: {
                    RoomSummary(
                        title: player.name,
                        state: state,
                        symbol: state.sourceKind == .unknown ? "hifispeaker.fill" : state.sourceKind.systemImage,
                        isGroup: false
                    )
                }
                .buttonStyle(.plain)

                QuickPlayButton(state: state.playState) { repository.togglePlayback(pid: player.pid) }
            }

            Divider()
            CompactVolumeControl(
                volume: state.volume,
                isMuted: state.isMuted,
                setVolume: { repository.setVolume(pid: player.pid, level: $0) },
                toggleMute: { repository.toggleMute(pid: player.pid) }
            )
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct GroupRoomCard: View {
    @ObservedObject var repository: PlayerRepository
    let group: HEOSGroup

    private var leaderPID: String? { group.leaderPID }
    private var leader: HEOSPlayer? {
        guard let leaderPID else { return nil }
        return repository.players.first { $0.pid == leaderPID }
    }
    private var state: PlayerState {
        leaderPID.map { repository.state(for: $0) } ?? PlayerState(pid: "")
    }
    private var averageVolume: Int {
        guard !group.players.isEmpty else { return 0 }
        return group.players.map { repository.state(for: $0.pid).volume }.reduce(0, +) / group.players.count
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let leader {
                    NavigationLink {
                        PlayerRemoteView(repository: repository, player: leader)
                            .onAppear { repository.selectedPlayerID = leader.pid }
                    } label: { summary }
                        .buttonStyle(.plain)
                } else {
                    summary
                }

                if let leaderPID {
                    QuickPlayButton(state: state.playState) { repository.togglePlayback(pid: leaderPID) }
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Samma volym i alla rum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                CompactVolumeControl(
                    volume: repository.groupVolumes[group.gid] ?? averageVolume,
                    isMuted: repository.groupMutes[group.gid] ?? false,
                    sendsWhileEditing: false,
                    setVolume: { repository.setUniformGroupVolume(group, level: $0) },
                    toggleMute: { repository.toggleGroupMute(gid: group.gid) }
                )
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
    }

    private var summary: some View {
        RoomSummary(title: group.displayName, state: state, symbol: "speaker.wave.3.fill", isGroup: true)
    }
}

private struct RoomSummary: View {
    let title: String
    let state: PlayerState
    let symbol: String
    let isGroup: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(state.playState == .playing ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isGroup || state.playState == .playing ? Color.accentColor : .secondary)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).lineLimit(2)
                Text(state.displayTitle).lineLimit(1)
                if let artist = state.artist, !artist.isEmpty {
                    Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
        }
        .contentShape(Rectangle())
    }
}

private struct QuickPlayButton: View {
    let state: HEOSPlayState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: state == .playing ? "pause.fill" : "play.fill")
                .font(.headline)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(state == .playing ? L10n.string("Pausa") : L10n.string("Spela"))
    }
}

private extension View {
    func roomListRowStyle() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
    }
}

#Preview { PlayerListView(repository: PlayerRepository.preview) }
