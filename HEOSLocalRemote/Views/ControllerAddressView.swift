import SwiftUI

struct ControllerAddressView: View {
    @ObservedObject var repository: PlayerRepository
    @Environment(\.dismiss) private var dismiss
    @State private var address: String

    init(repository: PlayerRepository) {
        self.repository = repository
        _address = State(initialValue: repository.connectedAddress ?? repository.savedAddress)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.1.50 eller heos.local", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit(changeAddress)
                    if let current = repository.connectedAddress {
                        LabeledContent("Ansluten via", value: current)
                    }
                } header: {
                    Text("HEOS-controller")
                } footer: {
                    Text("Ange adressen till valfri HEOS-spelare på nätverket. Appen hämtar hela HEOS-systemet via den enheten.")
                }
            }
            .navigationTitle("HEOS-adress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anslut", action: changeAddress)
                        .disabled(SettingsStore.normalizedAddress(address) == nil)
                }
            }
        }
    }

    private func changeAddress() {
        if repository.changeController(to: address) { dismiss() }
    }
}

#Preview { ControllerAddressView(repository: PlayerRepository.preview) }
