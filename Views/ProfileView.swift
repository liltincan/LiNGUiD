import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @StateObject private var vm: ProfileViewModel
    @EnvironmentObject var state: AppState
    @StateObject private var viewModel: SavedWordViewModel
    @StateObject var userSession: UserSessionViewModel
    
    @State private var showingFullScreenProfilePicture: Bool = false
    @State private var fullScreenProfilePictureURL: String?
    
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var backgroundUploader: BackgroundUploader
    @State private var isShowingUploadView = false
    @State private var overlayVisible = true
    @Binding var selectedTab: Int
    let onLogout: () -> Void
    
    // Add this property to detect navigation context
    let showBackButton: Bool
    @Environment(\.dismiss) private var dismiss
    
    private var showOverlay: Bool {
        backgroundUploader.totalToUpload > 0 && (overlayVisible || !backgroundUploader.isUploadComplete)
    }
    private var barProgress: Double {
        backgroundUploader.isUploadComplete ? 1 : backgroundUploader.barProgressNormalized
    }
    private var stepText: String {
        backgroundUploader.isUploadComplete
        ? "Upload complete!"
        : "Uploading \(backgroundUploader.completedCount + 1)/\(backgroundUploader.totalToUpload)...\(Int((barProgress * 100).rounded()))%"
    }
    
    @Environment(\.colorScheme) var colorScheme

    init(userSession: UserSessionViewModel, onLogout: @escaping () -> Void = {}, selectedTab: Binding<Int>, showBackButton: Bool = false) {
        self.onLogout = onLogout
        self._selectedTab = selectedTab
        self.showBackButton = showBackButton
        _userSession = StateObject(wrappedValue: userSession)
        _vm = StateObject(wrappedValue: ProfileViewModel(userSession: userSession))
        _viewModel = StateObject(wrappedValue: SavedWordViewModel(userSession: userSession))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    VStack {
                        ProfileHeaderView(
                            userSession: userSession,
                            userName: vm.userName,
                            profilePictureURL: vm.profilePictureURL,
                            country: vm.country ?? "ERROR",
                            languageDisplay: vm.formattedLanguagesDisplay,
                            vm: vm,
                            onLogout: onLogout,
                            showingFullScreenProfilePicture: $showingFullScreenProfilePicture,
                            fullScreenProfilePictureURL: $fullScreenProfilePictureURL,
                            selectedTab: $selectedTab,
                            showBackButton: showBackButton,
                            onBackTapped: {
                                dismiss()
                            }
                        )
                        .padding(.top, -15)
                        
                        ProfileStatsView(
                            videoCount: vm.videoCount,
                            inputAmount: vm.inputAmount,
                            followerCount: vm.followerCount,
                            ownerUid: Auth.auth().currentUser?.uid ?? ""
                        )
                        .padding(.top, -10)
                        
                        ProfileActionButtons(username: vm.userName, pfp: vm.profilePictureURL, isShowingUploadView: $isShowingUploadView, onUploadComplete: {await refreshData()})
                            .padding(.bottom, 10)
                        ScrollView{
                            VideoGridSection(
                                videoThumbnails: vm.videoThumbnails.reversed(),
                                videoURLs: vm.videoURLs.reversed(),
                                uploadingVideos: uploadManager.uploadingVideos,
                                noVideosMessage: "No videos uploaded yet.",
                                videoArray: vm.uploadedVideoArray.reversed(),
                                selectedTab: $selectedTab,
                                fromOtherUserProfile: false,
                                onLogout: onLogout
                            )
                        }
                    }
                    .padding(.top)
                }
                .scrollIndicators(.hidden)
            }
            .refreshable {
                await refreshData()
            }
            .onAppear {
                uploadManager.onUploadFinished = {
                    Task {
                        await refreshData()
                    }
                }
                Task {
                    await loadData()
                }
            }
            .overlay(
                ZStack {
                    VStack(spacing: 0) {
                        if showOverlay {
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.appPrimaryColor.opacity(0.5))
                                    .frame(height: 40)
                                    .overlay(Rectangle().stroke(colorScheme == .dark ? .clear : .clear, lineWidth: 1))

                                Rectangle()
                                    .fill(Color.appPrimaryColor.opacity(0.75))
                                    .frame(width: UIScreen.main.bounds.width * CGFloat(barProgress), height: 40)
                                    .clipShape(RoundedCorner(radius: 0, corners: [.topRight, .bottomRight]))
                                    .animation(backgroundUploader.isUploadComplete ? nil : .easeInOut(duration: 0.12),
                                               value: barProgress)

                                HStack {
                                    let done = backgroundUploader.isUploadComplete

                                    Text(stepText)
                                      .font(.system(size: 16, weight: .medium))
                                      .foregroundColor(.white)
                                      .frame(maxWidth: .infinity, alignment: done ? .center : .leading)
                                      .padding(.leading, done ? 0 : 20)
                                      .animation(.easeInOut(duration: 0.25), value: done)
                                }
                            }
                            .padding(.top, -10)
                            .transition(.opacity)
                        }

                        Spacer()
                    }
                }
            )
            //.animation(.easeInOut, value: showOverlay)
            .onChange(of: backgroundUploader.isUploadComplete) { _, done in
                if done {
                    // Hold “Upload complete!” briefly, then fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            overlayVisible = false
                        }
                        // After the fade finishes (~0.35s), clear the uploader’s visual state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            // We're on the main thread; the method is @MainActor-safe
                            backgroundUploader.clearFinishedBatchVisuals()
                        }
                    }
                } else {
                    withAnimation { overlayVisible = true }
                }
            }
            .onChange(of: backgroundUploader.totalToUpload) { _, total in
                // If a new item gets enqueued later, show the overlay again
                if total > 0 {
                    withAnimation { overlayVisible = true }
                }
            }

            .overlay(
                ZStack {
                    //Fullscreen Profile Picture
                    if showingFullScreenProfilePicture,
                       let urlString = fullScreenProfilePictureURL,
                       let url = URL(string: urlString) {

                        ZStack {
                            // Dimmed/tappable background
                            Rectangle()
                                .fill(Material.ultraThinMaterial)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    showingFullScreenProfilePicture = false
                                    fullScreenProfilePictureURL = nil
                                }

                            VStack {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFit()
                                        } else if phase.error != nil {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundColor(.red)
                                                .frame(width: 100, height: 100)
                                        } else {
                                            CustomProgressView(progress: 0.45)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.clear)
                                }
                            }
                            .padding(20)
                            .transition(.opacity)
                        }
                    }
                }
            )
            .animation(.easeInOut, value: showingFullScreenProfilePicture)
        }
        .navigationBarBackButtonHidden(showBackButton) // Hide default back button when using custom one
    }
    
    @MainActor
    private func loadData() async {
        if let currentUser = Auth.auth().currentUser {
            print("Loading data for user: \(currentUser.uid)")
            await vm.fetchUserData(uid: currentUser.uid)
            userSession.getCurrentUser()
        } else {
            print("Error: No current user on appear.")
            await vm.fetchUserData()
            userSession.getCurrentUser()
        }
    }
    
    @MainActor
    private func refreshData() async {
        if let currentUser = Auth.auth().currentUser {
            await vm.fetchUserData(uid: currentUser.uid)
            userSession.getCurrentUser()
            print("Loading data for user: \(currentUser.uid)")
        } else {
            print("Error: No current user for refresh.")
            await vm.fetchUserData()
            userSession.getCurrentUser()
        }
    }
    
    private var currentUploadId: String? {
        let i = uploadManager.currentIndex
        return uploadManager.uploadingVideos.indices.contains(i)
            ? uploadManager.uploadingVideos[i].localIdentifier
            : nil
    }

    private var overlayPercentInt: Int {
        guard let id = currentUploadId else { return 0 }
        // keep the same rounding as your thumbnail
        return Int(((backgroundUploader.progressById[id] ?? 0) * 100).rounded())
    }
}
extension Int {
    func abbreviated() -> String {
        let n = Double(self)
        func fmt(_ v: Double) -> String {
            v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
        }
        switch n {
        case 0..<1_000: return String(Int(n))
        case 1_000..<1_000_000: return fmt(n/1_000) + "K"
        case 1_000_000..<1_000_000_000: return fmt(n/1_000_000) + "M"
        default: return fmt(n/1_000_000_000) + "B"
        }
    }
}

