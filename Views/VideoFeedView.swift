import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @State private var player = AVPlayer()

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(Array(vm.videos.enumerated()), id: \.element.id) { index, video in
                            VideoPlayerView(videoURL: video.url)
                                .id(video.id)
                                .frame(height: UIScreen.main.bounds.height)
                                .ignoresSafeArea()
                                .onAppear {
                                    if index >= vm.videos.count - 2 {
                                        Task { await vm.fetchMoreVideos() }
                                    }
                                }
                        }
                if vm.isLoading {
                    ProgressView()
                }
            }
        }
        .task { await vm.fetchInitialVideos() }
    }
}

//import SwiftUI
//import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}


struct VideoFeedView_Previews: PreviewProvider {
    static var previews: some View {
        VideoFeedView()
    }
}
