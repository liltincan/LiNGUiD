import Foundation

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
    func login() async -> Bool {
        do {
            try await authService.signIn(email: email, password: password)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
