import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct LiNGUiDApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var userSession = UserSessionViewModel()

    init() {
        DependencyContainer.shared.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environmentObject(state)
                .environmentObject(userSession)
                .environment(\.font, .custom("Poppins", size: 16))
        }
    }
}
