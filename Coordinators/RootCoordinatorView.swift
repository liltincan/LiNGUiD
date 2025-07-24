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
    
    @EnvironmentObject var notificationService: NotificationService

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
        .onChange(of: notificationService.notificationVideoId) { _, newId in
            guard let id = newId else { return }

            print("Opening video from notification: \(id)")
            
            // Step 1: reset startingVideoId to nil to force a reload
            startingVideoId = nil
            
            // Step 2: small delay, then assign the new video id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startingVideoId = id
                selectedTab = 0
            }

            // Step 3: reset the notification id so this handler can fire again next time
            notificationService.notificationVideoId = nil
        }

    }
    
    @ViewBuilder
    private var mainContent: some View {
        if !appState.isSignedIn {
            authView
        } else if appState.needsOnboarding {
            onboardingView
        } else {
            MainTabView(
                selectedTab: $selectedTab,
                deepLinkedVideoID: $startingVideoId,
                onLogout: logout
            )
            .id(startingVideoId) // Important: triggers view reload when ID changes
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
            let firestoreCompleted = try await FirestoreService.shared.getOnboardingStatus()
            let localCompleted = UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
            
            await MainActor.run {
                appState.needsOnboarding = !(firestoreCompleted || localCompleted)
                hasCheckedOnboarding = true
            }
            
            if !firestoreCompleted && localCompleted {
                try await FirestoreService.shared.updateOnboardingStatus(completed: true)
            }
        } catch {
            print("Error checking onboarding:", error)
            await MainActor.run {
                appState.needsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
                hasCheckedOnboarding = true
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
        appState.needsOnboarding = false
        
        Task { @MainActor in
            selectedTab = 0

            do {
                try await FirestoreService.shared.updateOnboardingStatus(completed: true)
            } catch {
                print("Failed to update Firestore onboarding status:", error)
            }
        }
    }
    
    private func handleDeepLinkChange(_ newId: String?) {
        guard let videoId = newId else { return }

        startingVideoId = nil // Reset to trigger reload
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
                    
                    if exists {
                        FirestoreService.shared.getOnboardingStatus { result in
                            switch result {
                            case .success(let completed):
                                appState.needsOnboarding = !completed
                                UserDefaults.standard.set(completed, forKey: "didCompleteOnboarding")
                            case .failure:
                                appState.needsOnboarding = true
                            }
                        }
                    } else {
                        appState.needsOnboarding = true
                        UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
                    }
                }
            }
        }
    }
    
    func logout() {
        let result = vm.logout()
        if result {
            userSession.clearUserData()
            appState.isSignedIn = false
            appState.needsOnboarding = UserDefaults.standard.bool(forKey: "didCompleteOnboarding") == false
            navigationPath = NavigationPath()
            print("Logout successful - navigating to login")
        } else {
            print("Logout failed")
        }
    }
}

