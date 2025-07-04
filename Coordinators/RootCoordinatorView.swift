import SwiftUI

struct RootCoordinatorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject var userSession = UserSessionViewModel()
    @StateObject private var vm = LoginViewModel()
    @State private var selectedTab: Int = 0
    
    @State private var navigationPath = NavigationPath()
    
    @State private var startingVideoId: String? = nil

    init() {
        // logout()
    }

    var body: some View {
        mainContent
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
        MainTabView(
            selectedTab: $selectedTab,
            deepLinkedVideoID: startingVideoId,
            onLogout: logout
        )
        .environmentObject(userSession)
    }
    
    
    private func handleDeepLinkChange(_ newId: String?) {
        guard let videoId = newId else { return }
        
        // Reset ViewModel's videos and set starting video ID to the new one:
        startingVideoId = nil
        selectedTab = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startingVideoId = videoId
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
    

    // Updated logout function that properly updates app state
    func logout() {
        let result = vm.logout()
        if result {
            // Clear user session data
            userSession.clearUserData()
            
            // Reset app state to show login screen
            appState.isSignedIn = false
            appState.needsOnboarding = UserDefaults.standard.bool(forKey: "didCompleteOnboarding") == false
            
            // Clear navigation path
            navigationPath = NavigationPath()
            
            print("Logout successful - navigating to login")
        } else {
            print("Logout failed")
        }
    }
}
