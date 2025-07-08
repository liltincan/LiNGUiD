import AVFoundation
import FirebaseAuth
import SwiftUI
import SwiftUIFlow

struct VideoPlayerView: View {
    let url: URL
    let videoId: String
    let language: String?
    let uploaderId: String
    let uploaderPfp: String?
    let containerWidth: CGFloat?
    let containerHeight: CGFloat?
    var isActive: Bool
    let captions: [Captions]?

    init(
        url: URL,
        videoId: String,
        language: String? = nil,
        uploaderId: String,
        uploaderPfp: String? = nil,
        captions: [Captions]? = nil
    ) {
        self.url = url
        self.videoId = videoId
        self.language = language
        self.containerWidth = nil
        self.containerHeight = nil
        self.isActive = true
        self.captions = captions
        self.uploaderId = uploaderId
        self.uploaderPfp = uploaderPfp
    }

    init(
        url: URL,
        videoId: String,
        language: String? = nil,
        uploaderId: String,
        uploaderPfp: String? = nil,
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
        self.uploaderId = uploaderId
        self.uploaderPfp = uploaderPfp
    }

    @State private var isPlaying = false
    @State private var player: AVQueuePlayer = .init()
    @State private var looper: AVPlayerLooper?
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var isShareSheetPresented = false
    @State private var isOptionsSheetPresented = false
    @State private var isPlayerReady = false
    @State private var hasBeenSetup = false
    @State private var watchTimer: Timer?
    @State private var totalWatchTime: TimeInterval = 0
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
        NavigationStack {
            GeometryReader { proxy in
                let screenWidth = proxy.size.width
                let screenHeight = proxy.size.height
                let safeAreaTop = proxy.safeAreaInsets.top
                let safeAreaBottom = proxy.safeAreaInsets.bottom
                
                // Calculate available height for video (excluding tab bar)
                let tabBarHeight: CGFloat = 83
                let availableHeight = screenHeight - tabBarHeight
                
                // Calculate video dimensions to maintain 1:2 aspect ratio
                let videoWidth = containerWidth ?? screenWidth
                let idealVideoHeight = videoWidth * 2 // 1:2 aspect ratio (width:height)
                let videoHeight = min(idealVideoHeight, availableHeight)
                
                ZStack {
                    // Video Player - positioned at the very top
                    VStack(spacing: 0) {
                        VideoPlayerLayerView(player: player)
                            .frame(width: videoWidth, height: videoHeight)
                            .clipped()
                            .onTapGesture {
                                togglePlayPause()
                            }
                        
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Action buttons overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 35) {
                                ActionButton(
                                    icon: isCaptionVisible ? "caption-on" : "caption-off",
                                    color: .white,
                                    size: 30,
                                    isSystemImage: false
                                ) {
                                    isCaptionVisible.toggle()
                                    if isCaptionVisible && !currentCaptionText.isEmpty {
                                        words = currentCaptionText.components(separatedBy: .whitespacesAndNewlines)
                                    }
                                }
                                
                                NavigationLink(destination: OtherUserProfileView(userId: uploaderId)) {
                                    ProfilePictureView(
                                        uploaderPfp: uploaderPfp,
                                        size: 40
                                    )
                                }
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded { _ in
                                            if isPlaying {
                                                player.pause()
                                                isPlaying = false
                                                stopWatchTimer()
                                            }
                                        }
                                )
                                
                                ActionButton(
                                    icon: "heart.fill",
                                    color: isLiked ? .red : .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {
                                    guard let userID = Auth.auth().currentUser?.uid else { return }
                                    let currentLikes = userSession.currentUser?.likedVideos ?? []
                                    isLiked.toggle()
                                    videoPlayerViewModel.toggleLike(
                                        for: "\(language ?? "")/items/\(videoId)",
                                        userId: userID,
                                        currentLikes: currentLikes,
                                        language: language
                                    ) { newState in
                                        isLiked = newState
                                        if var currentUser = userSession.currentUser {
                                            var updatedLikes = currentUser.likedVideos ?? []
                                            let videoIdWithPath = "\(language ?? "")/items/\(videoId)"
                                            if newState {
                                                if !updatedLikes.contains(videoIdWithPath) {
                                                    updatedLikes.append(videoIdWithPath)
                                                }
                                            } else {
                                                updatedLikes.removeAll { $0 == videoIdWithPath }
                                            }
                                            currentUser.likedVideos = updatedLikes
                                            userSession.currentUser = currentUser
                                        }
                                    }
                                }
                                
                                ActionButton(
                                    icon: "bubble.fill",
                                    color: .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {}
                                
                                ActionButton(
                                    icon: "bookmark.fill",
                                    color: isSaved ? .yellow : .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {
                                    guard let userID = Auth.auth().currentUser?.uid else { return }
                                    let currentSaves = userSession.currentUser?.savedVideos ?? []
                                    isSaved.toggle()
                                    videoPlayerViewModel.toggleSave(
                                        for: "\(language ?? "")/items/\(videoId)",
                                        userId: userID,
                                        currentSaves: currentSaves,
                                        language: language
                                    ) { newState in
                                        isSaved = newState
                                        if var currentUser = userSession.currentUser {
                                            var updatedSaves = currentUser.savedVideos ?? []
                                            let videoIdWithPath = "\(language ?? "")/items/\(videoId)"
                                            if newState {
                                                if !updatedSaves.contains(videoIdWithPath) {
                                                    updatedSaves.append(videoIdWithPath)
                                                }
                                            } else {
                                                updatedSaves.removeAll { $0 == videoIdWithPath }
                                            }
                                            currentUser.savedVideos = updatedSaves
                                            userSession.currentUser = currentUser
                                        }
                                    }
                                }
                                
                                ActionButton(
                                    icon: "arrowshape.turn.up.right.fill",
                                    color: .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {
                                    guard let userID = Auth.auth().currentUser?.uid else { return }
                                    Task {
                                        await videoPlayerViewModel.recordShare(
                                            for: videoId,
                                            userId: userID,
                                            language: language
                                        )
                                    }
                                    isShareSheetPresented = true
                                }
                                
                                ActionButton(
                                    icon: "clock.fill",
                                    color: .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {}
                                
                                ActionButton(
                                    icon: "ellipsis",
                                    color: .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {}
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, tabBarHeight + safeAreaBottom)
                        }
<<<<<<< HEAD
                        
                        ActionButton(
                            icon: "clock.fill",
                            color: .white,
                            size: 25,
                            isSystemImage: true
                        ) {}
                        
                        ActionButton(
                            icon: "ellipsis",
                            color: .white,
                            size: 25,
                            isSystemImage: true
                        ) {
                            isOptionsSheetPresented = true
                        }
=======
>>>>>>> main
                    }
                    
                    // Captions overlay
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
                                                        wordFrames[word] = geo.frame(in: .global)
                                                    }
                                            }
                                        )
                                        .onTapGesture {
                                            if isPlaying {
                                                togglePlayPause()
                                            }
                                            actionFunction(word: word)
                                        }
                                }
                            }
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.horizontal, 20)
                            .padding(.trailing, 80) // Space for action buttons
                            .padding(.bottom, tabBarHeight + safeAreaBottom + 20)
                        }
                    }
                    
                    // Word popup overlay
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
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            words = []
            currentCaptionText = ""

            let videoIdWithPath = "\(language ?? "")/items/\(videoId)"
            isLiked = userSession.currentUser?.likedVideos?.contains(videoIdWithPath) ?? false
            isSaved = userSession.currentUser?.savedVideos?.contains(videoIdWithPath) ?? false

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
            recordWatchTime()
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
<<<<<<< HEAD
        .sheet(isPresented: $isOptionsSheetPresented) {
            OptionsSheetView(
                videoId: videoId,
                onInterested: {
                    print("Interested in video \(videoId)")
                    // Firestore logic or analytics here
                },
                onNotInterested: {
                    print("Not interested in video \(videoId)")
                    // Remove from feed or record feedback
                },
                onReport: {
                    print("Reported video \(videoId)")
                    // Firestore or moderation flag
                },
                onDismiss: {
                    isOptionsSheetPresented = false
                }
            )
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
=======
>>>>>>> main
    }

    // ... (rest of the methods remain the same)
    
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
                        .replacingOccurrences(of: "\n", with: " ")
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
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
            totalWatchTime = 0
            hasBeenMarkedAsWatched = false
            startWatchTimer()
        } else {
            player.pause()
            isPlaying = false
            recordWatchTime()
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

    private func startWatchTimer() {
        guard watchTimer == nil else { return }

        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            totalWatchTime += 0.1

            if totalWatchTime >= 1.0 && !hasBeenMarkedAsWatched {
                hasBeenMarkedAsWatched = true
                Task { @MainActor in
                    guard let userID = Auth.auth().currentUser?.uid else { return }
                    await videoPlayerViewModel.markVideoAsWatched(videoId, userID: userID)
                }
            }
        }
    }

    private func stopWatchTimer() {
        watchTimer?.invalidate()
        watchTimer = nil
    }

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
                targetLang: userSession.currentUser?.nativeLanguage ?? ""
            ) { result in
                if let translated = result {
                    isTranslatingCaption = false
                    translatedText = result
                }
            }
            selectedWord = word
            showWordPopup = true
        }
    }

    @ViewBuilder
    private func wordPopup(
        for word: String?,
        from targetLanguage: String,
        to nativeLanguage: String
    ) -> some View {
        VStack(spacing: 0) {
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
                    guard let userID = Auth.auth().currentUser?.uid else { return }
                    addUnknownWordInUserSession(word: word ?? "", userId: userID)
                }) {
                    HStack {
                        Image(systemName: "bookmark.fill")
                        if videoPlayerViewModel.isSavingWord {
                            ProgressView()
                        } else {
                            let videoPlayerWord = videoPlayerViewModel.word ?? ""
                            if videoPlayerViewModel.wordSaved && videoPlayerWord == word {
                                Text("Word Saved!")
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.3), value: videoPlayerViewModel.wordSaved)
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
                Button(action: {}) {
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
        }
    }

    func addUnknownWordInUserSession(word: String, userId: String) {
        guard let language = userSession.currentUser?.targetLanguage else { return }
        let newWord = WordPair(target: word, native: translatedText ?? "")

        guard var currentUser = userSession.currentUser else { return }
        var languagesData = currentUser.languagesData ?? [:]

        var langData =
            languagesData[language]
            ?? LanguagesData(savedWords: WordLists(knownWords: [], unknownWords: []))

        var savedWords =
            langData.savedWords ?? WordLists(knownWords: [], unknownWords: [])

        savedWords.unknownWords.append(newWord)
        langData.savedWords = savedWords
        languagesData[language] = langData
        currentUser.languagesData = languagesData
        userSession.currentUser = currentUser

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

struct ProfilePictureView: View {
    let uploaderPfp: String?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let uploaderPfp = uploaderPfp, !uploaderPfp.isEmpty {
                AsyncImage(url: URL(string: uploaderPfp)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .foregroundColor(.white)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(Color.black.opacity(0))
                .frame(width: size + 20, height: size + 20)
                .blur(radius: 3)
        )
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
                        .fill(Color.black.opacity(0))
                        .frame(width: size + 20, height: size + 20)
                        .blur(radius: 3)
                )
        }
        .contentShape(Rectangle())
    }
}

