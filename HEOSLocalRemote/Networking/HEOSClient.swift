import Foundation

enum HEOSClientEvent: Sendable {
    case connection(HEOSConnectionState)
    case loadingPlayers(Bool)
    case players([HEOSPlayer])
    case groups([HEOSGroup])
    case groupVolume(gid: String, level: Int)
    case groupMute(gid: String, muted: Bool)
    case playerAdded(HEOSPlayer)
    case playerRemoved(String)
    case playerRenamed(pid: String, name: String)
    case state(pid: String, HEOSPlayState)
    case volume(pid: String, level: Int, muted: Bool?)
    case mute(pid: String, muted: Bool)
    case media(pid: String, NowPlaying)
    case error(String)
}

actor HEOSClient {
    private struct PendingResponse {
        let id: UUID
        let continuation: CheckedContinuation<HEOSResponse, Error>
    }

    nonisolated let events: AsyncStream<HEOSClientEvent>
    private let continuation: AsyncStream<HEOSClientEvent>.Continuation
    private let connection = HEOSConnection()
    private var connectionTask: Task<Void, Never>?
    private var pending: [String: [PendingResponse]] = [:]
    private var timeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var started = false
    private var heartbeatTask: Task<Void, Never>?

    init() {
        let pair = AsyncStream<HEOSClientEvent>.makeStream(bufferingPolicy: .bufferingNewest(200))
        events = pair.stream
        continuation = pair.continuation
    }

    deinit {
        connectionTask?.cancel()
        heartbeatTask?.cancel()
        continuation.finish()
    }

    func connect(host: String, reconnecting: Bool = false) async {
        startConsumingIfNeeded()
        await connection.connect(host: host, reconnecting: reconnecting)
    }

    func disconnect() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        cancelPending(with: HEOSConnectionError.connectionClosed)
        await connection.disconnect()
    }

    func refreshPlayers() async {
        continuation.yield(.loadingPlayers(true))
        defer { continuation.yield(.loadingPlayers(false)) }
        do {
            let response = try await request(.getPlayers)
            let players = try decodePlayers(response.payload)
            continuation.yield(.players(players))
            for player in players { await refresh(pid: player.pid) }
        } catch { report(error) }
    }

    func refresh(pid: String) async {
        async let state = fetchState(pid: pid)
        async let media = fetchMedia(pid: pid)
        async let volume = fetchVolume(pid: pid)
        async let mute = fetchMute(pid: pid)
        _ = await (state, media, volume, mute)
    }

    func refreshGroups() async {
        do {
            let response = try await request(.getGroups)
            let groups = try decodePayload([HEOSGroup].self, from: response.payload) ?? []
            continuation.yield(.groups(groups.filter { !$0.gid.isEmpty }))
            for group in groups {
                async let volume: Void = fetchGroupVolume(gid: group.gid)
                async let mute: Void = fetchGroupMute(gid: group.gid)
                _ = await (volume, mute)
            }
        } catch { report(error) }
    }

    func setGroup(leaderPID: String, memberPIDs: [String], stoppingExternalInputPIDs: [String] = []) async {
        let ordered = [leaderPID] + memberPIDs.filter { $0 != leaderPID }
        do {
            for pid in Set(stoppingExternalInputPIDs) where pid != leaderPID {
                _ = try await request(.setPlayState(pid: pid, state: .stopped))
            }
            if !stoppingExternalInputPIDs.isEmpty {
                try? await Task.sleep(for: .milliseconds(450))
            }
            _ = try await request(.setGroup(playerIDs: ordered))
            try? await Task.sleep(for: .milliseconds(350))
            await refreshGroups()
            await refreshPlayers()
        } catch { reportGroupError(error) }
    }

    func setGroupVolume(gid: String, level: Int) async {
        do {
            _ = try await request(.setGroupVolume(gid: gid, level: level))
            continuation.yield(.groupVolume(gid: gid, level: min(100, max(0, level))))
        } catch { report(error) }
    }

    func setUniformPlayerVolumes(pids: [String], level: Int) async {
        for pid in pids {
            await setVolume(pid: pid, level: level)
        }
    }

    func setGroupMute(gid: String, muted: Bool) async {
        do {
            _ = try await request(.setGroupMute(gid: gid, muted: muted))
            continuation.yield(.groupMute(gid: gid, muted: muted))
        } catch { report(error) }
    }

    func setPlayState(pid: String, state: HEOSPlayState) async {
        do { _ = try await request(.setPlayState(pid: pid, state: state)) }
        catch { report(error) }
    }

    func next(pid: String) async {
        do { _ = try await request(.next(pid: pid)) }
        catch { report(error) }
    }

    func previous(pid: String) async {
        do { _ = try await request(.previous(pid: pid)) }
        catch { report(error) }
    }

    func setVolume(pid: String, level: Int) async {
        do { _ = try await request(.setVolume(pid: pid, level: level)) }
        catch { report(error) }
    }

    func setMute(pid: String, muted: Bool) async {
        do { _ = try await request(.setMute(pid: pid, muted: muted)) }
        catch { report(error) }
    }

    func connectionState() async -> HEOSConnectionState { await connection.currentState() }

    private func startConsumingIfNeeded() {
        guard !started else { return }
        started = true
        connectionTask = Task { [weak self, events = connection.events] in
            for await event in events {
                guard !Task.isCancelled else { return }
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: HEOSConnectionEvent) async {
        switch event {
        case .state(let state):
            continuation.yield(.connection(state))
            if state == .connected {
                startHeartbeat()
                Task { [weak self] in await self?.bootstrap() }
            } else {
                heartbeatTask?.cancel()
                heartbeatTask = nil
                if case .failed = state { cancelPending(with: HEOSConnectionError.connectionClosed) }
            }
        case .response(let response):
            handle(response)
        }
    }

    private func bootstrap() async {
        async let registration: Void = registerForEvents()
        async let players: Void = refreshPlayers()
        async let groups: Void = refreshGroups()
        _ = await (registration, players, groups)
    }

    private func registerForEvents() async {
        do {
            _ = try await request(.registerForEvents)
        } catch {
            HEOSLogger.event.error("Kunde inte registrera change events: \(error.localizedDescription, privacy: .public)")
            continuation.yield(.error(L10n.string("Spelarna kan styras, men automatiska statusuppdateringar kunde inte aktiveras.")))
        }
    }

    private func request(_ command: HEOSCommand, timeout: Duration = .seconds(8)) async throws -> HEOSResponse {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[command.path, default: []].append(PendingResponse(id: id, continuation: continuation))
                timeoutTasks[id] = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    await self?.timeout(id: id, path: command.path)
                }
                Task { [weak self] in
                    do { try await self?.connection.send(command) }
                    catch { await self?.failPending(id: id, path: command.path, error: error) }
                }
            }
        } onCancel: {
            Task { await self.failPending(id: id, path: command.path, error: CancellationError()) }
        }
    }

    private func handle(_ response: HEOSResponse) {
        let command = response.heos.command
        if command.hasPrefix("event/") {
            handleEvent(response)
            return
        }
        guard var requests = pending[command], !requests.isEmpty else {
            HEOSLogger.response.notice("Svar utan väntande kommando: \(command, privacy: .public)")
            return
        }
        let request = requests.removeFirst()
        pending[command] = requests.isEmpty ? nil : requests
        timeoutTasks.removeValue(forKey: request.id)?.cancel()
        if response.heos.succeeded { request.continuation.resume(returning: response) }
        else { request.continuation.resume(throwing: HEOSCommandError.failed(response.heos.message)) }
    }

    private func handleEvent(_ response: HEOSResponse) {
        let values = response.heos.messageParameters
        let pid = values["pid"] ?? response.payload?.objectValue?.string("pid")
        #if DEBUG
        HEOSLogger.event.debug("Event \(response.heos.command, privacy: .public)")
        #endif
        switch response.heos.command {
        case "event/players_changed":
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                await self?.refreshPlayers()
            }
        case "event/groups_changed":
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                await self?.refreshGroups()
            }
        case "event/player_state_changed":
            if let pid { continuation.yield(.state(pid: pid, HEOSPlayState(heosValue: values["state"]))) }
        case "event/player_now_playing_changed":
            if let pid { Task { [weak self] in await self?.fetchMedia(pid: pid) } }
        case "event/player_volume_changed":
            if let pid, let level = values["level"].flatMap(Int.init) {
                continuation.yield(.volume(pid: pid, level: level, muted: values["mute"].map { $0 == "on" }))
            }
        case "event/group_volume_changed":
            if let gid = values["gid"], let level = values["level"].flatMap(Int.init) {
                continuation.yield(.groupVolume(gid: gid, level: level))
            }
        case "event/group_mute_changed":
            if let gid = values["gid"], let muted = values["state"].map({ $0 == "on" }) {
                continuation.yield(.groupMute(gid: gid, muted: muted))
            }
        case "event/player_added":
            if let player = decodePlayer(response.payload) { continuation.yield(.playerAdded(player)) }
            else { Task { [weak self] in await self?.refreshPlayers() } }
        case "event/player_removed":
            if let pid { continuation.yield(.playerRemoved(pid)) }
        case "event/player_name_changed":
            if let pid, let name = values["name"] { continuation.yield(.playerRenamed(pid: pid, name: name)) }
        case "event/player_now_playing_progress", "event/repeat_mode_changed", "event/shuffle_mode_changed":
            break
        default:
            HEOSLogger.event.notice("Okänt HEOS-event: \(response.heos.command, privacy: .public)")
        }
    }

    private func fetchState(pid: String) async {
        do {
            let response = try await request(.getPlayState(pid: pid))
            continuation.yield(.state(pid: pid, HEOSPlayState(heosValue: response.heos.messageParameters["state"])))
        } catch { report(error) }
    }

    private func fetchMedia(pid: String) async {
        do {
            let response = try await request(.getNowPlaying(pid: pid))
            if let media = try decodePayload(NowPlaying.self, from: response.payload) {
                continuation.yield(.media(pid: pid, media))
            }
        } catch { report(error) }
    }

    private func fetchGroupVolume(gid: String) async {
        do {
            let response = try await request(.getGroupVolume(gid: gid))
            if let level = response.heos.messageParameters["level"].flatMap(Int.init) {
                continuation.yield(.groupVolume(gid: gid, level: level))
            }
        } catch { report(error) }
    }

    private func fetchGroupMute(gid: String) async {
        do {
            let response = try await request(.getGroupMute(gid: gid))
            if let state = response.heos.messageParameters["state"] {
                continuation.yield(.groupMute(gid: gid, muted: state == "on"))
            }
        } catch { report(error) }
    }

    private func fetchVolume(pid: String) async {
        do {
            let response = try await request(.getVolume(pid: pid))
            if let level = response.heos.messageParameters["level"].flatMap(Int.init) {
                continuation.yield(.volume(pid: pid, level: level, muted: nil))
            }
        } catch { report(error) }
    }

    private func fetchMute(pid: String) async {
        do {
            let response = try await request(.getMute(pid: pid))
            if let state = response.heos.messageParameters["state"] {
                continuation.yield(.mute(pid: pid, muted: state == "on"))
            }
        } catch { report(error) }
    }

    private func decodePlayers(_ payload: JSONValue?) throws -> [HEOSPlayer] {
        guard let value = payload else { return [] }
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode([HEOSPlayer].self, from: data).filter { !$0.pid.isEmpty }
    }

    private func decodePlayer(_ payload: JSONValue?) -> HEOSPlayer? { try? decodePayload(HEOSPlayer.self, from: payload) }

    private func decodePayload<T: Decodable>(_ type: T.Type, from payload: JSONValue?) throws -> T? {
        guard let payload else { return nil }
        let data = try JSONEncoder().encode(payload)
        return try JSONDecoder().decode(type, from: data)
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled, let self else { return }
                do { _ = try await self.request(.heartBeat, timeout: .seconds(5)) }
                catch {
                    await self.report(HEOSConnectionError.connectionClosed)
                    await self.connection.disconnect()
                    return
                }
            }
        }
    }

    private func timeout(id: UUID, path: String) {
        failPending(id: id, path: path, error: HEOSCommandError.timeout)
    }

    private func failPending(id: UUID, path: String, error: Error) {
        guard var requests = pending[path], let index = requests.firstIndex(where: { $0.id == id }) else { return }
        let request = requests.remove(at: index)
        pending[path] = requests.isEmpty ? nil : requests
        timeoutTasks.removeValue(forKey: id)?.cancel()
        request.continuation.resume(throwing: error)
    }

    private func cancelPending(with error: Error) {
        for commands in pending.values { for request in commands { request.continuation.resume(throwing: error) } }
        pending.removeAll()
        timeoutTasks.values.forEach { $0.cancel() }
        timeoutTasks.removeAll()
    }

    private func report(_ error: Error) {
        guard !(error is CancellationError) else { return }
        HEOSLogger.error.error("HEOS-fel: \(error.localizedDescription, privacy: .public)")
        continuation.yield(.error(error.localizedDescription))
    }

    private func reportGroupError(_ error: Error) {
        if let commandError = error as? HEOSCommandError,
           commandError.heosErrorID == 7 {
            continuation.yield(.error(L10n.string("Gruppen kunde inte skapas av HEOS. Om en HomeCinema-, Bar- eller TV-enhet ingår: stoppa TV-ljudet eller aktivera ‘Gruppera TV-ljud’ i HEOS-appen och försök igen.")))
        } else {
            report(error)
        }
    }
}

enum HEOSCommandError: LocalizedError {
    case failed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .failed(let message): L10n.format("HEOS-kommandot misslyckades: %@", message)
        case .timeout: L10n.string("HEOS-enheten svarade inte i tid.")
        }
    }

    var heosErrorID: Int? {
        guard case .failed(let message) = self else { return nil }
        return message.split(separator: "&")
            .first(where: { $0.hasPrefix("eid=") })
            .flatMap { Int($0.dropFirst(4)) }
    }
}
