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
    @State private var isShowingUploadView = false
    @Binding var selectedTab: Int
    let onLogout: () -> Void
    

    init(userSession: UserSessionViewModel, onLogout: @escaping () -> Void = {}, selectedTab: Binding<Int>) {
        self.onLogout = onLogout
        self._selectedTab = selectedTab
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
                            selectedTab: $selectedTab
                        )
                        .padding(.top, -15)
                        
                        ProfileStatsView(
                            videoCount: vm.videoCount,
                            inputAmount: vm.inputAmount,
                            followerCount: vm.followerCount,
                            onFollowersTapped: {
                                print("Followers tapped")
                            }
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
                                fromOtherUserProfile: false
                            )
                        }
                    }
                    .padding(.vertical)
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
                    // Upload Progress Bar
                    VStack {
                        if uploadManager.totalToUpload > 0 {
                            Text(
                                uploadManager.completedCount == uploadManager.totalToUpload
                                ? "Upload complete!"
                                : "Uploading \(uploadManager.completedCount + 1)/\(uploadManager.totalToUpload)"
                            )
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: uploadManager.completedCount)

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
                                            ProgressView()
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.clear) // Ensures the tap registers outside image only
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
    
    
    var body: some View {
        VStack {
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
                    // Profile image or default
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


            
            // Use the country name to flag converter
            Text(CountryFlagConverter.getFlag(for: country.lowercased()))
                .font(.system(size: 20))
                .padding(.top, -25)
                .padding(.leading, -35)
        
//            Text(languageDisplay)
//                .lineLimit(1)
//                .padding(.bottom, 10)
//                .foregroundColor(.primary)
            
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

struct LevelDotsView: View {
    @Environment(\.colorScheme) var colorScheme
    let level: Int // current level, e.g., 3
    let maxLevel: Int = 5 // total dots

    var body: some View {
        // Determine the first empty index (if any)
        let firstEmptyIndex = level < maxLevel ? level : nil

        HStack(spacing: 1.5) {
            ForEach(0..<maxLevel, id: \.self) { index in
                let isFilled = index < level
                let isFirstEmpty = index == firstEmptyIndex

                Circle()
                    .fill(isFilled ? Color.appPrimaryColor : Color.white)
                    .frame(width: isFirstEmpty ? 2 : 4, height: isFirstEmpty ? 2 : 4)
                    .overlay(
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 0.5)
                    )
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
    var onFollowersTapped: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 30) {
            Stats(text1: videoCount, text2: "videos")
                .padding(.leading, 15)
            Stats(text1: "\(inputAmount)m", text2: "input")
            Button {
                onFollowersTapped?()
            } label: {
                Stats(text1: followerCount, text2: "followers")
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ProfileActionButtons: View {
    let username: String
    let pfp: String
    @Binding var isShowingUploadView: Bool
    let onUploadComplete: () async -> Void  // Add this parameter
    
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
                        await onUploadComplete()  // Wrap in Task
                    }
                })
            } label: {
                Buttons(text: "upload")
            }
            Buttons(text: "share")
        }
    }
}

struct VideoGridSection: View {
    let videoThumbnails: [String]
    let videoURLs: [String]
    let uploadingVideos: [UploadManager.UploadingVideo]
    let noVideosMessage: String?  // Optional custom message
    let gridItemWidth = (UIScreen.main.bounds.width - 5) / 3
    let thumbnailHeight = (UIScreen.main.bounds.width - 5) * 16 / 27
    var videoArray: [Video]
    @Binding var selectedTab: Int
    @EnvironmentObject var uploadManager: UploadManager
    @EnvironmentObject var userSession: UserSessionViewModel
    let fromOtherUserProfile: Bool

