import Foundation
import Network

enum HEOSConnectionEvent: Sendable {
    case state(HEOSConnectionState)
    case response(HEOSResponse)
}

actor HEOSConnection {
    nonisolated let events: AsyncStream<HEOSConnectionEvent>
    private let continuation: AsyncStream<HEOSConnectionEvent>.Continuation
    private var connection: NWConnection?
    private var parser = HEOSMessageParser()
    private var state: HEOSConnectionState = .disconnected
    private var generation = UUID()
    private var connectTimeoutTask: Task<Void, Never>?

    init() {
        let pair = AsyncStream<HEOSConnectionEvent>.makeStream(bufferingPolicy: .bufferingNewest(200))
        events = pair.stream
        continuation = pair.continuation
    }

    deinit { continuation.finish() }

    func connect(host: String, reconnecting: Bool = false) {
        guard connection == nil else { return }
        state = reconnecting ? .reconnecting : .connecting
        continuation.yield(.state(state))
        parser.reset()
        generation = UUID()
        let currentGeneration = generation

        let nwConnection = NWConnection(host: NWEndpoint.Host(host), port: 1255, using: .tcp)
        connection = nwConnection
        nwConnection.stateUpdateHandler = { [weak self] newState in
            Task { await self?.handle(newState, generation: currentGeneration) }
        }
        nwConnection.start(queue: DispatchQueue(label: "se.heoslocalremote.connection", qos: .userInitiated))
        receive(on: nwConnection, generation: currentGeneration)
        connectTimeoutTask?.cancel()
        connectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            await self?.connectionTimedOut(generation: currentGeneration)
        }
    }

    func send(_ command: HEOSCommand) async throws {
        guard state == .connected, let connection else { throw HEOSConnectionError.notConnected }
        #if DEBUG
        HEOSLogger.command.debug("Skickar \(command.string, privacy: .public)")
        #endif
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: command.wireData, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    func disconnect() {
        generation = UUID()
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        parser.reset()
        transition(to: .disconnected)
    }

    func currentState() -> HEOSConnectionState { state }

    private func receive(on connection: NWConnection, generation: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { await self?.received(data, isComplete: isComplete, error: error, connection: connection, generation: generation) }
        }
    }

    private func received(_ data: Data?, isComplete: Bool, error: NWError?, connection: NWConnection, generation: UUID) {
        guard generation == self.generation else { return }
        if let data, !data.isEmpty {
            for response in parser.append(data) {
                #if DEBUG
                HEOSLogger.response.debug("Mottog \(response.heos.command, privacy: .public)")
                #endif
                continuation.yield(.response(response))
            }
        }
        if let error {
            fail(error)
        } else if isComplete {
            fail(HEOSConnectionError.connectionClosed)
        } else {
            receive(on: connection, generation: generation)
        }
    }

    private func handle(_ newState: NWConnection.State, generation: UUID) {
        guard generation == self.generation else { return }
        switch newState {
        case .ready:
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            transition(to: .connected)
        case .failed(let error): fail(error)
        case .cancelled:
            connection = nil
            if state != .disconnected { transition(to: .disconnected) }
        case .waiting(let error):
            HEOSLogger.connection.notice("Väntar på nätverk: \(error.localizedDescription, privacy: .public)")
        default: break
        }
    }

    private func fail(_ error: Error) {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        let message = Self.userMessage(for: error)
        HEOSLogger.error.error("Anslutningsfel: \(error.localizedDescription, privacy: .public)")
        transition(to: .failed(message))
    }

    private func connectionTimedOut(generation: UUID) {
        guard generation == self.generation, state == .connecting || state == .reconnecting else { return }
        fail(HEOSConnectionError.timeout)
    }

    private func transition(to newState: HEOSConnectionState) {
        state = newState
        continuation.yield(.state(newState))
    }

    private static func userMessage(for error: Error) -> String {
        if let nwError = error as? NWError, case .posix(let code) = nwError, code == .EACCES || code == .EPERM {
            return L10n.string("Lokal nätverksåtkomst saknas. Aktivera åtkomst i Inställningar.")
        }
        if let connectionError = error as? HEOSConnectionError {
            switch connectionError {
            case .connectionClosed: return L10n.string("Anslutningen till HEOS-systemet bröts.")
            case .timeout: return L10n.string("HEOS-enheten svarade inte i tid. Kontrollera adressen och nätverket.")
            case .notConnected: break
            }
        }
        return L10n.string("Kunde inte ansluta till HEOS-enheten. Kontrollera adressen och att enheterna är på samma nätverk.")
    }
}

enum HEOSConnectionError: LocalizedError {
    case notConnected
    case connectionClosed
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected: L10n.string("Ingen aktiv HEOS-anslutning.")
        case .connectionClosed: L10n.string("Anslutningen till HEOS-systemet bröts.")
        case .timeout: L10n.string("Anslutningen till HEOS-enheten tog för lång tid.")
        }
    }
}
