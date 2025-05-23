import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @State private var player = AVPlayer()

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(vm.videos) { video in
                    // TODO: replace with custom video player view
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .onAppear {
                            Task { await vm.loadMore() }
                        }
                }
                if vm.isLoading {
                    ProgressView()
                }
            }
        }
        .task { await vm.loadInitial() }
    }
}
