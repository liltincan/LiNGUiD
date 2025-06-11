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
    @State private var watchTimer: Timer? // timer for video watch time - Gerardo
    @State private var totalWatchTime: TimeInterval = 0 // total watch time - Gerardo
    @State private var hasBeenMarkedAsWatched = false    @State private var isPlayerReady = false
    @State private var hasBeenSetup = false

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
                .onAppear {
                    if let cached = VideoCache.shared.player(for: url) as? AVQueuePlayer {
                        player = cached //get the player from the cache if it already exists with the url
                        looper = AVPlayerLooper(player: cached, templateItem: AVPlayerItem(url: url)) //creates video looper
                        
                        
                    } else { //if not, we make it here
                        
                        let queuePlayer = AVQueuePlayer() //queue of player items
                        
                        looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url)) //creates video looper
                        VideoCache.shared.setPlayer(queuePlayer, for: url) //saves new queue player to the cache
                        player = queuePlayer //sets the new queue player as the player for the view
                    }
                    
                    if isPlaying { //plays as long as it wasn't manually paused by the user prior to disappearing
                        player.play()
                        startWatchTimer()
                    }
                    // marking current video as watched - Gerardo De La Torre 06/06/2025
                    Task {
                        guard let userID = userSession.currentUser?.id else { return }
                        await videoPlayerViewModel.markVideoAsWatched(videoId, userID: userID)
                    }
                }
                .onDisappear { //pauses upon disappearing
                    player.pause()
                    stopWatchTimer()
                }
            HStack {

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
        } else {
            player.pause()
            isPlaying = false
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
