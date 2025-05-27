import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

@main
struct LiNGUiDApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    init() {
        DependencyContainer.shared.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environmentObject(state) 
                .environment(\.font, .custom("Poppins", size: 16))
        }
    }
}
