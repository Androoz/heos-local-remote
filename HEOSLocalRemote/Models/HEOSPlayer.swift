import Foundation

struct HEOSPlayer: Codable, Identifiable, Hashable, Sendable {
    let pid: String
    var name: String
    var model: String?
    var version: String?
    var ip: String?
    var network: String?
    var lineOut: String?

    var id: String { pid }

    enum CodingKeys: String, CodingKey {
        case pid, name, model, version, ip, network
        case lineOut = "lineout"
    }

    init(pid: String, name: String, model: String?, version: String?, ip: String?, network: String?, lineOut: String?) {
        self.pid = pid
        self.name = name
        self.model = model
        self.version = version
        self.ip = ip
        self.network = network
        self.lineOut = lineOut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pid = container.flexibleString(forKey: .pid) ?? ""
        name = container.flexibleString(forKey: .name) ?? L10n.string("Namnlös HEOS-spelare")
        model = container.flexibleString(forKey: .model)
        version = container.flexibleString(forKey: .version)
        ip = container.flexibleString(forKey: .ip)
        network = container.flexibleString(forKey: .network)
        lineOut = container.flexibleString(forKey: .lineOut)
    }
}
