import Foundation

@MainActor
struct PlayerRemoteViewModel {
    let repository: PlayerRepository
    let player: HEOSPlayer
    var state: PlayerState { repository.state(for: player.pid) }
    func togglePlayback() { repository.togglePlayback(pid: player.pid) }
    func previous() { repository.playPrevious(pid: player.pid) }
    func next() { repository.playNext(pid: player.pid) }
    func toggleMute() { repository.toggleMute(pid: player.pid) }
    func volume(_ level: Int) { repository.setVolume(pid: player.pid, level: level) }
}
