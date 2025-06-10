import Foundation
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
import UIKit

protocol AuthService {
    var currentUserID: String? { get }
    func registerOrLogin(email: String, password: String, appState: AppState) async throws  -> String?
    func signInWithGoogle(presenting: UIViewController, appState: AppState) async throws -> Bool
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String, appState: AppState) async throws
    func signOut() throws
    func linkEmailPassword(email: String, password: String) async throws // New method
    func updateEmail(to newEmail: String) async throws
    func updatePassword(to newPassword: String) async throws
    func sendEmailVerification() async throws
    func reloadCurrentUser() async throws
}
