import SwiftUI
import AVKit

struct VideoView: View {
    let videos: [String]
    @State private var currentIndex: Int

    init(videos: [String], startIndex: Int = 0) {
        self.videos = videos
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        Group {
            if videos.isEmpty {
                NoVideosView()
            } else {
                VideoPlayerTabView(videos: videos, currentIndex: $currentIndex)
            }
        }
        .ignoresSafeArea()
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct NoVideosView: View {
    var body: some View {
        Text("No videos found.")
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct VideoPlayerTabView: View {
    let videos: [String]
    @Binding var currentIndex: Int

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        TabView(selection: $currentIndex) {
            ForEach(videos.indices, id: \.self) { idx in
                SingleVideoPageView(
                    urlString: videos[idx],
                    isActive: idx == currentIndex
                )
                .rotationEffect(.degrees(-90)) // Rotate individual page content back
                .tag(idx)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .rotationEffect(.degrees(90)) // Rotate TabView for vertical swipe
        .frame(
            width: screenHeight,
            height: screenWidth
        )
        .ignoresSafeArea()
        .background(Color.black)
        .onAppear {
            if currentIndex >= videos.count {
                currentIndex = 0
            }
        }
        .onChange(of: videos) { newVideos in
            if currentIndex >= newVideos.count {
                currentIndex = 0
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
    }
}

struct SingleVideoPageView: View {
    let urlString: String
    let isActive: Bool
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            if let player = player {
                CustomVideoPlayer(player: player)
                    .onAppear {
                        if isActive {
                            player.play()
                            isPlaying = true
                        } else {
                            player.pause()
                            isPlaying = false
                        }
                        // Add observer for video end
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { _ in
                            player.seek(to: .zero) // Restart video
                            player.play() // Play again
                        }
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                        // Remove observer
                        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                    }
                    .onChange(of: isActive) { active in
                        if active {
                            player.seek(to: .zero)
                            player.play()
                            isPlaying = true
                        } else {
                            player.pause()
                            isPlaying = false
                        }
                    }
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                            isPlaying = false
                        } else {
                            player.play()
                            isPlaying = true
                        }
                    }
                    .transition(.opacity)
                    .edgesIgnoringSafeArea(.all)
                    .clipped()
                    .frame(
                        width: UIScreen.main.bounds.width - 20,
                        height: UIScreen.main.bounds.height - 20
                    )
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .onAppear {
                        loadPlayer()
                    }
            }
        }
        .frame(
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
    }

    private func loadPlayer() {
        guard let url = URL(string: urlString) else {
            print("Invalid video URL: \(urlString)")
            return
        }
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        isLoading = false
    }
}


struct CustomVideoPlayer: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect    // Fit inside frame, no cropping
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct VideoView_Previews: PreviewProvider {
    static var previews: some View {
        VideoView(videos: [
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"
        ])
    }
}
