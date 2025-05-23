import FirebaseAuth

final class FirebaseAuthService: AuthService {
    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    func signIn(email: String, password: String) async throws {
        // TODO: implement Firebase Auth email/password sign-in
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        // TODO: implement sign-out
        try Auth.auth().signOut()
    }
}
