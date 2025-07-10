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
    @State private var hasTaskExecuted = false
    
    let onLogout: () -> Void

    init(userSession: UserSessionViewModel, onLogout: @escaping () -> Void = {}) {
        self.onLogout = onLogout
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
                            userName: vm.userName,
                            profilePictureURL: vm.profilePictureURL,
                            country: vm.country ?? "ERROR",
                            languageDisplay: vm.formattedLanguagesDisplay,
                            vm: vm,
                            onLogout: onLogout,
                            showingFullScreenProfilePicture: $showingFullScreenProfilePicture,
                            fullScreenProfilePictureURL: $fullScreenProfilePictureURL
                        )
                        .padding(.bottom, 10)
                        
                        ProfileStatsView(
                            videoCount: vm.videoCount,
                            inputAmount: vm.inputAmount,
                            followerCount: vm.followerCount
                        )
                        .padding(.bottom, 10)
                        
                        ProfileActionButtons(username: vm.userName, pfp: vm.profilePictureURL)
                            .padding(.bottom, 15)
                        
                        VideoGridSection(videoThumbnails: vm.videoThumbnails, videoURLs: vm.videoURLs, videoArray: vm.uploadedVideoArray)
                            
                    }
                    .padding()
                }
            }
            .refreshable {
                await refreshData()
            }
            .task {
                Task {
                    await loadData()
                }
            }
            .overlay(
                Group {
                    if showingFullScreenProfilePicture, let urlString = fullScreenProfilePictureURL, let url = URL(string: urlString) {
                        Rectangle()
                            .fill(Material.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture{
                                showingFullScreenProfilePicture = false
                                fullScreenProfilePictureURL = nil
                            }
                        
                        ZStack {
                            ZStack(alignment: .topTrailing) {
                                Color.black.opacity(0.01)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        showingFullScreenProfilePicture = false
                                        fullScreenProfilePictureURL = nil
                                    }
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
                                
                            }
                        }
                        .onTapGesture {
                            showingFullScreenProfilePicture = false
                            fullScreenProfilePictureURL = nil
                        }
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
            guard !hasTaskExecuted else { return }
            hasTaskExecuted = true
            print("Loading data for user: \(currentUser.uid)")
            await vm.fetchUserData()
//            print("Loaded liked video thumbnails: \(vm.likedVideoThumbnails)")
        } else {
            print("Error: No current user on appear.")
            await vm.fetchUserData()
        }
    }
    
    @MainActor
    private func refreshData() async {
        if let currentUser = Auth.auth().currentUser {
            await vm.fetchUserData(uid: currentUser.uid)
            print("Loading data for user: \(currentUser.uid)")
        } else {
            print("Error: No current user for refresh.")
            await vm.fetchUserData()
        }
    }
}

struct ProfileHeaderView: View {
    let userName: String
    let profilePictureURL: String
    let country: String
    let languageDisplay: String
    @StateObject var vm: ProfileViewModel
    let uid: String = Auth.auth().currentUser?.uid ?? ""
    var onLogout: () -> Void
    @Binding var showingFullScreenProfilePicture: Bool
    @Binding var fullScreenProfilePictureURL: String?
    
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
                showingFullScreenProfilePicture = true
                fullScreenProfilePictureURL = profilePictureURL
            } label: {
                if profilePictureURL != "" {
                    AsyncImage(url: URL(string: profilePictureURL)) { result in
                        result.image?
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .frame(width: 100, height: 100)
                    .padding(.bottom, 15)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 15)
                }
            }
            
            // Use the country name to flag converter
            Text(CountryFlagConverter.getFlag(for: country.lowercased()))
                .font(.largeTitle)
                .padding(.top, -65)
                .padding(.leading, -55)
            Text(languageDisplay)
                .lineLimit(1)
                .padding(.bottom, 10)
                .foregroundColor(.primary)
        }
    }
}
struct ProfileStatsView: View {
    let videoCount: String
    let inputAmount: String
    let followerCount: String
    
    var body: some View {
        HStack(spacing: 35) {
            Stats(text1: videoCount, text2: "videos")
            Stats(text1: "\(inputAmount)m", text2: "input")
            Stats(text1: followerCount, text2: "followers")
        }
    }
}

struct ProfileActionButtons: View {
    let username: String
    let pfp: String
    
    var body: some View {
        HStack {
            NavigationLink {
                EditProfileView(currentUsername: username, currentProfilePictureURL: URL(string: pfp))
            } label: {
                Buttons(text: "edit")
            }
            NavigationLink {
                UploadView() // <- your upload screen
            } label: {
                Buttons(text: "upload")
            }
            //Buttons(text: "upload")
            Buttons(text: "share")
        }
    }
}

struct VideoGridSection: View {
    let videoThumbnails: [String]
    let videoURLs: [String]
    var emptyMsg: String = "No videos uploaded yet."
    var videoArray: [Video]
    var body: some View {
        if videoURLs.count == 0 {
            Text(emptyMsg)
                .foregroundColor(.secondary)
                .padding(.bottom, 15)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3),
                spacing: 0
            ) {
                // Use `id: \.offset` for unique identification within ForEach
                ForEach(Array(videoThumbnails.enumerated()), id: \.offset) { index, thumbnailURL in
                    Videos(
                        thumbnailURL: thumbnailURL,
                        videoURL: videoURLs[index], // Use the video URL at the same index
                        index: index,
                        videoURLs: videoURLs, // Pass the full array for VideoView navigation
                        videoArray: videoArray
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(index >= videoThumbnails.count - (videoThumbnails.count % 3 == 0 ? 3 : videoThumbnails.count % 3) ? .clear : .primary.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity),
                        alignment: .bottom
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor((index + 1) % 3 == 0 ? .clear : .primary.opacity(0.3))
                        }
                        .frame(maxHeight: .infinity),
                        alignment: .trailing
                    )
                }
            }
            .frame(height: CGFloat((videoThumbnails.count / 3 + (videoThumbnails.count % 3 == 0 ? 0 : 1)) * 180))
            .padding(.bottom, 15)
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
    let videoURLs: [String]
    let videoArray: [Video]
    var body: some View {
        if URL(string: videoURL) != nil {
            NavigationLink {
                VideoView(videos: videoArray, userSession: UserSessionViewModel(), startIndex: index)
                    .environmentObject(UserSessionViewModel())
                    .onAppear{
                        print(index)
                    }
            } label: {
                AsyncImage(url: URL(string: thumbnailURL)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    } else if phase.error != nil {
                        Color.red.frame(height: 180)
                    } else {
                        Color.gray.frame(height: 180)
                    }
                }
            }
        } else {
            Color.gray.frame(height: 180)
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

