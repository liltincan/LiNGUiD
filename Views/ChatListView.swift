import SwiftUI

struct ChatListView: View {
    var body: some View {
        NavigationView {
            List {
                Text("Chat Room 1")
                Text("Chat Room 2")
            }
            .navigationTitle("Chats")
        }
    }
}
