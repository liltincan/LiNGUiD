import Foundation
import AuthenticationServices
import UIKit

protocol AuthService {
    var currentUserID: String? { get }
    func signIn(email: String, password: String) async throws
    func signInWithGoogle(presenting: UIViewController) async throws -> Bool
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws
    func signOut() throws
}
