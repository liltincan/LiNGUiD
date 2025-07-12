import SwiftUI

struct MainTabView: View {
    @State private var selection = 0
    @Binding var selectedTab: Int
    @Binding var deepLinkedVideoID: String?
    //need to keep track of the numbers
    @State private var unreadChatCount: Int = 0

    @StateObject var userSession = UserSessionViewModel()
    
    // Add logout closure parameter
    let onLogout: () -> Void

    var body: some View {
        TabView(selection: $selection) {
            VideoFeedView(userSession: userSession, startingVideoId: deepLinkedVideoID)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ChatListView(unreadChatCount: $unreadChatCount)
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill")}
                //the .badge will show a red notification bubble with the parameter inside being the number
                .badge(unreadChatCount == 0 ? 0 : unreadChatCount)
                .tag(1)

            DashboardView(userSession: userSession, selectedTab: $selection)
                .environmentObject(userSession)
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(2)

            PracticeView(userSession: userSession)
                .tabItem {
                    VStack {
                        Image(selection == 3 ? "practiceImg2" : "practiceImg1")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25)
                        Text("Practice")
                            .font(.caption2)
                    }
                }
                .tag(3)

            // Pass logout closure to ProfileView
            ProfileView(userSession: userSession, onLogout: onLogout)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .accentColor(Color(red: 142/255, green: 84/255, blue: 229/255))
    }
}
