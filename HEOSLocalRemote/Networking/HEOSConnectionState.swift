import Foundation

enum HEOSConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: L10n.string("Frånkopplad")
        case .connecting: L10n.string("Ansluter…")
        case .connected: L10n.string("Ansluten")
        case .reconnecting: L10n.string("Återansluter…")
        case .failed: L10n.string("Anslutningen misslyckades")
        }
    }
}
