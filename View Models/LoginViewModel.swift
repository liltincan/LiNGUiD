import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import UIKit
import FirebaseFirestore


@MainActor
class LoginViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private var currentNonce: String?
    private var onSuccessCallback: (() -> Void)?
    private var currentAppState: AppState?



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
    func login(appState: AppState) async -> Bool {
        guard !email.isEmpty else {
            errorMessage = "Email is required"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await authService.registerOrLogin(email: email, password: password, appState: appState)
            if let error = result {
                errorMessage = error
                return false
            }

            await ensureUserDocumentDefaults(email: email)
            
            email = ""
            password = ""
            errorMessage = nil

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loginWithGoogle(presenting: UIViewController, appState: AppState, onSuccess: @escaping () -> Void) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let success = try await authService.signInWithGoogle(presenting: presenting, appState: appState)
                if success {
                    await ensureUserDocumentDefaults(email: Auth.auth().currentUser?.email)
                    onSuccess()
                } else {
                    errorMessage = "Google sign-in failed"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
    }

    func loginWithApple(credential: ASAuthorizationAppleIDCredential, appState: AppState, onSuccess: @escaping () -> Void) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                guard let nonce = currentNonce else {
                    errorMessage = "Missing nonce"
                    return
                }

                try await authService.signInWithApple(credential: credential, rawNonce: nonce, appState: appState)
                await ensureUserDocumentDefaults(email: Auth.auth().currentUser?.email)
                onSuccess()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func startSignInWithAppleFlow(appState: AppState, onSuccess: @escaping () -> Void) {
        self.currentAppState = appState
        self.onSuccessCallback = onSuccess

        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ Apple delegate method called")

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appState = currentAppState else {
            print("❌ Missing credential, nonce, or appState")
            errorMessage = "Missing required Apple Sign-In data"
            return
        }

        loginWithApple(credential: credential, appState: appState) {
            print("✅ Firebase login with Apple succeeded")
            self.onSuccessCallback?()
        }
    }





    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
           // Convert to ASAuthorizationError if possible
           if let authError = error as? ASAuthorizationError {
               switch authError.code {
               case .canceled:
                   return
               default:
                   // Handle other errors appropriately
                   errorMessage = "Something went wrong. Please try again."
               }
           } else {
               // Handle non-authorization errors
           }
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
    
    private func ensureUserDocumentDefaults(email: String?) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        do {
            let snap = try await ref.getDocument()
            let hasDoc = snap.exists
            let hasIsPro = (snap.data()?["isPro"] != nil)

            // Create doc if missing, or fill the isPro field if absent.
            if !hasDoc {
                try await ref.setData([
                    "isPro": false,
                    "email": email ?? NSNull(),
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)
            } else if !hasIsPro {
                try await ref.setData(["isPro": false], merge: true)
            }
        } catch {
            print("ensureUserDocumentDefaults error: \(error)")
        }
    }


}


