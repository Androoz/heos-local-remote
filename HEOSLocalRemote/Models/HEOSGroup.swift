import Foundation

struct HEOSGroup: Codable, Identifiable, Equatable, Sendable {
    struct Member: Codable, Identifiable, Equatable, Sendable {
        let name: String
        let pid: String
        let role: String

        var id: String { pid }
        var isLeader: Bool { role.lowercased() == "leader" }

        enum CodingKeys: String, CodingKey { case name, pid, role }

        init(name: String, pid: String, role: String) {
            self.name = name; self.pid = pid; self.role = role
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = container.flexibleString(forKey: .name) ?? L10n.string("HEOS-spelare")
            pid = container.flexibleString(forKey: .pid) ?? ""
            role = container.flexibleString(forKey: .role) ?? "member"
        }
    }

    let name: String
    let gid: String
    let players: [Member]

    var id: String { gid }
    var leaderPID: String? { players.first(where: \.isLeader)?.pid ?? players.first?.pid }
    var playerIDs: Set<String> { Set(players.map(\.pid)) }
    var displayName: String {
        let names = players.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? name : names.joined(separator: " + ")
    }

    enum CodingKeys: String, CodingKey { case name, gid, players }

    init(name: String, gid: String, players: [Member]) {
        self.name = name; self.gid = gid; self.players = players
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.flexibleString(forKey: .name) ?? L10n.string("HEOS-grupp")
        gid = container.flexibleString(forKey: .gid) ?? ""
        players = (try? container.decode([Member].self, forKey: .players)) ?? []
    }
}
