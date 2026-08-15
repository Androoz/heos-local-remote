import Foundation

enum HEOSPlayState: String, Codable, Sendable {
    case playing = "play"
    case paused = "pause"
    case stopped = "stop"
    case unknown

    init(heosValue: String?) {
        self = HEOSPlayState(rawValue: heosValue?.lowercased() ?? "") ?? .unknown
    }
}

struct PlayerState: Equatable, Sendable {
    let pid: String
    var playState: HEOSPlayState = .unknown
    var volume: Int = 0
    var isMuted = false
    var song: String?
    var station: String?
    var artist: String?
    var album: String?
    var imageURL: String?
    var sourceKind: PlaybackSourceKind = .unknown

    var displayTitle: String {
        song.nonEmpty ?? station.nonEmpty ?? (playState == .playing ? sourceKind.label : L10n.string("Inget spelas"))
    }

    mutating func apply(_ media: NowPlaying) {
        song = media.song; station = media.station; artist = media.artist
        album = media.album; imageURL = media.imageURL
        sourceKind = media.sourceKind
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? { flatMap { $0.isEmpty ? nil : $0 } }
}
