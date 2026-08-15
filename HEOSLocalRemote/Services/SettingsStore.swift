import Foundation
import Darwin

struct SettingsStore {
    private let defaults: UserDefaults
    private let addressKey = "lastHEOSAddress"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var lastAddress: String {
        get { defaults.string(forKey: addressKey) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: addressKey) }
    }

    static func normalizedAddress(_ input: String) -> String? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("[") && value.hasSuffix("]") { value = String(value.dropFirst().dropLast()) }
        guard !value.isEmpty, value.count <= 253, !value.contains(where: { $0.isWhitespace || $0 == "/" }) else { return nil }

        var ipv4 = in_addr()
        if inet_pton(AF_INET, value, &ipv4) == 1 { return value }
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, value, &ipv6) == 1 { return value }

        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty, labels.allSatisfy({ label in
            guard !label.isEmpty, label.count <= 63, label.first != "-", label.last != "-" else { return false }
            return label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }) else { return nil }
        return value
    }
}
