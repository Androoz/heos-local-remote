import SwiftUI

struct ConnectionStatusView: View {
    let state: HEOSConnectionState
    var compact = false

    private var color: Color {
        switch state {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .failed: .red
        case .disconnected: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 9, height: 9)
            if !compact { Text(state.label).font(.subheadline.weight(.medium)) }
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("Anslutningsstatus: %@", state.label))
    }
}
