import AVFoundation
import FirebaseAuth
import FirebaseFirestore
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
    @State private var videoLikes = 0
    @State private var videoSaves = 0
    @State private var commentCount = 0
    @State private var showProfile = false
    let showingInFullScreen: Bool
    let ownProfile: Bool
    let onLogout: () -> Void // <-- Add this property

    @Binding var selectedTab: Int
    init(
        url: URL,
        videoId: String,
        language: String? = nil,
        uploaderId: String,
        uploaderPfp: String? = nil,
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        isActive: Bool = true,
        captions: [Captions]? = nil,
        videoLikes: Int,
        videoSaves: Int,
        commentCount: Int,
        selectedTab: Binding<Int>,
        showingInFullScreen: Bool,
        ownProfile: Bool,
        onLogout: @escaping () -> Void
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
        _videoLikes = State(initialValue: videoLikes)
        _videoSaves = State(initialValue: videoSaves)
        _commentCount = State(initialValue: commentCount)
        self._selectedTab = selectedTab
        self.showingInFullScreen = showingInFullScreen
        self.ownProfile = ownProfile
        self.onLogout = onLogout // <-- Store the closure
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
    
    // Report functionality
    @State private var showingReportSheet = false
    @State private var showingReportConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingComments = false
    let speedArray: [Float] = [1.0, 0.75, 0.5]
    @State private var currentSpeedIndex = 0

    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject var videoPlayerViewModel = VideoPlayerViewModel()
    @State private var uploaderUsername: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPracticeSheet = false
    @State private var justSavedFlash = false
    
    @State private var sentencePieces: [String] = []
    @State private var currentPieceIndex: Int = 0
    @State private var highlightedWord: String? = nil

    @State private var arrowOffsetX: CGFloat = 0
    private let popupWidth: CGFloat = 200
    @State private var popupOffsetX: CGFloat = 0
    
    //Video Slider States
    @State private var duration: Double = 0
    @State private var playbackTime: Double = 0
    @State private var isScrubbing = false
    @State private var wasPlayingBeforeScrub = false
    
    //showing the pop up
    @State private var showLimitAlert = false
    @ObservedObject var tap = TapTracker(maxPerDay: 20)
    @ObservedObject var viewModel = ChatListViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    private var hasMeaning: Bool {
        let m = (translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !m.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let screenWidth = max(proxy.size.width, 1) // Ensure minimum width
                let screenHeight = max(proxy.size.height, 1) // Ensure minimum height
                let safeAreaBottom = proxy.safeAreaInsets.bottom
                
                // Calculate available height for video (excluding tab bar)
                let tabBarHeight: CGFloat = showingInFullScreen ? 0 : 83
                let availableHeight = max(proxy.size.height - tabBarHeight, 100) // Minimum height
                
                // Calculate video dimensions to maintain 1:2 aspect ratio with safety checks
                let videoWidth = max(containerWidth ?? screenWidth, 1)
                let idealVideoHeight = videoWidth * 2
                let videoHeight: CGFloat = showingInFullScreen ? proxy.size.height : max(min(idealVideoHeight, availableHeight), 100)
                
                ZStack {
                    // Video Player - positioned at the very top
                    VStack(spacing: 0) {
                        VideoPlayerLayerView(player: player)
                            .frame(width: videoWidth, height: videoHeight)
                            .clipped()
                            .onTapGesture {
                                togglePlayPause()
                            }
                            .ignoresSafeArea(edges: .top)
                        
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Action buttons overlay - Fixed positioning at bottom right
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
                                        let separator = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
                                        words = currentCaptionText.components(separatedBy: separator).filter{ !$0.isEmpty}
                                    }
                                }
                                
                                Button{
                                    if isPlaying {
                                        player.pause()
                                        isPlaying = false
                                        stopWatchTimer()
                                    }
                                    showProfile = true
                                } label: {
                                    ProfilePictureView(uploaderPfp: uploaderPfp, size: 40)
                                }
                                .fullScreenCover(isPresented: $showProfile) {
                                    NavigationStack {
                                        if(uploaderId == Auth.auth().currentUser?.uid){
                                            ProfileView(
                                                userSession: UserSessionViewModel(),
                                                onLogout: onLogout,
                                                selectedTab: $selectedTab,
                                                showBackButton: true
                                            )
                                        } else {
                                            OtherUserProfileView(userId: uploaderId, selectedTab: $selectedTab, onLogout: onLogout)
                                        }
                                    }
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
                                
                                VStack(spacing: 5){
                                    ActionButton(
                                        icon: "heart.fill",
                                        color: isLiked ? .red : .white,
                                        size: 25,
                                        isSystemImage: true
                                    ) {
                                        videoLikes += isLiked ? -1 : 1
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
                                    Text("\(videoLikes)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.white)
                                }
                                VStack(spacing: 5){
                                    ActionButton(
                                        icon: "bubble.fill",
                                        color: .white,
                                        size: 25,
                                        isSystemImage: true
                                    ) {
                                        if isPlaying {
                                            player.pause()
                                            isPlaying = false
                                            stopWatchTimer()
                                        }
                                        showingComments = true
                                    }
                                    Text("\(commentCount)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.white)
                                }
                                VStack(spacing: 5){
                                    ActionButton(
                                        icon: "bookmark.fill",
                                        color: isSaved ? .yellow : .white,
                                        size: 25,
                                        isSystemImage: true
                                    ) {
                                        videoSaves += isSaved ? -1 : 1
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
                                    Text("\(videoSaves)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.white)
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
                                VStack(spacing: 5){
                                    ActionButton(
                                        icon: "clock.fill",
                                        color: .white,
                                        size: 25,
                                        isSystemImage: true
                                    ) {
                                        if(currentSpeedIndex != 2){
                                            currentSpeedIndex += 1
                                        } else if (currentSpeedIndex == 2){
                                            currentSpeedIndex = 0
                                        }
                                        
                                        // Apply the speed with better audio processing
                                        let newSpeed = speedArray[currentSpeedIndex]
                                        setPlayerSpeed(newSpeed)
                                    }
                                    Text("\(speedArray[currentSpeedIndex], specifier: "%.2f")x")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                
                                ActionButton(
                                    icon: "ellipsis",
                                    color: .white,
                                    size: 25,
                                    isSystemImage: true
                                ) {
                                    showingReportSheet = true
                                }
                                .confirmationDialog("", isPresented: $showingReportSheet, titleVisibility: .hidden) {
                                    Button("Report Video", role: .destructive) {
                                        
                                        print("DEBUG: Attempting to report video")
                                                print("DEBUG: reporterUid = \(String(describing: Auth.auth().currentUser?.uid))")
                                                print("DEBUG: reporterUsername = \(String(describing: userSession.currentUser?.userName))")
                                                print("DEBUG: posterUsername = \(String(describing: self.uploaderUsername))")
                                                print("DEBUG: posterUid = \(self.uploaderId)")
                                        guard
                                            let reporterUid = Auth.auth().currentUser?.uid,
                                            let reporterUsername = userSession.currentUser?.userName,
                                            let posterUsername = self.uploaderUsername
                                        else {
                                            print("Missing required user info to report video")
                                            return
                                        }

                                        reportVideo(
                                            videoId: self.videoId,
                                            reporterUid: reporterUid,
                                            reporterUsername: reporterUsername,
                                            posterUid: self.uploaderId,
                                            posterUsername: posterUsername
                                        )

                                        handleReportVideo()
                                    }
                                    if (uploaderId == Auth.auth().currentUser?.uid || userSession.isAdmin) {
                                        Button(userSession.isAdmin && uploaderId != Auth.auth().currentUser?.uid
                                               ? "Remove Video (Admin)" : "Delete Video",
                                               role: .destructive) {
                                            showingDeleteConfirmation = true
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                }
                                .confirmationDialog("Are you sure you want to delete this video?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await FirestoreService.shared.deleteVideo(videoId: videoId, uid: uploaderId, language: language ?? "")
                                            dismiss()
                                        }                                    }
                                    Button("Cancel", role: .cancel) {}
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, showingInFullScreen ? 100 : max(tabBarHeight + safeAreaBottom + 20, 20))
                        }
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 0)
                    
                    // Fixed positioned back button overlay
                    if (showingInFullScreen || ownProfile) && isActive {
                        VStack {
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .bold))
                                        .frame(width: 12, height: 18)
                                        .foregroundColor(.white)
                                        .padding(.leading, 20)
                                        .padding(.vertical, 4)
                                        .background(Color.clear)
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 80)
                        .padding(.leading, 20)
                    }
                    
                    // Transparent tap-catcher: active only when a word is highlighted / popup shown
                    if !showWordPopup && (highlightedWord != nil) {
                        Color.clear
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { clearHighlightAndPopup() } // outside caption & popup => clear both
                            .zIndex(1) // caption and popup will sit above this, so taps on them are NOT intercepted
                    }

                    // Captions overlay (single line)
                    if isCaptionVisible && !sentencePieces.isEmpty {
                        let line = sentencePieces[currentPieceIndex]
                        let lineWords = line.split(separator: " ").map(String.init)

                        VStack {
                            Spacer()
                            HStack(spacing: 5) {
                                ForEach(lineWords, id: \.self) { w in
                                    let isSelected = (highlightedWord == w)
                                    Text(w)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .fixedSize()
                                        .contentShape(Rectangle())
                                        .background(
                                            isSelected ? Color.gray.opacity(0.6) : Color.clear
                                        )
                                        .onTapGesture {
                                            guard isActive else { return }
                                            if isPlaying { togglePlayPause() }

                                            if highlightedWord == w && showWordPopup {
                                                clearHighlightAndPopup()
                                            } else {
                                                highlightedWord = w
                                                let cleaned = w.trimmingCharacters(in: .punctuationCharacters)
                                                selectedWord = cleaned
                                                showWordPopup = true
                                                updatePopupPlacement(for: w, screenWidth: screenWidth)
                                                actionFunction(word: cleaned)
                                            }
                                        }
                                        .background(
                                          GeometryReader { g in
                                            Color.clear
                                              .onAppear { wordFrames[w] = g.frame(in: .named("Overlay")) }
                                              .onChange(of: currentPieceIndex) { _ in
                                                wordFrames[w] = g.frame(in: .named("Overlay"))
                                              }
                                          }
                                        )
                                }
                            }
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.horizontal, 20)
                            .padding(.trailing, 0)
                            .padding(.bottom, showingInFullScreen ? 60 : max(safeAreaBottom + 100, 60))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, showingInFullScreen ? 90 : max(safeAreaBottom + 50, 50))
                        .padding(.horizontal, 0)
                        .padding(.trailing, 0)
                        .coordinateSpace(name: "Overlay")
                        .zIndex(2)
                    }

                    // Scrub slider
                    VStack(spacing: 6) {
                        SlimScrubber(
                            value: $playbackTime,
                            range: 0...max(duration, 0.1),
                            onScrubBegan: {
                                if !isScrubbing {
                                    isScrubbing = true
                                    wasPlayingBeforeScrub = isPlaying
                                    player.pause()
                                }
                            },
                            onScrubChanged: { t in
                                player.currentItem?.cancelPendingSeeks()
                                let target = CMTime(seconds: t, preferredTimescale: 600)
                                player.seek(
                                    to: target,
                                    toleranceBefore: CMTime(seconds: 0.03, preferredTimescale: 600),
                                    toleranceAfter: CMTime(seconds: 0.03, preferredTimescale: 600)
                                )
                            },
                            onScrubEnded: { t in
                                isScrubbing = false
                                let target = CMTime(seconds: t, preferredTimescale: 600)
                                player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                                    if wasPlayingBeforeScrub { setPlayerSpeed(speedArray[currentSpeedIndex]) }
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, 25)
                    .padding(.bottom, showingInFullScreen ? 17 : 38)
                    .zIndex(2.1)
                    .allowsHitTesting(!showWordPopup)
                    .opacity(showWordPopup ? 0.0 : 1)
                    .animation(.easeInOut(duration: 0.15), value: showWordPopup)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    
                    // Word popup overlay
                    if showWordPopup, let word = selectedWord {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    clearHighlightAndPopup()
                                }
                            }
                        
                        VStack {
                            Spacer()
                            wordPopup(
                                for: word,
                                from: userSession.currentUser?.targetLanguage ?? "",
                                to: userSession.currentUser?.nativeLanguage ?? ""
                            )
                            Triangle()
                                .fill(Color.appPrimaryColor)
                                .frame(width: 40, height: 20)
                                .rotationEffect(.degrees(180))
                                .offset(x: arrowOffsetX, y: -1) // relative to popup center
                                .allowsHitTesting(false)
                                .padding(.top, -10)
                        }
                        .offset(x: popupOffsetX)        // shift the whole popup left/right
                        .padding(.bottom, 185)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .zIndex(3)
                    }

                }
                .onChange(of: showPracticeSheet) { isShowing in
                    if isShowing {
                        player.pause()
                        isPlaying = false
                        stopWatchTimer()
                    }
                }
                .fullScreenCover(isPresented: $showPracticeSheet) {
                    PracticeFullScreen(userSession: userSession, isPresented: $showPracticeSheet)
                }

                .ignoresSafeArea(edges: .top)
                .navigationBarBackButtonHidden(true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pauseAllVideos)) { _ in
            player.pause()
        }
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
            
            fetchUsername(for: uploaderId) { username in
                if let username = username {
                    DispatchQueue.main.async {
                        self.uploaderUsername = username
                    }
                } else {
                    print("Username not found for UID \(self.uploaderId)")
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
        }.sheet(isPresented: $showingComments) {
            VideoCommentView(videoId: videoId, language: language, commentCount: $commentCount)
                .environmentObject(userSession)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Report Submitted", isPresented: $showingReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you for your report. We'll review this content.")
        }
        .modifier(TransparentNavigationBar(opacity: 0.0))
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                tap.resetForNewDayIfNeeded()
            }
        }
        //TODO: Check if the user is a pro or not
        .onAppear {
            tap.isPro = viewModel.isCurrentUserPro
        }
        //if user buys it then update
        .onChange(of: viewModel.isCurrentUserPro) { isPro in
            tap.isPro = isPro
            if(isPro) {
                //flag it back to false
                showLimitAlert = false
            }
        }
        .overlay(
            ZStack {
                if (showLimitAlert) {
                    Color.black.opacity(0.9)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation {
                                showLimitAlert = false
                            }
                        }
                    VStack {
                        Spacer()
                        GetProView()
                            .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height * 0.5)
                            .padding(.horizontal, 20)
                            .background(
                                Color(red: 22/255, green: 0/255, blue: 46/255)
                                    .cornerRadius(24)
                            )
                        Spacer()
                    }
                    .transition(.slideUpFromBottom)
                }
            }
            .animation(.easeInOut, value: showLimitAlert)
        )

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

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite else { return "0:00" }
        let total = Int(t.rounded())
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        return h > 0 ? "\(h):" + String(format:"%02d:%02d", m, s)
                     : "\(m):" + String(format:"%02d", s)
    }
    
    private func updatePopupPlacement(for token: String, screenWidth: CGFloat) {
        guard let rect = wordFrames[token] else {
            popupOffsetX = 0
            arrowOffsetX = 0
            return
        }

        let edge: CGFloat = 16
        let half = popupWidth / 2

        let desiredCenterX = min(max(rect.midX, edge + half),
                                 screenWidth - edge - half)

        popupOffsetX = desiredCenterX - (screenWidth / 2)
        arrowOffsetX = rect.midX - desiredCenterX
    }

    
    private func clearHighlightAndPopup() {
        withAnimation {
            highlightedWord = nil
            selectedWord = nil
            translatedText = nil
            showWordPopup = false
        }
    }
    
    private func splitIntoSentences(_ text: String) -> [String] {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(whereSeparator: { ".!?".contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? (cleaned.isEmpty ? [] : [cleaned]) : parts
    }

    private func chunkToOneLinePieces(sentence: String, maxWidth: CGFloat, font: UIFont = .systemFont(ofSize: 20)) -> [String] {
        guard !sentence.isEmpty else { return [] }
        var pieces: [String] = []
        var current = ""

        func width(of s: String) -> CGFloat {
            let attr: [NSAttributedString.Key: Any] = [.font: font]
            let rect = (s as NSString).boundingRect(
                with: CGSize(width: .greatestFiniteMagnitude, height: font.lineHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attr,
                context: nil
            )
            return ceil(rect.width)
        }

        for word in sentence.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : current + " " + word
            if width(of: candidate) <= maxWidth {
                current = candidate
            } else {
                if !current.isEmpty { pieces.append(current) }
                // If a single very-long word doesn't fit, hard-split it.
                if width(of: String(word)) > maxWidth {
                    var chunk = ""
                    for ch in String(word) {
                        let cand = chunk + String(ch)
                        if width(of: cand) <= maxWidth { chunk = cand }
                        else { if !chunk.isEmpty { pieces.append(chunk) }; chunk = String(ch) }
                    }
                    if !chunk.isEmpty { pieces.append(chunk) }
                    current = ""
                } else {
                    current = String(word)
                }
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    private func setupPlayer() {
        configureAudioSession()

        let asset = VideoAssetCache.shared.asset(for: url)
        let item = AVPlayerItem(asset: asset)
        
        // Enable audio processing for better quality at different speeds
        item.audioTimePitchAlgorithm = .timeDomain // Better for pitch preservation at slower speeds
        
        let queuePlayer = AVQueuePlayer()
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer

        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            let item = player.currentItem
            let dur = CMTimeGetSeconds(item?.duration ?? .invalid)
            
            if dur.isFinite && dur > 0 {
                duration = dur
            }
            if !isScrubbing {
                playbackTime = seconds.clamped(to: 0...max(duration, 0))
            }

            if let caption = captions?.first(where: { $0.start <= seconds && seconds <= $0.end }) {
                currentCaptionText = caption.text

                let baseWidth = (containerWidth ?? UIScreen.main.bounds.width)
                let horizontalPadding: CGFloat = 20 + 80 + 20
                let maxTextWidth = max(baseWidth - horizontalPadding, 100)

                //Split into sentences
                let sentences = splitIntoSentences(currentCaptionText)

                //Decide which sentence based on proportional time within this caption
                let capDuration = max(caption.end - caption.start, 0.1)
                let elapsed = seconds - caption.start
                let sIndex = min(Int((elapsed / capDuration) * Double(max(sentences.count, 1))), max(sentences.count - 1, 0))
                let sentence = sentences.isEmpty ? "" : sentences[sIndex]

                //Break that sentence into one-line pieces that fit width
                let pieces = chunkToOneLinePieces(sentence: sentence, maxWidth: maxTextWidth)

                sentencePieces = pieces.isEmpty ? [""] : pieces

                //Pick current piece based on time within this sentence slice
                let sliceDuration = capDuration / Double(max(sentences.count, 1))
                let sliceElapsed = elapsed - (Double(sIndex) * sliceDuration)
                let pieceIdx = min(Int((sliceElapsed / sliceDuration) * Double(max(pieces.count, 1))), max(pieces.count - 1, 0))
                currentPieceIndex = max(0, pieceIdx)

            } else {
                currentCaptionText = ""
                sentencePieces = []
                currentPieceIndex = 0
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
                // Set initial speed with smooth transition
                self.setPlayerSpeed(self.speedArray[self.currentSpeedIndex])
                isPlaying = true
            }
        }
    }

    private func setPlayerSpeed(_ speed: Float) {
        guard isPlayerReady else { return }
        
        if speed == 0.5 {
            player.currentItem?.audioTimePitchAlgorithm = .timeDomain
        } else if speed < 1.0 {
            player.currentItem?.audioTimePitchAlgorithm = .spectral
        } else {
            player.currentItem?.audioTimePitchAlgorithm = .lowQualityZeroLatency
        }
        
        player.rate = speed
    }

    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use .playback category with better options for audio processing
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback, // Use .moviePlayback for better video audio processing
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
            )
            
            // Set preferred sample rate and buffer duration for better audio quality
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
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
            setPlayerSpeed(speedArray[currentSpeedIndex])
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
            // Maintain the current speed when resuming with proper audio processing
            setPlayerSpeed(speedArray[currentSpeedIndex])
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

    private func handleReportVideo() {
        guard (Auth.auth().currentUser?.uid) != nil else { return }
        
        Task {
            print("Video \(language ?? "ERROR")/items/\(videoId) reported")
        }
        
        showingReportConfirmation = true
    }
    //MARK: -Here is where user taps to translate the word
    func actionFunction(word: String) {
        //have to check if the user is pro and if not then
        guard tap.tryConsume() else {
            showLimitAlert = true
            return
        }
        isTranslatingCaption = true
        withAnimation {
            translateTextV2(
                text: word,
                sourceLang: userSession.currentUser?.targetLanguage ?? "",
                targetLang: userSession.currentUser?.nativeLanguage ?? ""
            ) { result in
                if result != nil {
                    isTranslatingCaption = false
                    translatedText = result
                }
            }
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

                Button {
                    guard let userID = Auth.auth().currentUser?.uid else { return }
                    let lang = userSession.currentUser?.targetLanguage ?? ""
                    let w = (word ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !w.isEmpty else { return }

                    let alreadySaved = isWordSavedAnywhere(w, language: lang)

                    if alreadySaved {
                        clearHighlightAndPopup()
                        showPracticeSheet = true
                    } else {
                        //block saving until meaning exists
                        let meaning = (translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !meaning.isEmpty else {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            return
                        }

                        withAnimation { justSavedFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            addUnknownWordInUserSession(word: w, meaning: meaning, userId: userID)
                            withAnimation { justSavedFlash = false }
                        }
                    }
                } label: {
                    let saved = isWordSavedAnywhere((word ?? ""), language: userSession.currentUser?.targetLanguage ?? "")
                    HStack {
                        if saved {
                            Image("Vector")
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text("Practice")
                        } else if justSavedFlash {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Word saved!")
                        } else {
                            Image(systemName: "bookmark.fill")
                            Text("Save")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(isTranslatingCaption || !hasMeaning)
                .opacity((isTranslatingCaption || !hasMeaning) ? 0.6 : 1.0)

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
        .onAppear{
            //TODO: Check if the user is pro or not
        }
        //TODO: create a .onChange(of: viewModel.isCurrentUserPro) {is Pro in and set the tap to isPro then if true then don't show the alert}
    }

    func addUnknownWordInUserSession(word: String, meaning: String, userId: String) {
        guard let language = userSession.currentUser?.targetLanguage else { return }
        guard var currentUser = userSession.currentUser else { return }

        //do not save without meaning
        let meaningTrimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaningTrimmed.isEmpty else { return }

        if isWordSavedAnywhere(word, language: language) {
            videoPlayerViewModel.word = word
            videoPlayerViewModel.wordSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                videoPlayerViewModel.wordSaved = false
            }
            return
        }

        let newWord = WordPair(target: word, native: meaningTrimmed)

        var languagesData = currentUser.languagesData ?? [:]
        var langData = languagesData[language] ?? LanguagesData(savedWords: WordLists(knownWords: [], unknownWords: []))
        var savedWords = langData.savedWords ?? WordLists(knownWords: [], unknownWords: [])

        savedWords.unknownWords.append(newWord)
        langData.savedWords = savedWords
        languagesData[language] = langData
        currentUser.languagesData = languagesData
        userSession.currentUser = currentUser

        videoPlayerViewModel.saveUnknownWord(
            to: userId,
            targetLanguage: language,
            savedWord: word,
            languagesData: languagesData,
            nativeText: meaningTrimmed
        )
    }

    
    private func normalize(_ s: String) -> String {
        let extraWS = CharacterSet(charactersIn: "\u{00A0}\u{202F}") // NBSP, NNBSP
        let ws = CharacterSet.whitespacesAndNewlines.union(extraWS)
        return s.trimmingCharacters(in: ws.union(.punctuationCharacters))
    }



    private func isWordSavedAnywhere(_ word: String, language: String) -> Bool {
        let key = normalize(word)
        guard let saved = userSession.currentUser?.languagesData?[language]?.savedWords else {
            return false
        }
        let inUnknown = saved.unknownWords.contains { normalize($0.target) == key }
        let inKnown   = saved.knownWords.contains   { normalize($0.target) == key }
        return inUnknown || inKnown
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
        .frame(width: max(size, 1), height: max(size, 1)) // Ensure minimum size
        .foregroundColor(.white)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(Color.black.opacity(0))
                .frame(width: max(size + 20, 21), height: max(size + 20, 21)) // Ensure minimum size
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
                .frame(width: max(size, 1), height: max(size, 1)) // Ensure minimum size
                .foregroundColor(color)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0))
                        .frame(width: max(size + 20, 21), height: max(size + 20, 21)) // Ensure minimum size
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

func reportVideo(videoId: String, reporterUid: String, reporterUsername: String, posterUid: String, posterUsername: String) {
    guard let url = URL(string: "https://makechicken.onrender.com/api/report") else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "videoId": videoId,
        "reporterUid": reporterUid,
        "reporterUsername": reporterUsername,
        "posterUid": posterUid,
        "posterUsername": posterUsername
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Report failed:", error)
            return
        }
        print("Report sent successfully")
    }.resume()
}

func fetchUsername(for uid: String, completion: @escaping (String?) -> Void) {
    let db = Firestore.firestore()
    db.collection("users").document(uid).getDocument { snapshot, error in
        if let error = error {
            print("Error fetching user: \(error)")
            completion(nil)
            return
        }

        if let data = snapshot?.data(), let username = data["userName"] as? String {
            completion(username)
        } else {
            completion(nil)
        }
    }
}

struct TransparentNavigationBar: ViewModifier {
    var opacity: CGFloat

    init(opacity: CGFloat = 0.0) {
        self.opacity = opacity

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(opacity)

        // Hide back button text
//        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
//        appearance.backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
//        appearance.backButtonAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
//
//        // ✅ Make the chevron (back indicator) white
//        appearance.setBackIndicatorImage(
//            UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal),
//            transitionMaskImage: UIImage(systemName: "chevron.left")?.withTintColor(.white, renderingMode: .alwaysOriginal)
//        )

        // Apply appearance
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    func body(content: Content) -> some View {
        content
    }
}

struct PracticeFullScreen: View {
    @ObservedObject var userSession: UserSessionViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss  // correct presenter-level dismiss

    var body: some View {
        NavigationStack {
            PracticeView(userSession: userSession)
                .padding(.top, -50)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.appPrimaryColor)
                        }
                    }
                }
        }
    }
}

struct SlimScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onScrubBegan: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void
    var captureHeight: CGFloat = 44
    var barHeightInactive: CGFloat = 4
    var barHeightActive: CGFloat = 7

    @State private var dragging = false
    @State private var didHaptic = false

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                .clamped(to: 0...1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.clear)
                    .frame(height: dragging ? barHeightActive : barHeightInactive)

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(4, progress * w), height: dragging ? barHeightActive : barHeightInactive)
                    .shadow(color: Color.white.opacity(dragging ? 0.35 : 0), radius: dragging ? 6 : 0)
                    .scaleEffect(dragging ? 1.02 : 1.0)
                    .animation(.spring(response: 0.18, dampingFraction: 0.8), value: dragging)
            }
            .frame(height: captureHeight, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging {
                            dragging = true
                            onScrubBegan()
                            if !didHaptic {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                didHaptic = true
                            }
                        }
                        let x = min(max(0, g.location.x), w)
                        let newVal = Double(x / w) * (range.upperBound - range.lowerBound) + range.lowerBound
                        value = newVal
                        onScrubChanged(newVal)
                    }
                    .onEnded { g in
                        dragging = false
                        didHaptic = false
                        let x = min(max(0, g.location.x), w)
                        let newVal = Double(x / w) * (range.upperBound - range.lowerBound) + range.lowerBound
                        value = newVal
                        onScrubEnded(newVal)
                    }
            )
        }
        .frame(height: 44)
    }
}


extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
