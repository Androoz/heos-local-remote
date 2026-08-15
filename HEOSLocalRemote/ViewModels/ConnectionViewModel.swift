import Foundation

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published var address: String
    private let repository: PlayerRepository

    init(repository: PlayerRepository) {
        self.repository = repository
        address = repository.savedAddress
    }

    var canConnect: Bool { !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && repository.connectionState != .connecting }
    func connect() { repository.connect(to: address) }
}
