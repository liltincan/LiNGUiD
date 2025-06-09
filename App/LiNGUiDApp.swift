import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct LiNGUiDApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()
    @Environment(\.openURL) var openURL
    @StateObject var deepLinkCoordinator = DeepLinkCoordinator()
    

    init() {
        DependencyContainer.shared.registerAll()
        
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environmentObject(state)
                .environment(\.font, .custom("Poppins", size: 16))
                .environmentObject(deepLinkCoordinator)
                .onOpenURL { url in
                    deepLinkCoordinator.handle(url: url)
                }
        }
    }
}

