import SwiftUI

struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            VideoFeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(1)

            DashboardView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)

            PracticeView()
                .tabItem { Label("Practice", systemImage: "rectangle.3.offgrid.fill") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
    }
}
