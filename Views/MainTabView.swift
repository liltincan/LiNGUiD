import SwiftUI

struct MainTabView: View {
    @State private var selection = 0
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @State private var showDeepLinkedVideo = false
    @State private var deepLinkedVideoID: String?
    @State private var deepLinkedVideoURL: URL?
    
    @StateObject var userSession = UserSessionViewModel()
    
    // Add logout closure parameter
    let onLogout: () -> Void

    var body: some View {
        TabView(selection: $selection) {
            VideoFeedView(userSession: userSession)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
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
        .onReceive(deepLinkCoordinator.$deepLinkVideoID.compactMap { $0 }) { id in
            FirestoreService.shared.getVideoURL(for: id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        deepLinkedVideoID = id
                        deepLinkedVideoURL = url
                        showDeepLinkedVideo = true
                    case .failure(let error):
                        print("Failed to fetch video URL: \(error.localizedDescription)")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showDeepLinkedVideo) {
            if let id = deepLinkedVideoID, let url = deepLinkedVideoURL {
                VideoPlayerView(url: url, videoId: id)
            }
        }
    }
}
