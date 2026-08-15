import Foundation

struct NowPlaying: Codable, Equatable, Sendable {
    var type: String?
    var song: String?
    var station: String?
    var album: String?
    var artist: String?
    var imageURL: String?
    var albumID: String?
    var mediaID: String?
    var queueID: String?
    var sourceID: String?

    enum CodingKeys: String, CodingKey {
        case type, song, station, album, artist
        case imageURL = "image_url"
        case albumID = "album_id"
        case mediaID = "mid"
        case queueID = "qid"
        case sourceID = "sid"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.flexibleString(forKey: .type)
        song = container.flexibleString(forKey: .song)
        station = container.flexibleString(forKey: .station)
        album = container.flexibleString(forKey: .album)
        artist = container.flexibleString(forKey: .artist)
        imageURL = container.flexibleString(forKey: .imageURL)
        albumID = container.flexibleString(forKey: .albumID)
        mediaID = container.flexibleString(forKey: .mediaID)
        queueID = container.flexibleString(forKey: .queueID)
        sourceID = container.flexibleString(forKey: .sourceID)
    }

    init(type: String? = nil, song: String? = nil, station: String? = nil, album: String? = nil, artist: String? = nil, imageURL: String? = nil, albumID: String? = nil, mediaID: String? = nil, queueID: String? = nil, sourceID: String? = nil) {
        self.type = type; self.song = song; self.station = station; self.album = album
        self.artist = artist; self.imageURL = imageURL; self.albumID = albumID
        self.mediaID = mediaID; self.queueID = queueID; self.sourceID = sourceID
    }

    var sourceKind: PlaybackSourceKind {
        PlaybackSourceKind(type: type, station: station, song: song)
    }
}

enum PlaybackSourceKind: String, Codable, Sendable {
    case music
    case radio
    case television
    case auxiliary
    case bluetooth
    case unknown

    init(type: String?, station: String?, song: String?) {
        let description = [type, station, song].compactMap { $0 }.joined(separator: " ").lowercased()
        if description.contains("tv") || description.contains("hdmi") || description.contains("arc") {
            self = .television
        } else if description.contains("aux") || description.contains("input") || description.contains("optical") || description.contains("coax") {
            self = .auxiliary
        } else if description.contains("bluetooth") {
            self = .bluetooth
        } else if type?.lowercased() == "station" || station?.isEmpty == false {
            self = .radio
        } else if type?.lowercased() == "song" || song?.isEmpty == false {
            self = .music
        } else {
            self = .unknown
        }
    }

    var label: String {
        switch self {
        case .music: L10n.string("Musik")
        case .radio: L10n.string("Radio")
        case .television: L10n.string("TV-ljud")
        case .auxiliary: L10n.string("Extern ingång")
        case .bluetooth: L10n.string("Bluetooth")
        case .unknown: L10n.string("Okänd källa")
        }
    }

    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .radio: "radio"
        case .television: "tv"
        case .auxiliary: "cable.connector"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .unknown: "hifispeaker"
        }
    }

    var supportsSkipping: Bool { self == .music || self == .radio || self == .unknown }
    var isExternalInput: Bool { self == .television || self == .auxiliary || self == .bluetooth }
}
