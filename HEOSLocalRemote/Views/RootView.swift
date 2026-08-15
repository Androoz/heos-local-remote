import SwiftUI

struct RootView: View {
    @EnvironmentObject private var repository: PlayerRepository

    var body: some View {
        Group {
            if repository.connectionState == .connected {
                PlayerListView(repository: repository)
            } else {
                ConnectionView(repository: repository)
            }
        }
        .animation(.default, value: repository.connectionState)
    }
}

#Preview { RootView().environmentObject(PlayerRepository.preview) }
