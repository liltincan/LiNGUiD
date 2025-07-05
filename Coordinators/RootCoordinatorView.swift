import SwiftUI
import FirebaseAuth

struct RootCoordinatorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject var userSession = UserSessionViewModel()
    @StateObject private var vm = LoginViewModel()
    @State private var hasCheckedOnboarding = false
    @State private var selectedTab: Int = 0
    @State private var navigationPath = NavigationPath()
    
    @State private var startingVideoId: String? = nil

    init() {
        // logout()
    }

    var body: some View {
        ZStack {
            if !hasCheckedOnboarding {
                ProgressView()
            } else {
                mainContent
            }
        }
        .task {
            await checkInitialState()
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
        } else if startingVideoId != nil {
            // Deep link takes priority — show feed with specific video
            MainTabView(
                selectedTab: $selectedTab,
                deepLinkedVideoID: $startingVideoId,
                onLogout: logout
            )
            .id(startingVideoId) // Important: triggers view reload if ID changes
            .environmentObject(userSession)
        } else {
            // Default signed-in experience
            MainTabView(
                selectedTab: $selectedTab,
                deepLinkedVideoID: $startingVideoId,
                onLogout: logout
            )
            .environmentObject(userSession)
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
            // This runs when onboarding completes
            completeOnboarding()
        }
        .environmentObject(userSession)
        
    }
    
    private func checkInitialState() async {
        guard appState.isSignedIn else {
            hasCheckedOnboarding = true
            return
        }
        
        do {
            // 1. First try to get from Firestore
            let firestoreCompleted = try await FirestoreService.shared.getOnboardingStatus()
            
            // 2. If not found in Firestore, check local storage
            let localCompleted = UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
            
            await MainActor.run {
                appState.needsOnboarding = !(firestoreCompleted || localCompleted)
                hasCheckedOnboarding = true
            }
            
            // 3. If Firestore says incomplete but local says complete, sync to Firestore
            if !firestoreCompleted && localCompleted {
                try await FirestoreService.shared.updateOnboardingStatus(completed: true)
            }
        } catch {
            print("Error checking onboarding:", error)
            // Fallback to local storage
            await MainActor.run {
                appState.needsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
                hasCheckedOnboarding = true
            }
        }
    }
    
    private func completeOnboarding() {
        // Update local state immediately
        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
        appState.needsOnboarding = false
        
        // Update Firestore async
        Task {
            do {
                try await FirestoreService.shared.updateOnboardingStatus(completed: true)
            } catch {
                print("Failed to update Firestore onboarding status:", error)
                // You might want to retry this later
            }
        }
    }
    
    private func checkOnboardingStatus() async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        do {
            // First check Firestore
            let firestoreCompleted = try await FirestoreService.shared.getOnboardingStatus()
            
            // Then check local UserDefaults as fallback
            let localCompleted = UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
            
            await MainActor.run {
                appState.needsOnboarding = !(firestoreCompleted || localCompleted)
                if !appState.needsOnboarding {
                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                }
            }
        } catch {
            print("Error checking onboarding status: \(error)")
            await MainActor.run {
                // Fallback to local storage if Firestore fails
                appState.needsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
            }
        }
    }
    
    
    @ViewBuilder
    private var mainTabView: some View {
        MainTabView(
            selectedTab: $selectedTab,
            deepLinkedVideoID: $startingVideoId,
            onLogout: logout
        )
        .environmentObject(userSession)
    }
    
    
    private func handleDeepLinkChange(_ newId: String?) {
        guard let videoId = newId else { return }

        startingVideoId = nil // reset to trigger .task
        selectedTab = 0 // ensure you're showing video feed

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
                    
                    if exists {
                        // Check onboarding status from Firestore
                        FirestoreService.shared.getOnboardingStatus { result in
                            switch result {
                            case .success(let completed):
                                appState.needsOnboarding = !completed
                                UserDefaults.standard.set(completed, forKey: "didCompleteOnboarding")
                            case .failure:
                                // If we can't check, assume onboarding is needed
                                appState.needsOnboarding = true
                            }
                        }
                    } else {
                        // New user needs onboarding
                        appState.needsOnboarding = true
                        UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
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
