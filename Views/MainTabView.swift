import SwiftUI

struct MainTabView: View {
    @State private var selection = 0
    @EnvironmentObject var userSession: UserSessionViewModel
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @State private var showDeepLinkedVideo = false
    @State private var deepLinkedVideoID: String?
    @State private var deepLinkedVideoURL: URL?


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

            PracticeView(userSession:  userSession)
                .tabItem { Label("Practice", systemImage: "rectangle.3.offgrid.fill") }
                .tag(3)

            ProfileView(userSession: userSession)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
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
