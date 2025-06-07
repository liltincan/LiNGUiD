import SwiftUI

struct RootCoordinatorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var userSession = UserSessionViewModel()
    @StateObject private var vm = LoginViewModel()
    
    init () {
//        logout()
    }

    var body: some View {
        Group {
            if !appState.isSignedIn {
                AuthCoordinatorView(onSuccessfulLogin: {
                    appState.isSignedIn = true
                    userSession.getCurrentUser()
                })
                .onAppear {
                    let isUserAuthenticated = FirebaseAuthService.shared.currentUserID != nil
                    if isUserAuthenticated && !appState.isSignedIn {
                        appState.isSignedIn = true
                        userSession.getCurrentUser()
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
    }
    
    func logout(){
        let result = vm.logout()
        if (result){
            print("Logout successful")
        }
    }
}

