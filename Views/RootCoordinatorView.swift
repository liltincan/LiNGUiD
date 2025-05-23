import SwiftUI

struct RootCoordinatorView: View {
    // TODO: swap to real auth state
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                AuthCoordinatorView()
            } else {
                AuthCoordinatorView()
            }
        }
    }
}
