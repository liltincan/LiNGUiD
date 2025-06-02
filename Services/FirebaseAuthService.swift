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

        let newUser = User(
            id: user.uid,
            email: email,
            username: username,
            uploadedVideos: [],
            savedVideos: [],
            watchedVideos: [],
            likedVideos: [],
            chats: [],
            savedWords: [],
            followers: [],
            following: [],
            country: "",
            nativeLanguages: [],
            targetLanguages: []
        )

        do {
            try db.collection("users").document(user.uid).setData(from: newUser)
        } catch {
            print("Failed to save user: \(error.localizedDescription)")
        }

    }


    private func userDocumentExists(uid: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            return doc.exists
        } catch {
            print("Error checking user document:", error.localizedDescription)
            return false
        }
    }

    @MainActor
    func registerOrLogin(email: String, password: String) async -> String? {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            saveUserData(user: result.user, loginMethod: "email", isNewUser: true)
            return nil
        } catch let error as NSError {
            if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                do {
                    _ = try await Auth.auth().signIn(withEmail: email, password: password)
                    return nil
                } catch {
                    return "Incorrect password for existing account"
                }
            }
            return error.localizedDescription
        }
    }

    func signOut() throws {
        if GIDSignIn.sharedInstance.currentUser != nil {
            GIDSignIn.sharedInstance.signOut()
            try? Auth.auth().signOut()
        }
        try Auth.auth().signOut()
    }

    func signInWithGoogle(presenting: UIViewController) async throws -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return false }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                print("Missing ID Token")
                return false
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user

            let exists = await userDocumentExists(uid: firebaseUser.uid)
            if !exists {
                saveUserData(user: firebaseUser, loginMethod: "google", isNewUser: true)
            }

            return true

        } catch {
            print("Google sign-in failed:", error.localizedDescription)
            return false
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        guard let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            throw NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid identity token"])
        }

        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: tokenString,
            rawNonce: rawNonce
        )

        let result = try await Auth.auth().signIn(with: firebaseCredential)
        let firebaseUser = result.user

        let exists = await userDocumentExists(uid: firebaseUser.uid)
        if !exists {
            saveUserData(user: firebaseUser, loginMethod: "apple", isNewUser: true)
        }
    }
}
