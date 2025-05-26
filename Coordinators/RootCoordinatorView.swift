import SwiftUI

struct RootCoordinatorView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if !state.isSignedIn {
                
                AuthCoordinatorView()
                    .onAppear {
                        print(state.isSignedIn)
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


