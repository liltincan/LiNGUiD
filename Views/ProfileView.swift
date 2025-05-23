import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
            Text("User Name")
                .font(.title)
            // TODO: user stats, logout button
        }
        .padding()
    }
}
