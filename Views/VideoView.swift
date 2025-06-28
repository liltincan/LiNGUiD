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
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if videos.isEmpty {
                Text("No videos found.")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            } else {
                VerticalVideoScrollView(videos: videos, currentIndex: $currentIndex)
            }
        }
        .ignoresSafeArea()
    }
}

struct VerticalVideoScrollView: View {
    let videos: [String]
    @Binding var currentIndex: Int
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(videos.indices, id: \.self) { index in
                            SingleVideoPageView(
                                urlString: videos[index],
                                isActive: index == currentIndex,
                                containerWidth: screenWidth,
                                containerHeight: screenHeight
                            )
                            .frame(width: screenWidth, height: screenHeight)
                            .id(index)
                            .background(
                                GeometryReader { itemGeo in
                                    Color.clear
                                        .onAppear {
                                            checkIfCentered(index: index, geometry: itemGeo, screenHeight: screenHeight)
                                        }
                                        .onChange(of: itemGeo.frame(in: .global)) { oldFrame, newFrame in
                                            checkIfCentered(index: index, geometry: itemGeo, screenHeight: screenHeight)
                                        }
                                }
                            )
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .onAppear {
                    if currentIndex >= videos.count {
                        currentIndex = 0
                    }
                }
                .onChange(of: videos) { oldVideos, newVideos in
                    if currentIndex >= newVideos.count {
                        currentIndex = 0
                    }
                }
            }
        }
        .background(Color.black)
    }
    
    private func checkIfCentered(index: Int, geometry: GeometryProxy, screenHeight: CGFloat) {
        let frame = geometry.frame(in: .global)
        let screenCenter = screenHeight / 2
        let itemCenter = frame.midY
        let distanceFromCenter = abs(itemCenter - screenCenter)
        
        if distanceFromCenter < screenHeight / 4 {
            if index != currentIndex {
                currentIndex = index
            }
        }
    }
}

struct SingleVideoPageView: View {
    let urlString: String
    let isActive: Bool
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            Color.black
            
            if let player = player {
                VideoPlayerLayerView(player: player)
                    .frame(width: containerWidth, height: containerHeight)
                    .clipped()
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        cleanupPlayer()
                    }
                    .onChange(of: isActive) { oldValue, newValue in
                        handleActiveStateChange(newValue)
                    }
                    .onTapGesture {
                        togglePlayPause()
                    }
                
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .onAppear {
                        loadPlayer()
                    }
            }
        }
        .frame(width: containerWidth, height: containerHeight)
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
    
    private func setupPlayer() {
        guard let player = player else { return }
        
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
    
    private func cleanupPlayer() {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    private func handleActiveStateChange(_ active: Bool) {
        guard let player = player else { return }
        
        if active {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
}
