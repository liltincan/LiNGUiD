import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService = DependencyContainer.shared.resolve()) {
        self.authService = authService
    }

    func login() async {
        do {
            try await authService.signIn(email: email, password: password)
            // TODO: notify coordinator of success
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
