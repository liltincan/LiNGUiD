// Services/FirebaseAuthService.swift

import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import AuthenticationServices


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
        if(GIDSignIn.sharedInstance.currentUser != nil){
            GIDSignIn.sharedInstance.signOut()
            try? Auth.auth().signOut()
        }
        try Auth.auth().signOut()
    }
    
    
    
    // Sign in with Google
    
    func signInWithGoogle(presenting: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        let config = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                print("Missing ID Token")
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            try await Auth.auth().signIn(with: credential)
            
            
        } catch {
            print("Google sign-in failed:", error.localizedDescription)
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
        try await Auth.auth().signIn(with: firebaseCredential)
    }
}

