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
class ChangeEmailViewModel: ObservableObject {
    @Published var verificationSent: Bool = false
    @Published var isReauthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var userIsGoogleUser: Bool = false
    @Published var hasEmailPasswordProvider: Bool = false
    @Published var errorMessage: String? = nil
    
    private var wasOriginallyGoogleUser: Bool = false
    
    var currentUserEmail: String? {
        return Auth.auth().currentUser?.email
    }
    
    func resetMessages() {
        errorMessage = ""
        verificationSent = false
        isLoading = false
    }

    func detectUserSignInProvider() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user signed in."
            return
        }
        userIsGoogleUser = user.providerData.contains(where: { $0.providerID == "google.com" })
        hasEmailPasswordProvider = user.providerData.contains(where: { $0.providerID == "password" })
        if !wasOriginallyGoogleUser && userIsGoogleUser && !hasEmailPasswordProvider {
            wasOriginallyGoogleUser = true
        }
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
                self.detectUserSignInProvider()
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
            self.detectUserSignInProvider()
        }
    }

    func sendVerificationEmail(newEmail: String, newPassword: String) {
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
                if !hasEmailPasswordProvider {
                    // Link email/password to existing account
                    let credential = EmailAuthProvider.credential(withEmail: newEmail, password: newPassword)
                    try await user.link(with: credential)
                    
                    await MainActor.run {
                        self.detectUserSignInProvider()
                    }
                    
                    try await user.sendEmailVerification()
                    await MainActor.run {
                        self.verificationSent = true
                        self.errorMessage = "Email/Password linked successfully! Verification email sent to \(newEmail)."
                    }
                } else {
                    // Send verification email before updating email
                    try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
                    await MainActor.run {
                        self.verificationSent = true
                        self.errorMessage = "Verification email sent to \(newEmail). Please verify before updating."
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    func updateEmailAndPassword(newEmail: String, newPassword: String) {
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
                // Reload user to get latest verification status
                try await user.reload()
                
                var successMessages: [String] = []
                
                // Update email if provided and different from current
                if !newEmail.isEmpty && newEmail != user.email {
                    try await user.updateEmail(to: newEmail)
                    successMessages.append("Email updated successfully")
                    
                    // CRITICAL: Reload the user after email update to refresh token
                    try await user.reload()
                }
                
                // Update password if provided
                if !newPassword.isEmpty {
                    try await user.updatePassword(to: newPassword)
                    successMessages.append("Password updated successfully")
                }
                
                // Force refresh the ID token to ensure authentication state is current
                try await user.getIDTokenResult(forcingRefresh: true)
                
                await MainActor.run {
                    if successMessages.isEmpty {
                        self.errorMessage = "No changes were made."
                    } else {
                        self.errorMessage = successMessages.joined(separator: " and ") + "."
                    }
                    self.isLoading = false
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    // Handle specific Firebase Auth errors
                    switch error.code {
                    case AuthErrorCode.requiresRecentLogin.rawValue:
                        self.errorMessage = "This operation requires recent authentication. Please reauthenticate and try again."
                        self.isReauthenticated = false
                    case AuthErrorCode.emailAlreadyInUse.rawValue:
                        self.errorMessage = "This email is already in use by another account."
                    case AuthErrorCode.invalidEmail.rawValue:
                        self.errorMessage = "Please enter a valid email address."
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
