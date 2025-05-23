import Foundation

protocol AuthService {
    var currentUserID: String? { get }
    func signIn(email: String, password: String) async throws
    func signOut() throws
}
