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
    @State private var deepLinkedProfileId: String? = nil
    @State private var showingProfileSheet = false
    @State private var logoShow = true
    @State private var pendingProfileVideoId: String? = nil
    
    @EnvironmentObject var notificationService: NotificationService

    init() {
        // logout()
    }

    var body: some View {
        ZStack {
            if !hasCheckedOnboarding {
                ProgressView().tint(.clear)
            } else {
                mainContent
            }
        }
        .task {
            await checkInitialState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openProfileFromNotification)) { note in
            NotificationCenter.default.post(name: .pauseAllVideos, object: nil)
            
            if let uid = note.userInfo?["profileId"] as? String {
                deepLinkCoordinator.deepLinkProfileID = uid
            }
            
            if let vid = note.userInfo?["videoId"] as? String, !vid.isEmpty {
                pendingProfileVideoId = vid
            }
        }
        .onChange(of: deepLinkCoordinator.deepLinkVideoID) { _, newId in
            handleDeepLinkVideoChange(newId)
        }
        .onChange(of: deepLinkCoordinator.deepLinkProfileID) { _, newId in
            handleDeepLinkProfileChange(newId)
        }
        .onChange(of: notificationService.notificationVideoId) { _, newId in
            guard let id = newId else { return }
            print("🔔 Opening video from notification: \(id)")
            
            // Reset startingVideoId to nil to force a reload
            startingVideoId = nil
            
            // Small delay, then assign the new video id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startingVideoId = id
                selectedTab = 0
            }

            // Reset the notification id so this handler can fire again next time
            notificationService.notificationVideoId = nil
        }
        .onChange(of: appState.isSignedIn) { _, signedIn in
            if signedIn {
                hasCheckedOnboarding = false
                Task { await checkInitialState() }
            }
        }
        .fullScreenCover(isPresented: $showingProfileSheet, onDismiss: {
            // Ensure we clean up state when dismissed
            print("🔗 Profile sheet dismissed, cleaning up state")
            deepLinkedProfileId = nil
            deepLinkCoordinator.deepLinkProfileID = nil
            pendingProfileVideoId = nil
        }) {
            if let profileId = deepLinkedProfileId {
                // Remove NavigationView wrapper to prevent extra padding
                OtherUserProfileView(
                    userId: profileId,
                    selectedTab: $selectedTab,
                    onLogout: logout,
                    autoOpenVideoId: pendingProfileVideoId
                )
                .environmentObject(userSession)
                .onAppear { NotificationCenter.default.post(name: .pauseAllVideos, object: nil) }
                .onAppear{
                    print("🔗 Opening \(profileId) from deeplink")
                }
                // Force a new instance each time by using a unique ID
                .id(UUID())
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(red: 22/255, green: 1/255, blue: 46/255)
                .edgesIgnoringSafeArea(.all)
            
            if logoShow {
                Image("ApplogoWallpaper")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                logoShow = false
                            }
                        }
                    }
            } else if !appState.isSignedIn {
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
        .animation(.easeInOut, value: logoShow)
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
    
    private func handleDeepLinkVideoChange(_ newId: String?) {
        guard let videoId = newId else { return }
        NotificationCenter.default.post(name: .pauseAllVideos, object: nil)
        
        print("🔗 Processing video deep link: \(videoId)")
        startingVideoId = nil // Reset to trigger reload
        selectedTab = 0

        // Increased delay to ensure proper state transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🔗 Setting video ID in tab view: \(videoId)")
            startingVideoId = videoId
        }
    }
    
    private func handleDeepLinkProfileChange(_ newId: String?) {
        guard let profileId = newId else { return }
        
        print("🔗 Processing profile deep link: \(profileId)")
        
        // Only show profile if user is signed in and past onboarding
        guard appState.isSignedIn && !appState.needsOnboarding else {
            print("🔗 Profile deep link received but user not ready - will process when ready")
            return
        }

        // Prevent double-presentation if already showing the same profile
        if showingProfileSheet && deepLinkedProfileId == profileId {
            print("🔗 Profile sheet already showing for this profile, skipping re-presentation")
            return
        }

        // Dismiss if already showing, then present after a short delay
        if showingProfileSheet {
            print("🔗 Profile sheet already showing, dismissing first")
            showingProfileSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔗 Setting new profile ID after dismissal: \(profileId)")
                self.deepLinkedProfileId = profileId
                // Clear the deep link state to prevent re-trigger
                self.deepLinkCoordinator.deepLinkProfileID = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showingProfileSheet = true
                }
            }
        } else {
            print("🔗 Setting profile ID directly: \(profileId)")
            deepLinkedProfileId = profileId
            // Clear the deep link state to prevent re-trigger
            deepLinkCoordinator.deepLinkProfileID = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingProfileSheet = true
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
                    
                    if exists {
                        FirestoreService.shared.getOnboardingStatus { result in
                            switch result {
                            case .success(let completed):
                                appState.needsOnboarding = !completed
                                UserDefaults.standard.set(completed, forKey: "didCompleteOnboarding")
                                
                                // Check if we have a pending profile deep link
                                if !appState.needsOnboarding, let profileId = deepLinkCoordinator.deepLinkProfileID {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        deepLinkedProfileId = profileId
                                        showingProfileSheet = true
                                    }
                                }
                                
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
            // Clear any pending deep links
            deepLinkedProfileId = nil
            showingProfileSheet = false
            startingVideoId = nil
            print("Logout successful - navigating to login")
        } else {
            print("Logout failed")
        }
    }
}
