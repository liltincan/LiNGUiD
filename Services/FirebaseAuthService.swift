// Services/FirebaseAuthService.swift

import FirebaseAuth

final class FirebaseAuthService: AuthService {
    static let shared = FirebaseAuthService()
    // Removed `private` so you can call `FirebaseAuthService()` if needed
    init() {}

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
