import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Button("Stäng", systemImage: "xmark", action: onDismiss).labelStyle(.iconOnly)
        }
        .padding(14)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 5)
    }
}
