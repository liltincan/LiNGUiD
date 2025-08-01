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
                ScrollView {
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
                            .padding(.bottom, 0)
                        
                        VideoGridSection(
                            videoThumbnails: vm.videoThumbnails.reversed(),
                            videoURLs: vm.videoURLs.reversed(),
                            uploadingVideos: uploadManager.uploadingVideos,
                            noVideosMessage: "No videos uploaded yet.",
                            videoArray: vm.uploadedVideoArray.reversed(),
                            selectedTab: $selectedTab
                        )
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

                    // 🖼 Fullscreen Profile Picture
                    if showingFullScreenProfilePicture,
                       let urlString = fullScreenProfilePictureURL,
                       let url = URL(string: urlString) {

                        Rectangle()
                            .fill(Material.ultraThinMaterial)
                            .ignoresSafeArea()

                        ZStack {
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

                                Button {
                                    showingFullScreenProfilePicture = false
                                    fullScreenProfilePictureURL = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                        .padding(15)
                                }
                            }
                        }
                        .padding(20)
                        .transition(.opacity)
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
    
    
    var body: some View {
        VStack {
            ZStack{
                Text(userName)
                    .font(.system(size: 27))
                    .bold()
                    .foregroundColor(.primary)
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
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .padding(10)
                            .foregroundColor(.primary)
                    }
                }
            }
            Button {
                if profilePictureURL != "" {
                    showingFullScreenProfilePicture = true
                    fullScreenProfilePictureURL = profilePictureURL
                } else {
                    // Trigger image picker or edit action here
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
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .padding(.top, -15)


            
            // Use the country name to flag converter
            Text(CountryFlagConverter.getFlag(for: country.lowercased()))
                .font(.largeTitle)
                .padding(.top, -50)
                .padding(.leading, -50)
//            Text(languageDisplay)
//                .lineLimit(1)
//                .padding(.bottom, 10)
//                .foregroundColor(.primary)
            
            VStack(spacing: 0){
                HStack(spacing: 10) {
                    Text(userSession.currentUser?.nativeLanguage?.uppercased() ?? "")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Image(systemName: "chevron.right.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                    
                    Text(userSession.currentUser?.targetLanguage.uppercased() ?? "")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                LevelDotsView(level: userSession.currentUser?.languagesData?[userSession.currentUser?.targetLanguage ?? ""]?.comprehensionLevel ?? 0)
                    .padding(.top, -10)
            }
            .padding(.top, -25)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct LevelDotsView: View {
    let level: Int // current level, e.g., 3
    let maxLevel: Int = 5 // total dots

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Circle()
                    .fill(index < level ? Color.appPrimaryColor : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 0.75)
                    )
            }
        }
        .padding()
        .background(Color.clear)
        //.background(Color.black)
    }
}

struct ProfileStatsView: View {
    let videoCount: String
    let inputAmount: String
    let followerCount: String
    var onFollowersTapped: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 35) {
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
        HStack {
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
                            Color.appSecondaryColor.opacity(0.3)
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
                    Videos(
                        thumbnailURL: thumbnailURL,
                        videoURL: videoURLs[index],
                        index: index,
                        videoArray: videoArray,
                        allVideoURLs: videoURLs,
                        selectedTab: $selectedTab
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
}

struct Stats: View {
    let text1: String
    let text2: String
    
    var body: some View {
        VStack{
            Text(text1)
                .font(.system(size: 20))
                .bold()
                .foregroundColor(.primary)
            Text(text2)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
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

    var body: some View {
        if let video = selectedVideo {
            NavigationLink {
                VideoView(
                    videos: orderedVideos,
                    userSession: userSession,
                    startIndex: orderedVideos.firstIndex(where: { $0.id == video.id }) ?? 0,
                    selectedTab: $selectedTab
                )
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
            .fontWeight(.medium)
            .font(.system(size: 16))
            .padding(15)
            .frame(maxWidth: 100, maxHeight: 45)
            .background(Color.appPrimaryColor)
            .cornerRadius(10)
    }
}

