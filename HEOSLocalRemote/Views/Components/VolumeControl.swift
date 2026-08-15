import SwiftUI

struct VolumeControl: View {
    let volume: Int
    let isMuted: Bool
    let setVolume: (Int) -> Void
    let toggleMute: () -> Void
    @State private var sliderValue: Double
    @State private var pendingSend: Task<Void, Never>?
    @State private var isEditing = false

    init(volume: Int, isMuted: Bool, setVolume: @escaping (Int) -> Void, toggleMute: @escaping () -> Void) {
        self.volume = volume; self.isMuted = isMuted; self.setVolume = setVolume; self.toggleMute = toggleMute
        _sliderValue = State(initialValue: Double(volume))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: toggleMute) {
                    Label(isMuted ? L10n.string("Slå på ljud") : L10n.string("Stäng av ljud"), systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .labelStyle(.iconOnly).font(.title2)
                }
                Slider(value: $sliderValue, in: 0...100, step: 1) { editing in
                    isEditing = editing
                    if !editing {
                        pendingSend?.cancel()
                        setVolume(Int(sliderValue.rounded()))
                    }
                }
                .onChange(of: sliderValue) { _, newValue in
                    guard isEditing else { return }
                    pendingSend?.cancel()
                    pendingSend = Task {
                        try? await Task.sleep(for: .milliseconds(180))
                        guard !Task.isCancelled else { return }
                        await MainActor.run { setVolume(Int(newValue.rounded())) }
                    }
                }
                Text("\(Int(sliderValue.rounded())) %").monospacedDigit().frame(width: 52, alignment: .trailing)
            }
            if isMuted { Text("Ljudet är avstängt").font(.caption).foregroundStyle(.red) }
        }
        .onChange(of: volume) { _, newValue in if !isEditing { sliderValue = Double(newValue) } }
        .onDisappear { pendingSend?.cancel() }
    }
}
