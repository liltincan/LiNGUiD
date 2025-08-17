import SwiftUI

struct OtherUserProfile: View {
    // ...existing properties and methods...

    var body: some View {
        // ...existing view code...
        .navigationBarHidden(true) // Add this modifier to hide the navigation bar
        // If using iOS 16+, you can use:
        // .toolbar(.hidden, for: .navigationBar)
    }

    // ...existing methods...
}