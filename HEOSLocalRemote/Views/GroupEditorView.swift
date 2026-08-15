import SwiftUI

struct GroupEditorView: View {
    @ObservedObject var repository: PlayerRepository
    let leader: HEOSPlayer
    @Environment(\.dismiss) private var dismiss
    @AppStorage("confirmedExternalInputStopForGrouping") private var confirmedExternalInputStop = false
    @State private var selectedIDs: Set<String>
    @State private var showingStopConfirmation = false

    init(repository: PlayerRepository, leader: HEOSPlayer) {
        self.repository = repository
        self.leader = leader
        let existing = repository.group(for: leader.pid)?.playerIDs ?? [leader.pid]
        _selectedIDs = State(initialValue: existing)
    }

    var body: some View {
        NavigationStack {
            List(repository.players) { player in
                Button {
                    guard player.pid != leader.pid else { return }
                    if selectedIDs.contains(player.pid) { selectedIDs.remove(player.pid) }
                    else { selectedIDs.insert(player.pid) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(player.name).foregroundStyle(.primary)
                            if player.pid == leader.pid { Text("Spelar gruppens ljud").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: selectedIDs.contains(player.pid) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIDs.contains(player.pid) ? Color.accentColor : .secondary)
                    }
                }
                .disabled(player.pid == leader.pid)
            }
            .safeAreaInset(edge: .bottom) {
                if leaderUsesExternalInput {
                    Label(L10n.format("TV-/externljudet behålls och %@ blir gruppledare. ‘Gruppera TV-ljud’ måste vara aktiverat för soundbaren.", leader.name), systemImage: "tv.badge.wifi")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                } else if !externalMemberPIDs.isEmpty {
                    Label(L10n.format("TV-/externljud i valda medlemsrum stoppas så att %@s ljud kan ta över.", leader.name), systemImage: "speaker.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                }
            }
            .navigationTitle(leaderUsesExternalInput ? L10n.string("Spela TV-ljud även i…") : L10n.format("Spela %@ även i…", leader.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        saveGroup()
                    }
                }
            }
            .alert("Stoppa TV-/externljud?", isPresented: $showingStopConfirmation) {
                Button("Avbryt", role: .cancel) {}
                Button("Stoppa och gruppera", role: .destructive) {
                    confirmedExternalInputStop = true
                    applyGroup()
                }
            } message: {
                Text(L10n.format("För att spela %@s ljud i de valda rummen behöver appen först stoppa deras aktiva TV- eller externingång. Detta visas bara första gången.", leader.name))
            }
        }
    }

    private var leaderUsesExternalInput: Bool {
        usesExternalInput(leader)
    }

    private var externalMemberPIDs: [String] {
        guard !leaderUsesExternalInput else { return [] }
        return repository.players.compactMap { player in
            guard player.pid != leader.pid,
                  selectedIDs.contains(player.pid),
                  usesExternalInput(player) else { return nil }
            return player.pid
        }
    }

    private func usesExternalInput(_ player: HEOSPlayer) -> Bool {
        let source = repository.state(for: player.pid).sourceKind
        if source.isExternalInput { return true }
        guard source == .unknown else { return false }
        let description = [player.name, player.model].compactMap { $0 }.joined(separator: " ").lowercased()
        return description.contains("homecinema") || description.contains("home cinema") || description.contains("soundbar") || description.contains("heos bar")
    }

    private func saveGroup() {
        if !externalMemberPIDs.isEmpty && !confirmedExternalInputStop {
            showingStopConfirmation = true
        } else {
            applyGroup()
        }
    }

    private func applyGroup() {
        repository.updateGroup(
            leaderPID: leader.pid,
            memberPIDs: Array(selectedIDs.subtracting([leader.pid])),
            stoppingExternalInputPIDs: externalMemberPIDs
        )
        dismiss()
    }
}
