import AVFoundation
import FirebaseAuth
import SwiftUI

struct VideoPlayerView: View {
    let url: URL
    let videoId: String
    let language: String?
    let containerWidth: CGFloat?
    let containerHeight: CGFloat?
    var isActive: Bool
    let captions: [Captions]?

    init(
        url: URL,
        videoId: String,
        language: String? = nil,
        captions: [Captions]? = nil
    ) {
        self.url = url
        self.videoId = videoId
        self.language = language
        self.containerWidth = nil
        self.containerHeight = nil
        self.isActive = true
        self.captions = captions
    }

    init(
        url: URL,
        videoId: String,
        language: String? = nil,
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        isActive: Bool = true,
        captions: [Captions]? = nil
    ) {
        self.url = url
        self.videoId = videoId
        self.language = language
        self.containerWidth = containerWidth
        self.containerHeight = containerHeight
        self.isActive = isActive
        self.captions = captions
    }

    @State private var isPlaying = false
    @State private var player: AVQueuePlayer = .init()
    @State private var looper: AVPlayerLooper?
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var isShareSheetPresented = false
    @State private var isPlayerReady = false
    @State private var hasBeenSetup = false
    @State private var watchTimer: Timer?  // timer for video watch time - Gerardo
    @State private var totalWatchTime: TimeInterval = 0  // total watch time - Gerardo
    @State private var hasBeenMarkedAsWatched = false

    @State private var isCaptionVisible = false
    @State private var currentCaptionText: String = ""
    @State var words: [String] = []
    @State private var timeObserverToken: Any?

    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject var videoPlayerViewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            VideoPlayerLayerView(player: player)
                .aspectRatio(9 / 16, contentMode: .fill)
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
                            icon: isCaptionVisible
                                ? "captions.bubble.fill" : "captions.bubble",
                            color: .white,
                            size: 30
                        ) {
                            isCaptionVisible.toggle()
                            if(isCaptionVisible && !currentCaptionText.isEmpty){
                                words = currentCaptionText.components(separatedBy: .whitespacesAndNewlines)
//                                print(words)
                            }
                        }
                        ActionButton(
                            icon: isLiked ? "heart.fill" : "heart",
                            color: isLiked ? .red : .white,
                            size: 32
                        ) {
                            isLiked.toggle()

                            // Use Firebase Auth directly
                            guard let userID = Auth.auth().currentUser?.uid
                            else { return }

                            // Get current likes from userSession
                            let currentLikes =
                                userSession.currentUser?.likedVideos ?? []
                            videoPlayerViewModel.toggleLike(
                                for: videoId,
                                userId: userID,
                                currentLikes: currentLikes,
                                language: language
                            )
                        }

                        ActionButton(
                            icon: "bubble.right",
                            color: .white,
                            size: 30
                        ) {}

                        ActionButton(
                            icon: isSaved ? "bookmark.fill" : "bookmark",
                            color: isSaved ? .yellow : .white,
                            size: 32
                        ) {
                            isSaved.toggle()
                            let user = userSession.currentUser

                            // Use Firebase Auth directly - Gerardo
                            guard let userID = Auth.auth().currentUser?.uid
                            else { return }
                            // Get current saves from userSession
                            let currentSaves =
                                userSession.currentUser?.savedVideos ?? []
                            videoPlayerViewModel.toggleSave(
                                for: videoId,
                                userId: userID,
                                currentSaves: currentSaves,
                                language: language
                            )
                        }

                        ActionButton(
                            icon: "square.and.arrow.up",
                            color: .white,
                            size: 32
                        ) {
                            // Record share "intent" when user opens share sheet - Gerardo
                            let user = userSession.currentUser
                            guard let userID = Auth.auth().currentUser?.uid
                            else { return }

                            Task {
                                await videoPlayerViewModel.recordShare(
                                    for: videoId,
                                    userId: userID,
                                    language: language
                                )
                            }
                            isShareSheetPresented = true
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
            
            if isCaptionVisible && !words.isEmpty {
                VStack {
                    Spacer()
                    FlowLayout(words: words) { selectedWord in
                        print(selectedWord)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
                .frame(
                    width: containerWidth ?? UIScreen.main.bounds.width,
                    height: containerHeight ?? UIScreen.main.bounds.height,
                    alignment: .bottom
                )
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
            recordWatchTime()  // Record session when leaving view entirely
            player.pause()
            isPlaying = false
            stopWatchTimer()
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
    
    struct FlowLayout: View {
        let words: [String]
        let wordTapped: (String) -> Void

        var body: some View {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }

        private func generateContent(in geometry: GeometryProxy) -> some View {
            var width: CGFloat = 0
            var height: CGFloat = 0

            return ZStack(alignment: .bottomLeading) {
                ForEach(words, id: \.self) { word in
                    Text(word)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                        .fixedSize() // prevent shrinking
                        .alignmentGuide(.leading, computeValue: { d in
                            if abs(width - d.width) > geometry.size.width {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            width -= d.width
                            return result
                        })
                        .alignmentGuide(.bottom, computeValue: { _ in
                            let result = height
                            return result
                        })
                        .onTapGesture {
                            wordTapped(word)
                        }
                }
            }
        }
    }


    private func setupPlayer() {
        configureAudioSession()

        if let cached = VideoCache.shared.player(for: url) as? AVQueuePlayer {
            player = cached
            looper = AVPlayerLooper(
                player: cached,
                templateItem: AVPlayerItem(url: url)
            )
        } else {
            let queuePlayer = AVQueuePlayer()
            looper = AVPlayerLooper(
                player: queuePlayer,
                templateItem: AVPlayerItem(url: url)
            )
            VideoCache.shared.setPlayer(queuePlayer, for: url)
            player = queuePlayer
        }

        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)

            if let caption = captions?.first(where: {
                $0.start <= seconds && seconds <= $0.end
            }) {
                currentCaptionText = caption.text
                
                if(isCaptionVisible && !currentCaptionText.isEmpty){
                    words = currentCaptionText.components(separatedBy: .whitespacesAndNewlines)
//                                print(words)
                }
            } else {
                currentCaptionText = ""
            }
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
            await videoPlayerViewModel.markVideoAsWatched(
                videoId,
                userID: userID
            )
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
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
            // Resetting for a new watch session
            totalWatchTime = 0
            hasBeenMarkedAsWatched = false
            startWatchTimer()
        } else {
            player.pause()
            isPlaying = false
            recordWatchTime()  // Record this session before stopping
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

        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true)
        { _ in
            totalWatchTime += 0.1

            // Check if we've hit 1 second and haven't marked as watched yet
            if totalWatchTime >= 1.0 && !hasBeenMarkedAsWatched {
                hasBeenMarkedAsWatched = true
                Task { @MainActor in
                    // Use Firebase Auth UID instead of Firestore user.id
                    guard let userID = Auth.auth().currentUser?.uid else {
                        return
                    }
                    await videoPlayerViewModel.markVideoAsWatched(
                        videoId,
                        userID: userID
                    )
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

    /// Function to record watch time
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-15
    private func recordWatchTime() {
        guard totalWatchTime > 0 else { return }

        Task { @MainActor in
            guard let userID = Auth.auth().currentUser?.uid else { return }
            await videoPlayerViewModel.recordWatchSession(
                videoId: videoId,
                userID: userID,
                watchTime: totalWatchTime,
                language: language
            )
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
                        .fill(Color.black.opacity(0.1))
                        .frame(width: size + 20, height: size + 20)
                        .blur(radius: 3)
                )
        }
        .contentShape(Rectangle())
    }
}
