import SwiftUI

struct RootCoordinatorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject var userSession = UserSessionViewModel()
    @StateObject private var vm = LoginViewModel()
    
    @State private var navigationPath = NavigationPath()

    init() {
        // logout()
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationDestination(for: String.self) { videoId in
                    viewForDeepLink(videoId: videoId)
                }
        }
        .onChange(of: deepLinkCoordinator.deepLinkVideoID) { _, newId in
            handleDeepLinkChange(newId)
        }
    }
    
    
    @ViewBuilder
    private var mainContent: some View {
        if !appState.isSignedIn {
            authView
        } else if appState.needsOnboarding {
            onboardingView
        } else {
            mainTabView
        }
    }
    
    
    @ViewBuilder
    private var authView: some View {
        AuthCoordinatorView(onSuccessfulLogin: {
            appState.isSignedIn = true
            userSession.getCurrentUser()
        })
        .onAppear {
            checkExistingAuthentication()
        }
        .environmentObject(userSession)
    }
    
    
    @ViewBuilder
    private var onboardingView: some View {
        OnboardingFlowView {
            UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
            appState.needsOnboarding = false
        }
        .environmentObject(userSession)
    }
    
    
    @ViewBuilder
    private var mainTabView: some View {
        MainTabView()
            .environmentObject(userSession)
    }
    
    
    private func handleDeepLinkChange(_ newId: String?) {
        if let videoId = newId {
            navigationPath.append(videoId)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                deepLinkCoordinator.deepLinkVideoID = nil
            }
        }
    }
    
    
    private func checkExistingAuthentication() {
        let isUserAuthenticated = FirebaseAuthService.shared.currentUserID != nil
        if isUserAuthenticated {
            Task {
                let exists = await userSession.checkUserExists()
                await MainActor.run {
                    appState.isSignedIn = true
                    appState.needsOnboarding = !exists
                    
                    if exists {
                        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func viewForDeepLink(videoId: String) -> some View {
        if let url = URL(string: "https://learnwithlinguid.com/videos/\(videoId).mp4"),
           UIApplication.shared.canOpenURL(url) {
            VideoPlayerView(url: url, videoId: videoId)
        } else {
            Text("Video unavailable")
                .font(.headline)
                .foregroundColor(.gray)
                .padding()
                .onAppear {
                    print("⚠️ Invalid or missing video URL for ID: \(videoId)")
                }
        }
    }

    func logout() {
        let result = vm.logout()
        if result {
            print("Logout successful")
        }
    }
}
