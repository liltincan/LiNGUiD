import SwiftUI
import FirebaseCore

@main
struct LiNGUiDApp: App {
    init() {
        // TODO: configure Firebase and dependency container
        FirebaseApp.configure()
        DependencyContainer.shared.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView().environment(\.font, .custom("Poppins-Regular", size: 16))
        }
    }
}
