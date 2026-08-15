import Foundation

@MainActor
final class PlayerRepository: ObservableObject {
    @Published private(set) var players: [HEOSPlayer] = []
    @Published private(set) var states: [String: PlayerState] = [:]
    @Published private(set) var groups: [HEOSGroup] = []
    @Published private(set) var groupVolumes: [String: Int] = [:]
    @Published private(set) var groupMutes: [String: Bool] = [:]
    @Published var selectedPlayerID: String?
    @Published private(set) var connectionState: HEOSConnectionState = .disconnected
    @Published private(set) var isLoadingPlayers = false
    @Published private(set) var lastError: String?
    @Published private(set) var connectedAddress: String?
    @Published private(set) var discoveryState: HEOSDiscoveryState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredHEOSDevice] = []

    private let client: HEOSClient
    private let discovery: HEOSDiscoveryService
    private var settings: SettingsStore
    private var eventTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var shouldReconnect = false
    private var reconnectAttemptCount = 0
    private var attemptedHosts: Set<String> = []

    init(
        client: HEOSClient = HEOSClient(),
        discovery: HEOSDiscoveryService = HEOSDiscoveryService(),
        settings: SettingsStore = SettingsStore()
    ) {
        self.client = client
        self.discovery = discovery
        self.settings = settings
        eventTask = Task { [weak self, events = client.events] in
            for await event in events {
                guard !Task.isCancelled else { return }
                self?.apply(event)
            }
        }
        discoveryTask = Task { [weak self, events = discovery.events] in
            for await event in events {
                guard !Task.isCancelled else { return }
                self?.apply(event)
            }
        }
    }

    deinit { eventTask?.cancel(); discoveryTask?.cancel(); reconnectTask?.cancel() }

    var savedAddress: String { settings.lastAddress }
    var selectedPlayer: HEOSPlayer? { players.first { $0.pid == selectedPlayerID } }

    func state(for pid: String) -> PlayerState { states[pid] ?? PlayerState(pid: pid) }
    func group(for pid: String) -> HEOSGroup? { groups.first { $0.playerIDs.contains(pid) } }

    func startAutomaticConnection(forceDiscovery: Bool = false) {
        guard connectionState != .connected else { return }
        lastError = nil
        attemptedHosts.removeAll()
        discoveredDevices = []
        discoveryState = .searching
        Task { await discovery.start() }

        if !forceDiscovery,
           let saved = SettingsStore.normalizedAddress(settings.lastAddress) {
            shouldReconnect = true
            reconnectAttemptCount = 0
            connectCandidate(saved, reconnecting: false)
        }
    }

    func searchForDevices() {
        startAutomaticConnection(forceDiscovery: true)
    }

    func connectToSavedAddress() {
        guard connectionState != .connected,
              connectionState != .connecting,
              connectionState != .reconnecting,
              let saved = SettingsStore.normalizedAddress(settings.lastAddress) else { return }
        reconnectTask?.cancel()
        reconnectTask = nil
        shouldReconnect = true
        reconnectAttemptCount = 0
        attemptedHosts.removeAll()
        lastError = nil
        connectCandidate(saved, reconnecting: false)
    }

    func connect(to rawAddress: String) {
        guard let address = SettingsStore.normalizedAddress(rawAddress) else {
            lastError = L10n.string("Ange en giltig IP-adress eller ett lokalt värdnamn.")
            return
        }
        reconnectTask?.cancel()
        reconnectTask = nil
        shouldReconnect = true
        reconnectAttemptCount = 0
        attemptedHosts.removeAll()
        lastError = nil
        connectCandidate(address, reconnecting: false)
    }

    @discardableResult
    func changeController(to rawAddress: String) -> Bool {
        guard let address = SettingsStore.normalizedAddress(rawAddress) else {
            lastError = L10n.string("Ange en giltig IP-adress eller ett lokalt värdnamn.")
            return false
        }
        reconnectTask?.cancel()
        reconnectTask = nil
        shouldReconnect = true
        reconnectAttemptCount = 0
        attemptedHosts.removeAll()
        lastError = nil
        connectedAddress = address
        settings.lastAddress = address
        Task {
            await client.disconnect()
            await client.connect(host: address, reconnecting: true)
        }
        return true
    }

    func disconnect() {
        shouldReconnect = false
        reconnectAttemptCount = 0
        reconnectTask?.cancel()
        reconnectTask = nil
        Task {
            await client.disconnect()
            await discovery.stop()
        }
        players = []
        states = [:]
        groups = []
        groupVolumes = [:]
        groupMutes = [:]
        selectedPlayerID = nil
        connectedAddress = nil
        discoveredDevices = []
        discoveryState = .idle
    }

    func reconnect() {
        guard let address = connectedAddress ?? SettingsStore.normalizedAddress(settings.lastAddress) else { return }
        lastError = nil
        connectedAddress = address
        reconnectTask?.cancel()
        reconnectTask = nil
        shouldReconnect = true
        reconnectAttemptCount = 0
        Task {
            await client.disconnect()
            await client.connect(host: address, reconnecting: true)
        }
    }

    func refreshPlayers() { Task { await client.refreshPlayers() } }
    func refreshGroups() { Task { await client.refreshGroups() } }
    func refreshAll() {
        Task {
            async let players: Void = client.refreshPlayers()
            async let groups: Void = client.refreshGroups()
            _ = await (players, groups)
        }
    }
    func refresh(pid: String) { Task { await client.refresh(pid: pid) } }

    func togglePlayback(pid: String) {
        let newState: HEOSPlayState = state(for: pid).playState == .playing ? .paused : .playing
        states[pid, default: PlayerState(pid: pid)].playState = newState
        Task { await client.setPlayState(pid: pid, state: newState) }
    }

    func playNext(pid: String) { Task { await client.next(pid: pid) } }
    func playPrevious(pid: String) { Task { await client.previous(pid: pid) } }

    func setVolume(pid: String, level: Int) {
        states[pid, default: PlayerState(pid: pid)].volume = min(100, max(0, level))
        Task { await client.setVolume(pid: pid, level: level) }
    }

    func toggleMute(pid: String) {
        let muted = !state(for: pid).isMuted
        states[pid, default: PlayerState(pid: pid)].isMuted = muted
        Task { await client.setMute(pid: pid, muted: muted) }
    }

    func updateGroup(leaderPID: String, memberPIDs: [String], stoppingExternalInputPIDs: [String] = []) {
        for pid in stoppingExternalInputPIDs {
            states[pid, default: PlayerState(pid: pid)].playState = .stopped
        }
        Task {
            await client.setGroup(
                leaderPID: leaderPID,
                memberPIDs: memberPIDs,
                stoppingExternalInputPIDs: stoppingExternalInputPIDs
            )
        }
    }

    func ungroup(_ group: HEOSGroup) {
        guard let leaderPID = group.leaderPID else { return }
        Task { await client.setGroup(leaderPID: leaderPID, memberPIDs: []) }
    }

    func setGroupVolume(gid: String, level: Int) {
        groupVolumes[gid] = min(100, max(0, level))
        Task { await client.setGroupVolume(gid: gid, level: level) }
    }

    func setUniformGroupVolume(_ group: HEOSGroup, level: Int) {
        let clampedLevel = min(100, max(0, level))
        groupVolumes[group.gid] = clampedLevel
        let pids = group.players.map(\.pid)
        for pid in pids {
            states[pid, default: PlayerState(pid: pid)].volume = clampedLevel
        }
        Task { await client.setUniformPlayerVolumes(pids: pids, level: clampedLevel) }
    }

    func toggleGroupMute(gid: String) {
        let muted = !(groupMutes[gid] ?? false)
        groupMutes[gid] = muted
        Task { await client.setGroupMute(gid: gid, muted: muted) }
    }

    func dismissError() { lastError = nil }

    func applicationBecameActive() {
        guard connectedAddress != nil else {
            startAutomaticConnection()
            return
        }
        Task {
            let state = await client.connectionState()
            if state == .connected {
                async let players: Void = client.refreshPlayers()
                async let groups: Void = client.refreshGroups()
                _ = await (players, groups)
            } else { connectToSavedAddress() }
        }
    }

    func apply(_ event: HEOSClientEvent) {
        switch event {
        case .connection(let state):
            connectionState = state
            if state == .connected {
                reconnectTask?.cancel()
                reconnectTask = nil
                if let connectedAddress {
                    settings.lastAddress = connectedAddress
                    reconnectAttemptCount = 0
                }
                lastError = nil
                discoveryState = discoveredDevices.isEmpty ? .idle : .found(discoveredDevices.count)
                Task { await discovery.stop() }
            } else if case .failed(let message) = state {
                lastError = message
                if !connectToNextDiscoveredDevice() { scheduleReconnect() }
            } else if state == .disconnected, shouldReconnect {
                scheduleReconnect()
            }
        case .loadingPlayers(let isLoading):
            isLoadingPlayers = isLoading
        case .players(let newPlayers):
            players = newPlayers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let validIDs = Set(newPlayers.map(\.pid))
            states = states.filter { validIDs.contains($0.key) }
            for player in newPlayers where states[player.pid] == nil { states[player.pid] = PlayerState(pid: player.pid) }
            if let selectedPlayerID, !validIDs.contains(selectedPlayerID) { self.selectedPlayerID = nil }
            if newPlayers.isEmpty { lastError = L10n.string("HEOS-enheten svarade men rapporterade inga tillgängliga spelare.") }
        case .groups(let newGroups):
            groups = newGroups
            let validIDs = Set(newGroups.map(\.gid))
            groupVolumes = groupVolumes.filter { validIDs.contains($0.key) }
            groupMutes = groupMutes.filter { validIDs.contains($0.key) }
        case .groupVolume(let gid, let level): groupVolumes[gid] = level
        case .groupMute(let gid, let muted): groupMutes[gid] = muted
        case .playerAdded(let player):
            players.removeAll { $0.pid == player.pid }
            players.append(player)
            states[player.pid, default: PlayerState(pid: player.pid)] = states[player.pid] ?? PlayerState(pid: player.pid)
        case .playerRemoved(let pid):
            players.removeAll { $0.pid == pid }; states[pid] = nil
            if selectedPlayerID == pid { selectedPlayerID = nil }
        case .playerRenamed(let pid, let name):
            if let index = players.firstIndex(where: { $0.pid == pid }) { players[index].name = name }
        case .state(let pid, let playState):
            states[pid, default: PlayerState(pid: pid)].playState = playState
        case .volume(let pid, let level, let muted):
            states[pid, default: PlayerState(pid: pid)].volume = level
            if let muted { states[pid]?.isMuted = muted }
        case .mute(let pid, let muted):
            states[pid, default: PlayerState(pid: pid)].isMuted = muted
        case .media(let pid, let media):
            states[pid, default: PlayerState(pid: pid)].apply(media)
            if states[pid]?.sourceKind == .unknown,
               states[pid]?.playState == .playing,
               let player = players.first(where: { $0.pid == pid }),
               Self.isSoundbar(player) {
                states[pid]?.sourceKind = .television
            }
        case .error(let message): lastError = message
        }
    }

    func apply(_ event: HEOSDiscoveryEvent) {
        switch event {
        case .searching:
            discoveryState = .searching
        case .device(let device):
            if !discoveredDevices.contains(where: { $0.host == device.host }) {
                discoveredDevices.append(device)
                discoveredDevices.sort { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
            }
            discoveryState = .found(discoveredDevices.count)
            if connectionState == .disconnected || isFailedConnection {
                _ = connectToNextDiscoveredDevice()
            }
        case .finished(let devices):
            discoveredDevices = devices
            discoveryState = devices.isEmpty ? .idle : .found(devices.count)
            if connectionState == .disconnected || isFailedConnection {
                _ = connectToNextDiscoveredDevice()
            }
        case .failed(let message):
            discoveryState = .failed(message)
            if connectionState == .disconnected && settings.lastAddress.isEmpty {
                lastError = message
            }
        }
    }

    private static func isSoundbar(_ player: HEOSPlayer) -> Bool {
        let description = [player.name, player.model].compactMap { $0 }.joined(separator: " ").lowercased()
        return description.contains("soundbar") || description.contains("homecinema") || description.contains("home cinema") || description.contains("bar")
    }

    private func connectCandidate(_ host: String, reconnecting: Bool) {
        guard connectionState != .connected && connectionState != .connecting && connectionState != .reconnecting else { return }
        attemptedHosts.insert(host)
        connectedAddress = host
        Task { await client.connect(host: host, reconnecting: reconnecting) }
    }

    private var isFailedConnection: Bool {
        if case .failed = connectionState { return true }
        return false
    }

    @discardableResult
    private func connectToNextDiscoveredDevice() -> Bool {
        guard let device = discoveredDevices.first(where: { !attemptedHosts.contains($0.host) }) else { return false }
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttemptCount = 0
        shouldReconnect = true
        lastError = nil
        connectCandidate(device.host, reconnecting: false)
        return true
    }

    private func scheduleReconnect() {
        guard shouldReconnect,
              reconnectAttemptCount < 3,
              let address = connectedAddress ?? SettingsStore.normalizedAddress(settings.lastAddress) else { return }
        reconnectTask?.cancel()
        let delaySeconds = 1 << reconnectAttemptCount
        reconnectAttemptCount += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard !Task.isCancelled else { return }
            self?.connectCandidate(address, reconnecting: true)
        }
    }
}

extension PlayerRepository {
    static var preview: PlayerRepository {
        let repository = PlayerRepository()
        repository.connectionState = .connected
        repository.connectedAddress = "heos.local"
        repository.players = MockData.players
        repository.states = MockData.states
        repository.groups = MockData.groups
        repository.groupVolumes = ["10": 31]
        repository.groupMutes = ["10": false]
        return repository
    }
}
