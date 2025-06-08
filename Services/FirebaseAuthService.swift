import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices

final class FirebaseAuthService: AuthService {

    static let shared = FirebaseAuthService()
    init() {}

    private let db = Firestore.firestore()

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    private func saveUserData(user: FirebaseAuth.User, loginMethod: String, isNewUser: Bool = false) {
        guard isNewUser else { return }

        let email = user.email ?? ""
        let username = email.components(separatedBy: "@").first ?? "user"

        let userData: [String: Any] = [
            "id": user.uid,
            "email": email,
            "userName": username,
            "loginWith": loginMethod,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("Error saving user data to Firestore: \(error.localizedDescription)")
            } else {
                print("User data saved for new user: \(user.uid)")
            }
        }
    }


    func userDocumentExists(uid: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            return doc.exists
        } catch {
            print("Error checking user document:", error.localizedDescription)
            return false
        }
    }

    @MainActor
    func registerOrLogin(email: String, password: String, appState: AppState) async -> String? {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            saveUserData(user: result.user, loginMethod: "email", isNewUser: true)
            UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
            appState.needsOnboarding = true
            return nil
        } catch let error as NSError {
            if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                do {
                    _ = try await Auth.auth().signIn(withEmail: email, password: password)
                    return nil
                } catch {
                    return "Incorrect password for existing account." // Provide a more specific error
                }
            }
            return error.localizedDescription
        }
    }

    func signOut() throws {
        // Sign out from Google first if they are signed in via Google
        if GIDSignIn.sharedInstance.currentUser != nil {
            GIDSignIn.sharedInstance.signOut()
            print("Signed out from Google.")
        }
        
        // Always attempt to sign out from Firebase Auth
        do {
            try Auth.auth().signOut()
            print("Signed out from Firebase.")
        } catch {
            print("Error signing out from Firebase: \(error.localizedDescription)")
            throw error // Re-throw the error for the caller to handle
        }
    }

    func signInWithGoogle(presenting: UIViewController, appState: AppState) async throws -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Google client ID not found.")
            throw NSError(domain: "FirebaseAuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Google client ID not found."])
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                print("Missing ID Token from Google.")
                throw NSError(domain: "FirebaseAuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing ID Token from Google."])
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user

            // Check if the user document exists in Firestore and save if it's a new user
            let exists = await userDocumentExists(uid: firebaseUser.uid)
            if !exists {
                saveUserData(user: firebaseUser, loginMethod: "google", isNewUser: true)
                UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
                await MainActor.run {
                    appState.needsOnboarding = true
                }
            } else {
                // If user exists, update login method if necessary (e.g., if linked later)
                // This is optional; you might want to update the 'loginWith' field only if it changes
                db.collection("users").document(firebaseUser.uid).updateData(["loginWith": "google"]) { error in
                    if let error = error {
                        print("Error updating login method for existing user: \(error.localizedDescription)")
                    }
                }
            }

            return true

        } catch {
            print("Google sign-in failed:", error.localizedDescription)
            throw error // Re-throw the error
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String, appState: AppState) async throws {
        guard let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            throw NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid identity token from Apple."])
        }

        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: tokenString,
            rawNonce: rawNonce
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            let firebaseUser = result.user

            let exists = await userDocumentExists(uid: firebaseUser.uid)
            if !exists {
                saveUserData(user: firebaseUser, loginMethod: "apple", isNewUser: true)
                UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
                await MainActor.run {
                    appState.needsOnboarding = true
                }
            } else {
                db.collection("users").document(firebaseUser.uid).updateData(["loginWith": "apple"]) { error in
                    if let error = error {
                        print("Error updating login method for existing user: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Apple sign-in failed:", error.localizedDescription)
            throw error // Re-throw the error
        }
    }

    // MARK: - Email and Password Management (New Additions)

    func linkEmailPassword(email: String, password: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No user signed in to link credentials."])
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            _ = try await user.link(with: credential)
            print("Email/Password successfully linked to current user.")
            // Optionally update Firestore to reflect the new login method if it was purely Google before
            db.collection("users").document(user.uid).updateData(["loginWith": "email/google"]) { error in
                if let error = error {
                    print("Error updating login method in Firestore after linking: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error linking email/password: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }

    func updateEmail(to newEmail: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: 101, userInfo: [NSLocalizedDescriptionKey: "No user signed in to update email."])
        }
        do {
            try await user.updateEmail(to: newEmail)
            print("User email updated to: \(newEmail)")
            // Update email in Firestore as well
            db.collection("users").document(user.uid).updateData(["email": newEmail]) { error in
                if let error = error {
                    print("Error updating email in Firestore: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error updating email: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }

    func updatePassword(to newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: 102, userInfo: [NSLocalizedDescriptionKey: "No user signed in to update password."])
        }
        do {
            try await user.updatePassword(to: newPassword)
            print("User password updated successfully.")
        } catch {
            print("Error updating password: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: 103, userInfo: [NSLocalizedDescriptionKey: "No user signed in to send verification email."])
        }
        do {
            try await user.sendEmailVerification()
            print("Email verification sent to: \(user.email ?? "N/A")")
        } catch {
            print("Error sending email verification: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }

    func reloadCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: 104, userInfo: [NSLocalizedDescriptionKey: "No user signed in to reload."])
        }
        do {
            try await user.reload()
            print("Current user reloaded.")
        } catch {
            print("Error reloading current user: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }
    func verifyBeforeUpdateEmail(to newEmail: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in"])
        }
        
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }
}
