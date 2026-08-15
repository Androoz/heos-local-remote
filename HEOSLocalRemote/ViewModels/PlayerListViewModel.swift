import Foundation

@MainActor
struct PlayerListViewModel {
    let repository: PlayerRepository
    func select(_ player: HEOSPlayer) { repository.selectedPlayerID = player.pid }
    func refresh() { repository.refreshPlayers() }
}
