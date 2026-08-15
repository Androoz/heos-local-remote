import Foundation
import Network

struct DiscoveredHEOSDevice: Identifiable, Hashable, Sendable {
    let host: String
    let location: URL?
    let server: String?
    let usn: String?

    var id: String { host }
}

enum HEOSDiscoveryEvent: Sendable {
    case searching
    case device(DiscoveredHEOSDevice)
    case finished([DiscoveredHEOSDevice])
    case failed(String)
}

enum HEOSDiscoveryState: Equatable, Sendable {
    case idle
    case searching
    case found(Int)
    case failed(String)
}

actor HEOSDiscoveryService {
    nonisolated let events: AsyncStream<HEOSDiscoveryEvent>
    private let continuation: AsyncStream<HEOSDiscoveryEvent>.Continuation
    private var group: NWConnectionGroup?
    private var devices: [String: DiscoveredHEOSDevice] = [:]
    private var timeoutTask: Task<Void, Never>?

    init() {
        let pair = AsyncStream<HEOSDiscoveryEvent>.makeStream(bufferingPolicy: .bufferingNewest(50))
        events = pair.stream
        continuation = pair.continuation
    }

    deinit { continuation.finish() }

    func start(searchDuration: Duration = .seconds(4)) {
        stop()
        devices.removeAll()
        continuation.yield(.searching)

        do {
            let endpoint = NWEndpoint.hostPort(host: "239.255.255.250", port: 1900)
            let descriptor = try NWMulticastGroup(for: [endpoint], disableUnicast: false)
            let group = NWConnectionGroup(with: descriptor, using: .udp)
            self.group = group

            group.setReceiveHandler(maximumMessageSize: 64 * 1024, rejectOversizedMessages: true) { [weak self] message, content, _ in
                guard let content else { return }
                Task { await self?.handle(content, remoteEndpoint: message.remoteEndpoint) }
            }
            group.stateUpdateHandler = { [weak self] state in
                Task { await self?.handle(state) }
            }
            group.start(queue: DispatchQueue(label: "se.heoslocalremote.discovery", qos: .userInitiated))

            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: searchDuration)
                guard !Task.isCancelled else { return }
                await self?.finish()
            }
        } catch {
            continuation.yield(.failed(L10n.format("Kunde inte starta HEOS-sökningen: %@", error.localizedDescription)))
        }
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        group?.cancel()
        group = nil
    }

    private func handle(_ state: NWConnectionGroup.State) {
        switch state {
        case .ready:
            sendSearch()
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                await self?.sendSearch()
            }
        case .failed(let error):
            continuation.yield(.failed(Self.userMessage(for: error)))
            stop()
        default: break
        }
    }

    private func sendSearch() {
        let request = [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            "MAN: \"ssdp:discover\"",
            "MX: 2",
            "ST: urn:schemas-denon-com:device:ACT-Denon:1",
            "",
            ""
        ].joined(separator: "\r\n")

        group?.send(content: Data(request.utf8)) { error in
            if let error { HEOSLogger.connection.error("SSDP-sändning misslyckades: \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func handle(_ data: Data, remoteEndpoint: NWEndpoint?) {
        let endpointHost: String? = {
            guard let remoteEndpoint, case .hostPort(let host, _) = remoteEndpoint else { return nil }
            return String(describing: host)
        }()
        guard let device = Self.parseResponse(data, fallbackHost: endpointHost) else { return }
        guard devices[device.host] == nil else { return }
        devices[device.host] = device
        continuation.yield(.device(device))
    }

    nonisolated static func parseResponse(_ data: Data, fallbackHost: String? = nil) -> DiscoveredHEOSDevice? {
        guard let text = String(data: data, encoding: .utf8), text.uppercased().contains("HTTP/1.1 200") else { return nil }
        let headers = text.split(whereSeparator: \.isNewline).reduce(into: [String: String]()) { result, line in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return }
            result[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        let location = headers["location"].flatMap(URL.init(string:))
        guard let host = location?.host ?? fallbackHost, !host.isEmpty else { return nil }
        return DiscoveredHEOSDevice(host: host, location: location, server: headers["server"], usn: headers["usn"])
    }

    private func finish() {
        let result = devices.values.sorted { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
        continuation.yield(.finished(result))
        stop()
    }

    private static func userMessage(for error: NWError) -> String {
        if case .posix(let code) = error, code == .EACCES || code == .EPERM {
            return L10n.string("Automatisk HEOS-sökning saknar multicast-behörighet. Ange en adress manuellt eller kontrollera appens signering.")
        }
        return L10n.string("Kunde inte söka efter HEOS-enheter på nätverket.")
    }
}
