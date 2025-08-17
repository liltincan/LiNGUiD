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
    let locationVerifier = LocationVerifier()

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
                    locationVerifier.verifyAndSaveLocation()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // App became active, check if there's a pending deep link to handle
                        if let videoId = deepLinkCoordinator.deepLinkVideoID {
                            // Re-trigger the deep link handling to ensure proper navigation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                deepLinkCoordinator.deepLinkToVideo(with: videoId)
                            }
                        }
                        // --- Add this block for profile deep links ---
                        if let profileId = deepLinkCoordinator.deepLinkProfileID {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                deepLinkCoordinator.deepLinkToProfile(with: profileId)
                            }
                        }
                    }
                }
            }
        }
    }


