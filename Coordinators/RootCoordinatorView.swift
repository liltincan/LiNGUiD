import SwiftUI

struct RootCoordinatorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isSignedIn {
                AuthCoordinatorView(onSuccessfulLogin: {
                    appState.isSignedIn = true
                })
                .onAppear {
                    let isUserAuthenticated = FirebaseAuthService.shared.currentUserID != nil
                    if isUserAuthenticated && !appState.isSignedIn {
                        appState.isSignedIn = true
                    }
                }
            } else if appState.needsOnboarding {
                OnboardingFlowView {
                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                    appState.needsOnboarding = false
                }
            } else {
                MainTabView()
            }
        }
    }
}

