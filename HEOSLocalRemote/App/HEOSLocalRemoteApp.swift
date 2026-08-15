import SwiftUI

@main
struct HEOSLocalRemoteApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState.repository)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.repository.applicationBecameActive()
            }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    let repository = PlayerRepository()
}
