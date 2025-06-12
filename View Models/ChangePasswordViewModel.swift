import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import SwiftUI

extension UIViewController {
    static func topMostViewController(in window: UIWindow?) -> UIViewController? {
        guard let rootViewController = window?.rootViewController else {
            return nil
        }
        return UIViewController.topMostViewController(from: rootViewController)
    }

    static func topMostViewController(from viewController: UIViewController?) -> UIViewController? {
        guard let viewController = viewController else { return nil }

        if let navigationController = viewController as? UINavigationController {
            return UIViewController.topMostViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return UIViewController.topMostViewController(from: tabBarController.selectedViewController)
        }
        if let presentedViewController = viewController.presentedViewController {
            return UIViewController.topMostViewController(from: presentedViewController)
        }
        return viewController
    }

    static func topMostViewController() -> UIViewController? {
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return UIViewController.topMostViewController(from: window.rootViewController)
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return UIViewController.topMostViewController(from: window.rootViewController)
        }
        return nil
    }
}

@MainActor
class ChangePasswordViewModel: ObservableObject {
    @Published var isReauthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var userIsGoogleUser: Bool = false
    @Published var errorMessage: String? = nil
    
    var currentUserEmail: String? {
        return Auth.auth().currentUser?.email
    }
    
    func resetMessages() {
        errorMessage = ""
        isLoading = false
    }

    func detectUserSignInProvider() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user signed in."
            return
        }
        userIsGoogleUser = user.providerData.contains(where: { $0.providerID == "google.com" })
    }

    func googleReauth(loginVM: LoginViewModel) {
        isLoading = true
        errorMessage = nil
        
        guard Auth.auth().currentUser != nil else {
            errorMessage = "No user signed in."
            isLoading = false
            return
        }
        
        guard let presentingVC = UIViewController.topMostViewController() else {
            errorMessage = "Could not find a view controller to present Google Sign-In."
            isLoading = false
            return
        }

        // Get Google credential for reauthentication
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Could not get Google client ID."
            isLoading = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.errorMessage = "Failed to get Google credentials."
                self.isLoading = false
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

            // Reauthenticate the current user
            Auth.auth().currentUser?.reauthenticate(with: credential) { _, error in
                if let error = error {
                    self.errorMessage = "Reauthentication failed: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                self.isReauthenticated = true
                self.isLoading = false
            }
        }
    }

    func emailPasswordReauth(loginVM: LoginViewModel) {
        isLoading = true
        errorMessage = nil
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user signed in."
            isLoading = false
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: loginVM.email, password: loginVM.password)
        
        user.reauthenticate(with: credential) { [weak self] _, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Reauthentication failed: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            self.isReauthenticated = true
            self.isLoading = false
        }
    }

    func updatePassword(newPassword: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            guard let user = Auth.auth().currentUser else {
                await MainActor.run {
                    self.errorMessage = "User not signed in."
                    self.isLoading = false
                }
                return
            }

            do {
                // Update password
                try await user.updatePassword(to: newPassword)
                
                // Force refresh the ID token to ensure authentication state is current
                try await user.getIDTokenResult(forcingRefresh: true)
                
                await MainActor.run {
                    self.errorMessage = "Password updated successfully."
                    self.isLoading = false
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    // Handle specific Firebase Auth errors
                    switch error.code {
                    case AuthErrorCode.requiresRecentLogin.rawValue:
                        self.errorMessage = "This operation requires recent authentication. Please reauthenticate and try again."
                        self.isReauthenticated = false
                    case AuthErrorCode.weakPassword.rawValue:
                        self.errorMessage = "Password is too weak. Please choose a stronger password."
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                    self.isLoading = false
                }
            }
        }
    }
}
