import Foundation

struct HEOSResponse: Codable, Equatable, Sendable {
    struct Metadata: Codable, Equatable, Sendable {
        let command: String
        let result: String
        let message: String

        var succeeded: Bool { result.lowercased() == "success" }
        var messageParameters: [String: String] {
            guard !message.isEmpty else { return [:] }
            return message.split(separator: "&").reduce(into: [:]) { result, pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                result[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }
    }

    let heos: Metadata
    let payload: JSONValue?
}
