import AVKit
import SwiftUI

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @State private var player = AVPlayer()
    @State private var currentIndex = 0
    @ObservedObject var userSession : UserSessionViewModel
    
   

    var body: some View {
        VStack{
            if vm.errorMessage != nil {
                VStack {
                    Text(vm.errorMessage ?? "")
                        .font(.title3)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(vm.videos.enumerated()), id: \.element.id) {
                        index,
                        video in
                        VideoPlayerView(url: video.url, videoId: video.id)
                            .rotationEffect(.degrees(90))
                            .tag(index)
                            .frame(
                                width: UIScreen.main.bounds.height,
                                height: UIScreen.main.bounds.width
                            )
                        //.ignoresSafeArea()
                            .onAppear {
                                if index >= vm.videos.count - 2 {
                                    Task { await vm.fetchMoreVideos() }
                                }
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .rotationEffect(.degrees(-90))  // vertical scroll illusion
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                //.rotationEffect(.degrees(90))
                //            .offset(x: UIScreen.main.bounds.width)
                .ignoresSafeArea()
                .onAppear {
                    Task { await vm.fetchInitialVideos() }
                }
            }
        }
    }
}
//struct VideoFeedView_Previews: PreviewProvider {
//    static var previews: some View {
//        VideoFeedView()
//    }
//}
