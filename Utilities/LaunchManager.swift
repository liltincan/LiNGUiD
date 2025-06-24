import FirebaseAuth

class LaunchManager {
    static let shared = LaunchManager()

    func checkFirstLaunchAndLogoutIfNeeded() {
        let defaults = UserDefaults.standard
        let hasLaunchedKey = "hasLaunchedBefore"

        if defaults.bool(forKey: hasLaunchedKey) == false {
            // This is the first launch after reinstall
            defaults.set(true, forKey: hasLaunchedKey)

            if Auth.auth().currentUser != nil {
                do {
                    try Auth.auth().signOut()
                    print("✅ User signed out on first launch after reinstall")
                } catch {
                    print("❌ Error signing out: \(error.localizedDescription)")
                }
            }
        }
    }
}
