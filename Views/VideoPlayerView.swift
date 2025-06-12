import SwiftUI
import AVFoundation

struct VideoPlayerView: View {
    let url: URL
    let videoId: String
    let containerWidth: CGFloat?
    let containerHeight: CGFloat?
    var isActive: Bool

    init(url: URL, videoId: String) {
        self.url = url
        self.videoId = videoId
        self.containerWidth = nil
        self.containerHeight = nil
        self.isActive = true
    }

    init(url: URL, videoId: String, containerWidth: CGFloat, containerHeight: CGFloat, isActive: Bool = true) {
        self.url = url
        self.videoId = videoId
        self.containerWidth = containerWidth
        self.containerHeight = containerHeight
        self.isActive = isActive
    }

    @State private var isPlaying = false
    @State private var player: AVQueuePlayer = .init()
    @State private var looper: AVPlayerLooper?
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var isShareSheetPresented = false
    @State private var isPlayerReady = false
    @State private var hasBeenSetup = false
    @State private var watchTimer: Timer? // timer for video watch time - Gerardo
    @State private var totalWatchTime: TimeInterval = 0 // total watch time - Gerardo
    @State private var hasBeenMarkedAsWatched = false

    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject var videoPlayerViewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            VideoPlayerLayerView(player: player)
                .aspectRatio(9/16, contentMode: .fill)
                .frame(
                    width: containerWidth ?? UIScreen.main.bounds.width,
                    height: containerHeight ?? UIScreen.main.bounds.height
                )
                .clipped()
                .onTapGesture {
                    togglePlayPause()
                }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 24) {
                        ActionButton(
                            icon: isLiked ? "heart.fill" : "heart",
                            color: isLiked ? .red : .white,
                            size: 32
                        ) {
                            isLiked.toggle()
                            if let user = userSession.currentUser,
                               let userId = user.id {
                                videoPlayerViewModel.toggleLike(
                                    for: videoId,
                                    userId: userId,
                                    currentLikes: user.likedVideos ?? []
                                )
                            }
                        }

                        ActionButton(
                            icon: "bubble.right",
                            color: .white,
                            size: 30
                        ) { }

                        ActionButton(
                            icon: isSaved ? "bookmark.fill" : "bookmark",
                            color: isSaved ? .yellow : .white,
                            size: 32
                        ) {
                            isSaved.toggle()
                        }

                        ActionButton(
                            icon: "square.and.arrow.up",
                            color: .white,
                            size: 32
                        ) {
                            isShareSheetPresented = true
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            if !hasBeenSetup {
                setupPlayer()
                hasBeenSetup = true
            } else {
                if isActive && isPlayerReady {
                    player.seek(to: .zero)
                    player.play()
                    isPlaying = true
                }
            }
        }
        .onDisappear {
            player.pause()
            isPlaying = false
        }
        .onChange(of: isActive) { oldValue, newValue in
            if hasBeenSetup {
                handleActiveStateChange(newValue)
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheetView(videoId: videoId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func setupPlayer() {
        configureAudioSession()

        if let cached = VideoCache.shared.player(for: url) as? AVQueuePlayer {
            player = cached
            looper = AVPlayerLooper(player: cached, templateItem: AVPlayerItem(url: url))
        } else {
            let queuePlayer = AVQueuePlayer()
            looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))
            VideoCache.shared.setPlayer(queuePlayer, for: url)
            player = queuePlayer
        }

        player.currentItem?.preferredForwardBufferDuration = 0
        player.automaticallyWaitsToMinimizeStalling = false

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in }

        isPlayerReady = true

        DispatchQueue.main.async {
            if isActive {
                player.seek(to: .zero)
                player.play()
                isPlaying = true
            }
        }

        Task {
            guard let userID = userSession.currentUser?.id else { return }
            await videoPlayerViewModel.markVideoAsWatched(videoId, userID: userID)
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
    }

    private func handleActiveStateChange(_ active: Bool) {
        guard isPlayerReady else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if isPlayerReady {
                    handleActiveStateChange(active)
                }
            }
            return
        }

        if active {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            startWatchTimer()
        } else {
            player.pause()
            isPlaying = false
            stopWatchTimer()
        }
    }

    private func togglePlayPause() {
        guard isPlayerReady else { return }

        isPlaying.toggle()
        if isPlaying {
            player.play()
            startWatchTimer()
        } else {
            player.pause()
            stopWatchTimer()
        }
    }
    /// Function to start the watch timer for a video
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-10
    private func startWatchTimer() {
        // Guard so we don't start the timer if it's already running
        guard watchTimer == nil else { return }
        
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in totalWatchTime += 0.1
            
            // Check if we've hit 1 second and haven't marked as watched yet
            if totalWatchTime >= 1.0 && !hasBeenMarkedAsWatched {
                hasBeenMarkedAsWatched = true
                Task { @MainActor in
                    guard let userID = userSession.currentUser?.id else { return }
                    await videoPlayerViewModel.markVideoAsWatched(videoId, userID: userID)
                }
            }
        }
    }
    /// Function to stop the watch timer for a video
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-10
    private func stopWatchTimer() {
        watchTimer?.invalidate()
        watchTimer = nil
    }
    
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(color)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: size + 16, height: size + 16)
                        .blur(radius: 3)
                )
        }
        .contentShape(Rectangle())
    }
}