final class VideoAssetCache {
    static let shared = VideoAssetCache()
    private var cache: [URL: AVAsset] = [:]
    private let queue = DispatchQueue(label: "com.yourapp.VideoAssetCacheQueue", attributes: .concurrent)

    private init() {}

    func asset(for url: URL) -> AVAsset {
        var result: AVAsset?
        
        queue.sync {
            result = cache[url]
        }

        if let result = result {
            return result
        } else {
            let asset = AVURLAsset(url: url)
            
            queue.async(flags: .barrier) {
                self.cache[url] = asset
            }

            return asset
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
<<<<<<< HEAD

struct OptionsSheetView: View {
    let videoId: String
    let onInterested: () -> Void
    let onNotInterested: () -> Void
    let onReport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Text("What would you like to do?")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                Button {
                    onInterested()
                    onDismiss()
                } label: {
                    Label("I'm interested", systemImage: "hand.thumbsup")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    onNotInterested()
                    onDismiss()
                } label: {
                    Label("Not interested", systemImage: "hand.thumbsdown")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(role: .destructive) {
                    onReport()
                    onDismiss()
                } label: {
                    Label("Report video", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.top, 10)

            Button("Cancel") {
                onDismiss()
            }
            .foregroundColor(.white)
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.8), radius: 10)
        .padding(.horizontal)
        .transition(.move(edge: .bottom))
    }
}
=======
>>>>>>> main
