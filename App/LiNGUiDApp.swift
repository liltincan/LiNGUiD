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
    @StateObject var notificationService = NotificationService()
    @StateObject private var uploadManager = UploadManager()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var backgroundUploader = BackgroundUploader.shared


    init() {
        _ = BackgroundUploader.shared
        DependencyContainer.shared.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environmentObject(state)
                .environmentObject(uploadManager)
                .environmentObject(backgroundUploader)
                .environment(\.font, .custom("Poppins", size: 16))
                .environmentObject(deepLinkCoordinator)
                .environmentObject(notificationService)
                .onOpenURL { url in
                    deepLinkCoordinator.handle(url: url)
                }
                .onAppear {
                    notificationService.setupNotifications()
                }
        }
    }
}