struct ProfileHeaderView: View {
    let userSession: UserSessionViewModel
    let userName: String
    let profilePictureURL: String
    let country: String
    let languageDisplay: String
    @StateObject var vm: ProfileViewModel
    let uid: String = Auth.auth().currentUser?.uid ?? ""
    var onLogout: () -> Void
    @Binding var showingFullScreenProfilePicture: Bool
    @Binding var fullScreenProfilePictureURL: String?
    @Binding var selectedTab: Int
    @StateObject private var proVM = ProStatusViewModel()
    @State private var shouldNavigateToEdit = false
    var showBackButton: Bool = false
    var onBackTapped: () -> Void = { }
    var body: some View {
        VStack {
            ZStack{
                if(!showBackButton){
                    ZStack {
                        HStack(spacing: 0) {
                            Text(userName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if proVM.isPro {
                                Image(systemName: "checkmark.seal.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.appPrimaryColor)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.leading, 0)
                        
                        Spacer()
                        
                        HStack{
                            Spacer()
                            
                            NavigationLink {
                                SettingsView(
                                    likedVideos: vm.likedVideoThumbnails,
                                    likedVideoURLs: vm.likedVideoURLs,
                                    savedVideos: vm.savedVideoThumbnails,
                                    savedVideoURLs: vm.savedVideoURLs,
                                    likedVideoArray: vm.likedVideoArray,
                                    savedVideoArray: vm.savedVideoArray,
                                    languages: vm.allLanguageNames,
                                    uid: uid,
                                    selectedNativeLanguages: Set([vm.nativeLanguage?.lowercased() ?? ""]),
                                    selectedTab: $selectedTab,
                                    onLogout: onLogout
                                )
                            } label: {
                                Image(systemName: "gear")
                                    .font(.system(size: 26, weight: .bold))
                                    .padding(.trailing, 20)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                } else{
                    HStack {
                        Button {
                            onBackTapped()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        HStack(spacing: 0) {
                            Text(userName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if proVM.isPro {
                                Image(systemName: "checkmark.seal.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.appPrimaryColor)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        NavigationLink {
                            SettingsView(
                                likedVideos: vm.likedVideoThumbnails,
                                likedVideoURLs: vm.likedVideoURLs,
                                savedVideos: vm.savedVideoThumbnails,
                                savedVideoURLs: vm.savedVideoURLs,
                                likedVideoArray: vm.likedVideoArray,
                                savedVideoArray: vm.savedVideoArray,
                                languages: vm.allLanguageNames,
                                uid: uid,
                                selectedNativeLanguages: Set([vm.nativeLanguage?.lowercased() ?? ""]),
                                selectedTab: $selectedTab,
                                onLogout: onLogout
                            )
                        } label: {
                            Image(systemName: "gear")
                                .font(.system(size: 26, weight: .bold))
                                .padding(.trailing, 20)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.bottom, 10)
                }
               
            }
            .padding(.bottom, 10)
            
            Button {
                if profilePictureURL != "" {
                    showingFullScreenProfilePicture = true
                    fullScreenProfilePictureURL = profilePictureURL
                } else {
                    shouldNavigateToEdit = true
                    print("Edit profile picture tapped")
                }
            } label: {
                ZStack {
                    if profilePictureURL != "" {
                        AsyncImage(url: URL(string: profilePictureURL)) { result in
                            result.image?
                                .resizable()
                                .scaledToFill()
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                Text("edit")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .padding(.top, -20)
            
            Text(CountryFlagConverter.getFlag(for: country.lowercased()))
                .font(.system(size: 20))
                .padding(.top, -25)
                .padding(.leading, -35)
            
            VStack(spacing: 0){
                HStack(spacing: -10) {
                    VStack(spacing: -10) {
                        Text(userSession.currentUser?.nativeLanguage?.uppercased() ?? "")
                            .font(.system(size: 14, weight: .medium))
                        MiniProgressBarView()
                            .padding(.top, -7.5)
                    }
                    
                    Image(systemName: "chevron.right.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .padding(.top, -15)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: -20) {
                        ForEach(userSession.currentUser?.targetLanguageList?.sorted() ?? [], id: \.self) { language in
                            VStack(spacing: -10) {
                                Text(language.uppercased())
                                    .font(.system(size: 14, weight: .medium))

                                LevelDotsView(level: userSession.currentUser?.languagesData?[language]?.comprehensionLevel ?? 0)
                                    .padding(.top, -7.5)
                            }
                        }
                    }
                }
            }
            .padding(.top, -5)
        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                proVM.startListening(uid: uid)
            }
        }
        .onDisappear {
            proVM.stopListening()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        
        NavigationLink(
            destination: EditProfileView(
                currentUsername: userName,
                currentProfilePictureURL: URL(string: profilePictureURL)
            ),
            isActive: $shouldNavigateToEdit
        ) {
            EmptyView()
        }
        .hidden()
    }
}
// Rest of your structs remain the same...
struct LevelDotsView: View {
    @Environment(\.colorScheme) var colorScheme
    let level: Int
    let maxLevel: Int = 5

    var body: some View {
        let firstEmptyIndex = level < maxLevel ? level : nil

        HStack(spacing: 1.5) {
            ForEach(0..<maxLevel, id: \.self) { index in
                let isFilled = index < level
                let isFirstEmpty = index == firstEmptyIndex

                Circle()
                    .fill(isFilled ? Color.appPrimaryColor : Color.white)
                    .frame(width: isFirstEmpty ? 3 : 4, height: isFirstEmpty ? 3 : 4)
                    .overlay(
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 0.5)
                    )
                    .padding(.leading, isFirstEmpty ? 1 : 0)
                    .padding(.trailing, isFirstEmpty ? 0.75 : 0)
                    .padding(.top, isFirstEmpty ? 0.5 : 0)
            }
        }
        .padding()
        .background(Color.clear)
    }
}

struct MiniProgressBarView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.appPrimaryColor)
                .frame(width: 26, height: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 0.5)
                )
        }
        .padding()
        .background(Color.clear)
    }
}

struct ProfileStatsView: View {
    let videoCount: String
    let inputAmount: String
    let followerCount: String
    let ownerUid: String
    
    var body: some View {
        HStack(spacing: 30) {
            Stats(text1: videoCount, text2: "videos")
                .padding(.leading, 15)
            
            Stats(text1: "\(inputAmount)m", text2: "input")
            
            NavigationLink {
                FollowersView(ownerUid: ownerUid)
            } label: {
                Stats(text1: followerCount, text2: "followers")
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

struct ProfileActionButtons: View {
    let username: String
    let pfp: String
    @Binding var isShowingUploadView: Bool
    let onUploadComplete: () async -> Void
    @EnvironmentObject var backgroundUploader: BackgroundUploader
    
    @State private var showingShareSheet = false
    
    private var isUploading: Bool {
        backgroundUploader.totalToUpload > 0 && !backgroundUploader.isUploadComplete
    }
    
    private var shareURL: URL? {
        // Create the profile share URL using the username or user ID
        URL(string: "https://learnwithlinguid.com/profiles/\(Auth.auth().currentUser!.uid)")
    }
    
    var body: some View {
        HStack(spacing: 12.5) {
            NavigationLink {
                EditProfileView(currentUsername: username, currentProfilePictureURL: URL(string: pfp))
            } label: {
                Buttons(text: "edit")
            }
            NavigationLink(isActive: $isShowingUploadView) {
                UploadView(onComplete: {
                    isShowingUploadView = false
                    Task {
                        await onUploadComplete()
                    }
                })
            } label: {
                Buttons(text: isUploading ? "upload" : "upload")
                        .opacity(isUploading ? 0.6 : 1)
            }
            .disabled(isUploading)
            .animation(isUploading ? .easeInOut.delay(1) : .easeInOut, value: isUploading)
            
            Button {
                showingShareSheet = true
            } label: {
                Buttons(text: "share")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

struct VideoGridSection: View {
    let videoThumbnails: [String]
    let videoURLs: [String]
    let uploadingVideos: [UploadManager.UploadingVideo]
    let noVideosMessage: String?
    let gridItemWidth = (UIScreen.main.bounds.width - 5) / 3
    let thumbnailHeight = (UIScreen.main.bounds.width - 5) * 16 / 27
    var videoArray: [Video]
    @Binding var selectedTab: Int
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var backgroundUploader: BackgroundUploader
    @EnvironmentObject var userSession: UserSessionViewModel
    let fromOtherUserProfile: Bool
    let onLogout: () -> Void
    
    @State private var programmaticOpenTarget: String? = nil

    var body: some View {
        Group{
            if videoThumbnails.isEmpty && uploadingVideos.isEmpty {
                VStack {
                    Spacer()
                    Text(noVideosMessage ?? "No videos available.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(gridItemWidth), spacing: 0), count: 3),
                          spacing: 0) {
                    ForEach(uploadingVideos.reversed()) { video in
                        ZStack {
                            Image(uiImage: video.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: gridItemWidth, height: thumbnailHeight)
                                .clipped()
                            
                            if video.isUploading {
                                Color.appPrimaryColor.opacity(0.5)
                                ZStack {
                                    Color.clear
                                    CustomProgressView(progress: video.progress)
                                    if video.progress < 0.99{
                                        VStack {
                                            Spacer()
                                            Spacer()
                                            Button {
                                                backgroundUploader.cancelUpload(id: video.localIdentifier)
                                                uploadManager.removeUploadingVideo(id: video.localIdentifier)
                                            } label: {
                                                Text("cancel")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .stroke(Color.white, lineWidth: 1.0)
                                                    )
                                            }
                                            .padding(.bottom, 30)
                                        }
                                    }
                                }
                            }
                        }
                        .overlay(
                            Rectangle()
                                .stroke(Color.primary.opacity(1.0), lineWidth: 1.5)
                        )
                    }
                    ForEach(Array(videoThumbnails.enumerated()), id: \.offset) { index, thumbnailURL in
                        Videos(
                            thumbnailURL: thumbnailURL,
                            videoURL: videoURLs[index],
                            index: index,
                            videoArray: videoArray,
                            allVideoURLs: videoURLs,
                            onLogout: onLogout,
                            selectedTab: $selectedTab,
                            fromOtherUserProfile: fromOtherUserProfile,
                            programmaticOpenTarget: $programmaticOpenTarget
                        )
                        .environmentObject(userSession)
                        .overlay(
                            Rectangle()
                                .stroke(Color.primary.opacity(1.0), lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, 5)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVideoFromOtherUserProfile)) { note in
            guard fromOtherUserProfile else { return }
            guard let incoming = note.userInfo?["videoId"] as? String, !incoming.isEmpty else { return }

            // Try id first, then allow url fallback
            if let match = videoArray.first(where: { $0.id == incoming || $0.url.absoluteString == incoming }) {
                programmaticOpenTarget = match.url.absoluteString
            } else if videoURLs.contains(incoming) {
                programmaticOpenTarget = incoming
            }
        }
    }
}

struct Stats: View {
    let text1: String
    let text2: String
    
    var body: some View {
        VStack{
            Text(text1)
                .font(.system(size: 16))
                .bold()
                .foregroundColor(.primary)
            Text(text2)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
    }
}

struct Videos: View {
    let thumbnailURL: String
    let videoURL: String
    let index: Int
    let videoArray: [Video]
    let allVideoURLs: [String]
    let gridItemWidth = (UIScreen.main.bounds.width - 5) / 3
    let thumbnailHeight = (UIScreen.main.bounds.width - 5) * 16 / 27
    let onLogout: () -> Void
    
    @EnvironmentObject var userSession: UserSessionViewModel
    @Binding var selectedTab: Int

    @State private var reloadID = UUID()
    @State private var retryCount = 0
    private let maxRetryCount = 3

    @State private var isShowingVideoSheet = false
    @StateObject private var viewCounts = ViewCountsStore()

    private var selectedVideo: Video? {
        videoArray.first { $0.url.absoluteString == videoURL }
    }

    private var orderedVideos: [Video] {
        var ordered: [Video] = []
        for url in allVideoURLs {
            if let video = videoArray.first(where: { $0.url.absoluteString == url }) {
                ordered.append(video)
            }
        }
        return ordered
    }

    let fromOtherUserProfile: Bool
    
    @Binding var programmaticOpenTarget: String?
    
    var body: some View {
        if let video = selectedVideo {
            Button {
                isShowingVideoSheet = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: thumbnailURL), transaction: Transaction(animation: .easeInOut)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(width: gridItemWidth, height: thumbnailHeight)
                                .clipped()
                                .onAppear { retryCount = 0 }
                        case .failure(_):
                            Color.gray.frame(width: gridItemWidth, height: thumbnailHeight)
                                .onAppear {
                                    if retryCount < maxRetryCount {
                                        retryCount += 1
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { reloadID = UUID() }
                                    }
                                }
                        case .empty:
                            Color.gray.frame(width: gridItemWidth, height: thumbnailHeight)
                        @unknown default:
                            Color.gray.frame(width: gridItemWidth, height: thumbnailHeight)
                        }
                    }
                    .frame(width: gridItemWidth, height: thumbnailHeight)
                    .clipped()

                    if let vid = selectedVideo {
                        let count = viewCounts.value(lang: vid.language, id: vid.id)
                        ZStack(alignment: .bottomTrailing) {
                            HStack(spacing: 6) {
                                Image(systemName: "play")
                                    .symbolRenderingMode(.monochrome)
                                Text(count.abbreviated())
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                            .padding(.trailing, 4)
                            .padding(.bottom, 3)
                        }
                        .onAppear { viewCounts.attach(lang: vid.language, id: vid.id) }
                    }
                }
                .id(reloadID)
            }
            .onChange(of: programmaticOpenTarget) { _, target in
                guard let target = target else { return }
                if target == videoURL || target == video.id {
                    isShowingVideoSheet = true
                    DispatchQueue.main.async { programmaticOpenTarget = nil }
                }
            }
            .onAppear {
                if let target = programmaticOpenTarget,
                   target == videoURL || target == video.id {
                    isShowingVideoSheet = true
                    DispatchQueue.main.async { programmaticOpenTarget = nil }
                }
            }
            .fullScreenCover(isPresented: $isShowingVideoSheet) {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.edgesIgnoringSafeArea(.all)
                        
                        VideoView(
                            videos: orderedVideos,
                            userSession: userSession,
                            startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
                            selectedTab: $selectedTab,
                            fromProfile: fromOtherUserProfile,
                            ownProfile: !fromOtherUserProfile,
                            onLogout: onLogout
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .padding(.top, 50)
                        
                    }
                }
                .ignoresSafeArea()
            }
        } else {
            Color.gray.frame(width: gridItemWidth, height: thumbnailHeight)
        }
    }
}

struct Buttons: View{
    let text: String
    
    var body: some View{
        Text(text)
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 80, height: 32, alignment: .center)
            .background(Color.appPrimaryColor)
            .cornerRadius(8)
    }
}

final class ViewCountsStore: ObservableObject {
    @Published private(set) var counts: [String: Int] = [:]
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]

    private func key(_ lang: String, _ id: String) -> String { "\(lang)#\(id)" }

    deinit { listeners.values.forEach { $0.remove() } }

    func attach(lang: String, id: String) {
        let k = key(lang, id)
        guard listeners[k] == nil else { return }

        listeners[k] = db
            .collection("videos").document(lang)
            .collection("items").document(id)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let data = snap?.data() else { return }
                if let v = data["views"] as? Int {
                    self.counts[k] = v
                } else if let d = data["views"] as? Double {
                    self.counts[k] = Int(d)
                }
            }
    }

    func value(lang: String, id: String) -> Int { counts[key(lang, id)] ?? 0 }

    func prefetch(videos: [Video]) {
        videos.forEach { attach(lang: $0.language, id: $0.id) }
    }
}

