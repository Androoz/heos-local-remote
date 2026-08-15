import Foundation

enum MockData {
    static let players = [
        HEOSPlayer(pid: "1", name: "Kök", model: "HEOS 3", version: "3.34", ip: "192.0.2.10", network: "wired", lineOut: nil),
        HEOSPlayer(pid: "2", name: "TV-rum", model: "HEOS HomeCinema Soundbar", version: "3.34", ip: "192.0.2.11", network: "wifi", lineOut: nil),
        HEOSPlayer(pid: "3", name: "Sovrum", model: "HEOS 1", version: "3.34", ip: "192.0.2.12", network: "wifi", lineOut: nil)
    ]

    static let states: [String: PlayerState] = [
        "1": PlayerState(pid: "1", playState: .playing, volume: 38, isMuted: false, song: "Northern Lights", station: nil, artist: "Aurora Lane", album: "Home", imageURL: nil),
        "2": PlayerState(pid: "2", playState: .playing, volume: 24, isMuted: false, song: nil, station: nil, artist: nil, album: nil, imageURL: nil, sourceKind: .television),
        "3": PlayerState(pid: "3", playState: .stopped, volume: 18, isMuted: true, song: nil, station: nil, artist: nil, album: nil, imageURL: nil)
    ]

    static let groups = [
        HEOSGroup(name: "Nedervåning", gid: "10", players: [
            .init(name: "Kök", pid: "1", role: "leader"),
            .init(name: "TV-rum", pid: "2", role: "member")
        ])
    ]
}
