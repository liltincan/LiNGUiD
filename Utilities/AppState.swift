import Foundation

@MainActor
class AppState: ObservableObject {
    @Published var isSignedIn = false
    @Published var needsOnboarding = false
    @Published var notificationVideoIdToPresent: String?

    init() {
        isSignedIn = FirebaseAuthService.shared.currentUserID != nil
        //needsOnboarding = !UserDefaults.standard.bool(forKey: "didCompleteOnboarding")
    }
    
    func handleNotification(videoId: String) {
        notificationVideoIdToPresent = videoId
    }

    func clearNotificationVideo() {
        notificationVideoIdToPresent = nil
    }
}