    var body: some View {
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
                            ProgressView().scaleEffect(1.5).progressViewStyle(CircularProgressViewStyle(tint: .white))
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        uploadManager.cancelUpload(for: video.localIdentifier)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .padding(.top, 5)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(1.0), lineWidth: 1.5)
                    )
                }
                ForEach(Array(videoThumbnails.enumerated()), id: \.offset) { index, thumbnailURL in
                    if(fromOtherUserProfile){
                        Videos(
                            thumbnailURL: thumbnailURL,
                            videoURL: videoURLs[index],
                            index: index,
                            videoArray: videoArray,
                            allVideoURLs: videoURLs,
                            selectedTab: $selectedTab,
                            fromOtherUserProfile: true
                        )
                        .environmentObject(userSession)
                        .overlay(
                            Rectangle()
                                .stroke(Color.primary.opacity(1.0), lineWidth: 1.5)
                        )
                    } else {
                        Videos(
                            thumbnailURL: thumbnailURL,
                            videoURL: videoURLs[index],
                            index: index,
                            videoArray: videoArray,
                            allVideoURLs: videoURLs,
                            selectedTab: $selectedTab,
                            fromOtherUserProfile: false
                        )
                        .environmentObject(userSession)
                        .overlay(
                            Rectangle()
                                .stroke(Color.primary.opacity(1.0), lineWidth: 1.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .center)
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
    
    
    @EnvironmentObject var userSession: UserSessionViewModel
    @Binding var selectedTab: Int

    @State private var reloadID = UUID() //force reload by changing this
    @State private var retryCount = 0
    private let maxRetryCount = 3

    @State private var isShowingVideoSheet = false

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
    
    var body: some View {
        if let video = selectedVideo {
            NavigationLink {
                if(fromOtherUserProfile){
                    VideoView(
                        videos: orderedVideos,
                        userSession: userSession,
                        startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
                        selectedTab: $selectedTab,
                        fromProfile: true
                    )
                }else{
                    VideoView(
                        videos: orderedVideos,
                        userSession: userSession,
                        startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
                        selectedTab: $selectedTab,
                        fromProfile: false
                    )
                }
            } label: {
                AsyncImage(url: URL(string: thumbnailURL), transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: gridItemWidth, height: thumbnailHeight)
                            .clipped()
                            .onAppear {
                                retryCount = 0
                            }

                    case .failure(_):
                        VStack {
                            Color.gray.frame(width: gridItemWidth, height: thumbnailHeight)
                                .onAppear {
                                    if retryCount < maxRetryCount {
                                        retryCount += 1
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            reloadID = UUID()
                                        }
                                    }
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
                .id(reloadID) //forces reload when ID changes
            }
            .fullScreenCover(isPresented: $isShowingVideoSheet) {
                GeometryReader { geometry in
                    ZStack {
                        Color.black.edgesIgnoringSafeArea(.all)
                        if(fromOtherUserProfile){
                            VideoView(
                                videos: orderedVideos,
                                userSession: userSession,
                                startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
                                selectedTab: $selectedTab,
                                fromProfile: true
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .padding(.top, 60)
                        }else{
                            VideoView(
                                videos: orderedVideos,
                                userSession: userSession,
                                startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
                                selectedTab: $selectedTab,
                                fromProfile: false
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .padding(.top, 60)
                        }
                        // Use VerticalVideoScrollView for consistent video player experience
//                        VideoView(
//                            videos: orderedVideos,
//                            userSession: userSession,
//                            startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
//                            selectedTab: $selectedTab,
//                            fromProfile: <#T##Bool#>
//                        )
                        
                        
                        // Custom back button with chevron and text
                        VStack {
                            HStack {
                                Button {
                                    isShowingVideoSheet = false
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Back")
                                            .font(.system(size: 17, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Capsule())
                                }
                                .padding(.leading, 20)
                                .padding(.top, 80)
                                Spacer()
                            }
                            Spacer()
                        }
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
            //.padding(15)
            .frame(width: 80, height: 32, alignment: .center)
            .background(Color.appPrimaryColor)
            .cornerRadius(8)
    }
}

