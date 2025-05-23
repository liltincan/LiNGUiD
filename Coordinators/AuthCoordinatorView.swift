import SwiftUI

struct AuthCoordinatorView: View {
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                VideoFeedCoordinatorView()
            } else {
                LoginView {
                    isLoggedIn = true
                }
            }
        }
    }
}
