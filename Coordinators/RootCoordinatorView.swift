import SwiftUI

struct RootCoordinatorView: View {
    @StateObject private var state = AppState()

    var body: some View {
        Group {
            if !state.isSignedIn {
                AuthCoordinatorView()
                    .onAppear {
                        // in case user restored session
                        state.isSignedIn = FirebaseAuthService.shared.currentUserID != nil
                    }
            } else if state.needsOnboarding {
                OnboardingFlowView {
                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                    state.needsOnboarding = false
                }
            } else {
                MainTabView()
            }
        }
    }
}


