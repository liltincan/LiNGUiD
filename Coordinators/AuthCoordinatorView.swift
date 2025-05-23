import SwiftUI

struct AuthCoordinatorView: View {
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                VideoFeedCoordinatorView()
            } else {
                LoginView()
                    .onLoginSuccess { isLoggedIn = true }
            }
        }
    }
}

private extension View {
    func onLoginSuccess(_ action: @escaping () -> Void) -> some View {
        // TODO: hook into notification or binding
        self
    }
}
