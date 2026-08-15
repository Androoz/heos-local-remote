import SwiftUI

struct CompactVolumeControl: View {
    let volume: Int
    let isMuted: Bool
    let setVolume: (Int) -> Void
    let toggleMute: () -> Void
    let sendsWhileEditing: Bool
    @State private var sliderValue: Double
    @State private var isEditing = false
    @State private var pendingSend: Task<Void, Never>?

    init(volume: Int, isMuted: Bool, sendsWhileEditing: Bool = true, setVolume: @escaping (Int) -> Void, toggleMute: @escaping () -> Void) {
        self.volume = volume
        self.isMuted = isMuted
        self.setVolume = setVolume
        self.toggleMute = toggleMute
        self.sendsWhileEditing = sendsWhileEditing
        _sliderValue = State(initialValue: Double(volume))
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggleMute) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isMuted ? .red : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isMuted ? L10n.string("Slå på ljud") : L10n.string("Stäng av ljud"))

            Slider(value: $sliderValue, in: 0...100, step: 1) { editing in
                isEditing = editing
                if !editing { sendImmediately() }
            }
            .onChange(of: sliderValue) { _, newValue in
                guard isEditing, sendsWhileEditing else { return }
                pendingSend?.cancel()
                pendingSend = Task {
                    try? await Task.sleep(for: .milliseconds(180))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { setVolume(Int(newValue.rounded())) }
                }
            }

            Text("\(Int(sliderValue.rounded())) %")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .onChange(of: volume) { _, newValue in
            if !isEditing { sliderValue = Double(newValue) }
        }
        .onDisappear { pendingSend?.cancel() }
    }

    private func sendImmediately() {
        pendingSend?.cancel()
        setVolume(Int(sliderValue.rounded()))
    }
}
