import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

@main
struct LiNGUiDApp: App {
    @StateObject private var state = AppState()

    init() {
        FirebaseApp.configure()
        DependencyContainer.shared.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environmentObject(state) 
                .environment(\.font, .custom("Poppins-Regular", size: 16))
        }
    }
}
