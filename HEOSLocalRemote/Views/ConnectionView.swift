import SwiftUI

struct ConnectionView: View {
    @ObservedObject var repository: PlayerRepository
    @StateObject private var viewModel: ConnectionViewModel
    @Environment(\.openURL) private var openURL

    init(repository: PlayerRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: ConnectionViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "hifispeaker.2.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(.tint)
                        Text("HEOS Remote").font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text("Lokal fjärrkontroll utan konto eller moln")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 16) {
                        if repository.connectionState == .connecting || repository.connectionState == .reconnecting || repository.discoveryState == .searching {
                            ProgressView().controlSize(.large)
                        } else {
                            Image(systemName: "network")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                        Text(statusTitle).font(.headline)
                        Text("Söker automatiskt efter HEOS-spelare på ditt lokala nätverk. Du kan alltid ansluta manuellt nedan.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                        Button("Sök efter HEOS-enheter", systemImage: "dot.radiowaves.left.and.right") {
                            repository.searchForDevices()
                        }
                        .buttonStyle(.bordered)
                        .disabled(repository.discoveryState == .searching)
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("HEOS-adress").font(.headline)
                        TextField("192.168.1.50 eller heos.local", text: $viewModel.address)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.go)
                            .onSubmit { if viewModel.canConnect { viewModel.connect() } }
                        Button("Anslut", action: viewModel.connect)
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.canConnect)
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                    if let error = repository.lastError {
                        ErrorBanner(message: error, onDismiss: repository.dismissError)
                        if error.localizedCaseInsensitiveContains("nätverk") || error.localizedCaseInsensitiveContains("network") || error.localizedCaseInsensitiveContains("multicast") {
                            Button("Öppna Inställningar") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .task { repository.startAutomaticConnection() }
        }
    }

    private var statusTitle: String {
        switch repository.connectionState {
        case .connecting, .reconnecting: L10n.string("Ansluter till HEOS…")
        default:
            repository.discoveryState == .searching ? L10n.string("Söker efter HEOS…") : L10n.string("Anslut till HEOS")
        }
    }
}

#Preview { ConnectionView(repository: PlayerRepository()) }
