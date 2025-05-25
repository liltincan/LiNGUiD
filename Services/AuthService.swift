import Foundation
import UIKit

protocol AuthService {
    var currentUserID: String? { get }
    func signIn(email: String, password: String) async throws
    func signInWithGoogle(presenting: UIViewController) async throws
    func signOut() throws
}
