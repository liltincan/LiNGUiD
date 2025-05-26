import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import UIKit

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService = FirebaseAuthService.shared) {
        self.authService = authService
    }

    /// Returns true on success, false on failure
    @MainActor
    func login() async -> Bool {
        guard !email.isEmpty else {
            errorMessage = "Email is required"
            return false
        }

        do {
            let result = try await authService.registerOrLogin(email: email, password: password)
            if let error = result {
                errorMessage = error
                return false
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    
    func loginWithGoogle(presenting: UIViewController, onSuccess: @escaping ()-> Void ){
        Task{
            do{
                let success = try await authService.signInWithGoogle(presenting: presenting)
                if (success){
                    onSuccess()
                }
            } catch{
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private var currentNonce: String?

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
    }

    func loginWithApple(credential: ASAuthorizationAppleIDCredential, onSuccess: @escaping () -> Void) {
        Task {
            do {
                guard let nonce = currentNonce else {
                    errorMessage = "Missing nonce"
                    return
                }

                try await authService.signInWithApple(credential: credential, rawNonce: nonce)
                onSuccess()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    
    
    
    func logout() -> Bool {
        // Google Sign-Out
        GIDSignIn.sharedInstance.signOut()

        // Firebase Sign-Out
        try? Auth.auth().signOut()
        
        return true
    }
}
