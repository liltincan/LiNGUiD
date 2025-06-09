import SwiftUI

struct RootCoordinatorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject var userSession = UserSessionViewModel()
    @StateObject private var vm = LoginViewModel()
    
    @State private var isNavigatingToDeepLink = false

    init () {
        // logout()
    }

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isSignedIn {
                    AuthCoordinatorView(onSuccessfulLogin: {
                        appState.isSignedIn = true
                        userSession.getCurrentUser()
                    })
                    .onAppear {
                        let isUserAuthenticated = FirebaseAuthService.shared.currentUserID != nil
                        if isUserAuthenticated {
                            Task {
                                let exists = await userSession.checkUserExists()
                                appState.isSignedIn = true
                                appState.needsOnboarding = !exists

                                if exists {
                                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                                }
                            }
                        }
                    }
                } else if appState.needsOnboarding {
                    OnboardingFlowView {
                        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                        appState.needsOnboarding = false
                    }
                    .environmentObject(userSession)
                } else {
                    MainTabView()
                        .environmentObject(userSession)
                }
            }
            .environmentObject(userSession)

            NavigationLink(
                isActive: $isNavigatingToDeepLink
            ) {
                EmptyView()
            } destination: {
                viewForDeepLink()
            }
        }
        .onChange(of: deepLinkCoordinator.deepLinkVideoID) { newId in
            isNavigatingToDeepLink = (newId != nil)
        }
        .onChange(of: isNavigatingToDeepLink) { isActive in
            if !isActive {
                deepLinkCoordinator.deepLinkVideoID = nil
            }
        }
    }
    
    @ViewBuilder
    private func viewForDeepLink() -> some View {
        if let videoId = deepLinkCoordinator.deepLinkVideoID,
           let url = URL(string: "https://learnwithlinguid.com/videos/\(videoId).mp4"),
           UIApplication.shared.canOpenURL(url) {
            VideoPlayerView(url: url, videoId: videoId)
        } else {
            print("⚠️ Invalid or missing video URL for ID: \(deepLinkCoordinator.deepLinkVideoID ?? "nil")")
            Text("Video unavailable")
                .font(.headline)
                .foregroundColor(.gray)
                .padding()
        }
    }


    func logout() {
        let result = vm.logout()
        if result {
            print("Logout successful")
        }
    }
}

