import Foundation
import AuthenticationServices
import UIKit

protocol AuthService {
    var currentUserID: String? { get }
    func registerOrLogin(email: String, password: String) async throws  -> String?
    func signInWithGoogle(presenting: UIViewController) async throws -> Bool
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws
    func signOut() throws
}
