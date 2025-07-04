import AVFoundation
import FirebaseAuth
import SwiftUI
import SwiftUIFlow

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

    @State private var isTranslatingCaption: Bool = false
    @State private var translatedText: String? = nil
    @State private var selectedWord: String? = nil
    @State private var showWordPopup: Bool = false
    @State private var wordFrames: [String: CGRect] = [:]
    @State private var popupPosition: CGPoint = .zero

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
                                ? "caption-on" : "caption-off",

                            color: .white,
                            size: 30,
                            isSystemImage: false,
                        ) {
                            isCaptionVisible.toggle()

                            if isCaptionVisible && !currentCaptionText.isEmpty {
                                words = currentCaptionText.components(
                                    separatedBy: .whitespacesAndNewlines
                                )
                                //                                print(words)
                            }
                        }
                        ActionButton(
                            icon: isLiked ? "heart.fill" : "heart",
                            color: isLiked ? .red : .white,
                            size: 32,
                            isSystemImage: true
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
                            size: 30,
                            isSystemImage: true
                        ) {}

                        ActionButton(
                            icon: isSaved ? "bookmark.fill" : "bookmark",
                            color: isSaved ? .yellow : .white,
                            size: 32,
                            isSystemImage: true
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
                            size: 32,
                            isSystemImage: true
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
                    .padding(.bottom, 200)
                }

            }

            if isCaptionVisible && !words.isEmpty {
                VStack {
                    Spacer()
                    Flow(.vertical, alignment: .leading, spacing: 0) {
                        ForEach(words, id: \.self) { word in
                            Text(word)
                                .font(.system(size: 20))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                wordFrames[word] = geo.frame(
                                                    in: .global
                                                )
                                            }
                                    }
                                )
                                .onTapGesture {
                                    if isPlaying {
                                        togglePlayPause()
                                    }
                                    print(word)
                                    actionFunction(word: word)
                                }

                        }
                    }
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)  // or .top for upper display

                }

            }

            if showWordPopup, let word = selectedWord {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            selectedWord = nil
                            translatedText = nil
                            showWordPopup = false
                        }
                    }

                VStack {
                    Spacer()
                    wordPopup(
                        for: word,
                        from: userSession.currentUser?.targetLanguage ?? "",
                        to: userSession.currentUser?.nativeLanguage ?? ""
                    )
                    .padding(.bottom, 200)
                    //                    .position(x: popupPosition.x + 10, y: popupPosition.y - 150) // ⬅ adjust these offsets as needed
                }
            }

        }
        .onAppear {
            words = []  // Clear stale words
            currentCaptionText = ""
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
        //        .overlay(
        //            Group {
        //                if showWordPopup, let word = selectedWord {
        //                    wordPopup(
        //                        for: word,
        //                        from: "fr",
        //                        to: "en",
        //                    )
        //                    .padding()
        //                }
        //            }
        //        )
    }

    private func setupPlayer() {
        configureAudioSession()

        let asset = VideoAssetCache.shared.asset(for: url)
        let item = AVPlayerItem(asset: asset)

        let queuePlayer = AVQueuePlayer()
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer

        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)

            if let caption = captions?.first(where: {
                $0.start <= seconds && seconds <= $0.end
            }) {
                currentCaptionText = caption.text

                if isCaptionVisible && !currentCaptionText.isEmpty {
                    words =
                        currentCaptionText
                        .replacingOccurrences(of: "\n", with: " ")  // avoid vertical breaks
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }

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

    func actionFunction(word: String) {
        isTranslatingCaption = true
        withAnimation {
            translateTextV2(
                text: word,
                sourceLang: userSession.currentUser?.targetLanguage ?? "",
                targetLang: userSession.currentUser?.nativeLanguage ?? "",
            ) { result in
                if let translated = result {
                    isTranslatingCaption = false
                    translatedText = result
                    print("🇩🇪 Translated Text: \(translated)")
                } else {
                    print("❌ Translation failed.")
                }
            }

            //            translateWithMyMemory(
            //                text: word,
            //                from: userSession.currentUser?.targetLanguage ?? "",
            //                to: userSession.currentUser?.nativeLanguage ?? ""
            //            ) { result, source in
            //                DispatchQueue.main.async {
            //                    isTranslatingCaption = false
            //                    translatedText = result
            //                    print(
            //                        "Translated: \(result ?? "Failed")\nSource: \(source ?? "Failed")"
            //                    )
            //
            //                }
            //            }
            selectedWord = word
            showWordPopup = true
        }
    }

    @ViewBuilder
    private func wordPopup(
        for word: String?,
        from targetLanguage: String,
        to nativeLanguage: String,
    ) -> some View {
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                if isTranslatingCaption {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, 15)

                        Text("Translating...")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.top, 15)
                    }
                } else if let translated = translatedText {
                    Text(translated)
                        .font(.system(size: 24, weight: .semibold))
                        .padding(.top)
                }

                Spacer().frame(height: 10)

                Divider()
                    .frame(height: 2)
                    .background(Color.white)

                Button(action: {
                    guard let userID = Auth.auth().currentUser?.uid
                    else { return }

                    addUnknownWordInUserSession(
                        word: word ?? "",
                        userId: userID
                    )

                }) {
                    HStack {
                        Image(systemName: "bookmark.fill")
                        if videoPlayerViewModel.isSavingWord {
                            ProgressView()
                            //                                .background(Color.white)
                            //                                .cornerRadius(10)
                            //                                .shadow(radius: 5)
                        } else {
                            let videoPlayerWord =
                                videoPlayerViewModel.word ?? ""
                            if videoPlayerViewModel.wordSaved
                                && videoPlayerWord == word
                            {
                                Text("Word Saved! ")
                                    .transition(.opacity)
                                    .animation(
                                        .easeInOut(duration: 0.3),
                                        value: videoPlayerViewModel.wordSaved
                                    )
                            } else {
                                Text("Save")
                            }

                        }

                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .background(Color.white)

                Button(action: {
                    // see in context logic
                    //                    selectedWord = nil
                }) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text("See in context")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.appPrimaryColor)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(radius: 8)
            .frame(width: 200)

            //            Triangle()
            //                .fill(Color.appPrimaryColor)
            //                .frame(width: 30, height: 15)
            //                .rotationEffect(.degrees(180))
            //                .offset(x: -60, y: -1)
        }

    }

    func addUnknownWordInUserSession(word: String, userId: String) {
        guard let language = userSession.currentUser?.targetLanguage else {
            return
        }
        let newWord = WordPair(target: word, native: translatedText ?? "")

        // Ensure we have a mutable copy of currentUser
        guard var currentUser = userSession.currentUser else { return }

        // Ensure languagesData dictionary exists
        var languagesData = currentUser.languagesData ?? [:]

        // Get or create LanguagesData for the target language
        var langData =
            languagesData[language]
            ?? LanguagesData(
                savedWords: WordLists(knownWords: [], unknownWords: [])
            )

        // Get or create savedWords
        var savedWords =
            langData.savedWords ?? WordLists(knownWords: [], unknownWords: [])

        // Append new word to unknownWords
        savedWords.unknownWords.append(newWord)

        // Save it back into LanguagesData and languagesData map
        langData.savedWords = savedWords
        languagesData[language] = langData
        currentUser.languagesData = languagesData

        // Update the in-memory user session to trigger UI updates
        userSession.currentUser = currentUser

        // Save to Firestore
        videoPlayerViewModel.saveUnknownWord(
            to: userId,
            targetLanguage: language,
            savedWord: word,
            languagesData: languagesData
        )
    }

    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

}

struct ActionButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let isSystemImage: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            (isSystemImage ? Image(systemName: icon) : Image(icon))
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

import Foundation
import AVFoundation

final class VideoAssetCache {
    // Shared singleton instance
    static let shared = VideoAssetCache()

    // Private cache dictionary
    private var cache: [URL: AVAsset] = [:]

    // Serial queue for thread-safe access
    private let queue = DispatchQueue(label: "com.yourapp.videoAssetCache")

    private init() {}

    /// Returns a cached AVAsset for a given URL, or creates and caches it if missing.
    func asset(for url: URL) -> AVAsset {
        return queue.sync {
            if let cached = cache[url] {
                return cached
            } else {
                let asset = AVURLAsset(url: url)
                cache[url] = asset
                return asset
            }
        }
    }

    /// Clears all cached assets (optional utility)
    func clear() {
        queue.sync {
            cache.removeAll()
        }
    }
}

