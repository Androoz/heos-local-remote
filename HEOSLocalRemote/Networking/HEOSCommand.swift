import Foundation

enum HEOSCommand: Equatable, Sendable {
    case getPlayers
    case getPlayState(pid: String)
    case getNowPlaying(pid: String)
    case getVolume(pid: String)
    case setVolume(pid: String, level: Int)
    case getMute(pid: String)
    case setMute(pid: String, muted: Bool)
    case setPlayState(pid: String, state: HEOSPlayState)
    case next(pid: String)
    case previous(pid: String)
    case registerForEvents
    case heartBeat
    case getGroups
    case setGroup(playerIDs: [String])
    case getGroupVolume(gid: String)
    case setGroupVolume(gid: String, level: Int)
    case getGroupMute(gid: String)
    case setGroupMute(gid: String, muted: Bool)

    var path: String {
        switch self {
        case .getPlayers: "player/get_players"
        case .getPlayState: "player/get_play_state"
        case .getNowPlaying: "player/get_now_playing_media"
        case .getVolume: "player/get_volume"
        case .setVolume: "player/set_volume"
        case .getMute: "player/get_mute"
        case .setMute: "player/set_mute"
        case .setPlayState: "player/set_play_state"
        case .next: "player/play_next"
        case .previous: "player/play_previous"
        case .registerForEvents: "system/register_for_change_events"
        case .heartBeat: "system/heart_beat"
        case .getGroups: "group/get_groups"
        case .setGroup: "group/set_group"
        case .getGroupVolume: "group/get_volume"
        case .setGroupVolume: "group/set_volume"
        case .getGroupMute: "group/get_mute"
        case .setGroupMute: "group/set_mute"
        }
    }

    var parameters: [(String, String)] {
        switch self {
        case .getPlayers: []
        case .getPlayState(let pid), .getNowPlaying(let pid), .getVolume(let pid), .getMute(let pid), .next(let pid), .previous(let pid): [("pid", pid)]
        case .setVolume(let pid, let level): [("pid", pid), ("level", String(min(100, max(0, level))))]
        case .setMute(let pid, let muted): [("pid", pid), ("state", muted ? "on" : "off")]
        case .setPlayState(let pid, let state): [("pid", pid), ("state", state.commandValue)]
        case .registerForEvents: [("enable", "on")]
        case .heartBeat, .getGroups: []
        case .setGroup(let playerIDs): [("pid", playerIDs.joined(separator: ","))]
        case .getGroupVolume(let gid), .getGroupMute(let gid): [("gid", gid)]
        case .setGroupVolume(let gid, let level): [("gid", gid), ("level", String(min(100, max(0, level))))]
        case .setGroupMute(let gid, let muted): [("gid", gid), ("state", muted ? "on" : "off")]
        }
    }

    var string: String {
        var components = URLComponents()
        components.scheme = "heos"
        components.host = path.split(separator: "/").first.map(String.init)
        components.path = "/" + path.split(separator: "/").dropFirst().joined(separator: "/")
        components.queryItems = parameters.isEmpty ? nil : parameters.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.string ?? "heos://\(path)"
    }

    var wireData: Data { Data((string + "\r\n").utf8) }
}

private extension HEOSPlayState {
    var commandValue: String {
        switch self {
        case .playing: "play"
        case .paused: "pause"
        case .stopped: "stop"
        case .unknown: "pause"
        }
    }
}
