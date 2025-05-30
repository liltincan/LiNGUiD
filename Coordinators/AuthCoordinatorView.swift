import SwiftUI

struct AuthCoordinatorView: View {
    let onSuccessfulLogin: () -> Void

    var body: some View {
        LoginView {
            onSuccessfulLogin()
        }
    }
}
