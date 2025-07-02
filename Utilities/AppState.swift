import Foundation

@MainActor
class AppState: ObservableObject {
    @Published var isSignedIn = false
    @Published var needsOnboarding = false

    init() {
        isSignedIn = FirebaseAuthService.shared.currentUserID != nil
        //needsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
    }
}
