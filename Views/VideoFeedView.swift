import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @State private var player = AVPlayer()
    @State private var currentIndex = 0

    var body: some View {
            TabView(selection: $currentIndex) {
                ForEach(Array(vm.videos.enumerated()), id: \.element.id) { index, video in
                    VideoPlayerView(url: video.url)
                        .tag(index)
                        .ignoresSafeArea()
                        .onAppear {
                            if index >= vm.videos.count - 2 {
                                Task { await vm.fetchMoreVideos() }
                            }
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//            .rotationEffect(.degrees(-90)) // vertical scroll illusion
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .rotationEffect(.degrees(90))
//            .offset(x: UIScreen.main.bounds.width)
            .onAppear {
                Task { await vm.fetchInitialVideos() }
            }
        }
}
struct VideoFeedView_Previews: PreviewProvider {
    static var previews: some View {
        VideoFeedView()
    }
}
