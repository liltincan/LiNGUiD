import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import UIKit

@MainActor
class LoginViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService = FirebaseAuthService.shared) {
        self.authService = authService
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
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

            email = ""
            password = ""
            errorMessage = nil

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loginWithGoogle(presenting: UIViewController, onSuccess: @escaping () -> Void) {
        Task {
            do {
                let success = try await authService.signInWithGoogle(presenting: presenting)
                if success {
                    onSuccess()
                } else {
                    errorMessage = "Google sign-in failed"
                }
            } catch {
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
    
    func startSignInWithAppleFlow(onSuccess: @escaping () -> Void) {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()

        self.onSuccessCallback = onSuccess
    }
    
    private var onSuccessCallback: (() -> Void)?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            loginWithApple(credential: credential) {
                self.onSuccessCallback?()
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    
    final class AppleSignInContext: NSObject, ASAuthorizationControllerPresentationContextProviding {
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            return UIApplication.shared.windows.first { $0.isKeyWindow }!
        }
    }


    
    
    
    func logout() -> Bool {
        do {
            try authService.signOut()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

}


