import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @EnvironmentObject var state: AppState
    
    // State to control full-screen profile picture visibility
    @State private var showingFullScreenProfilePicture: Bool = false
    // State to hold the URL of the profile picture to display full screen
    @State private var fullScreenProfilePictureURL: String?
    
    func getUID() -> String {
        guard let uid = FirebaseAuthService.shared.currentUserID else {
            print("Error: User ID is nil. User is not logged in.")
            DispatchQueue.main.async {
                vm.user = ""
                vm.lvl = ""
                vm.videoCount = "0"
                vm.inputAmt = "0"
                vm.followerCount = "0"
                vm.videos = []
                vm.videoThumbnails = []
                vm.videoURLs = []
                vm.profilePicture = ""
                vm.dataReady = true
            }
            state.isSignedIn = false
            return ""
        }
        return uid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack {
                        ProfileHeaderView(
                            userName: vm.user,
                            profilePictureURL: vm.profilePicture,
                            languageDisplay: vm.formattedLanguagesDisplay,
                            vm: vm,
                            showingFullScreenProfilePicture: $showingFullScreenProfilePicture,
                            fullScreenProfilePictureURL: $fullScreenProfilePictureURL
                        )
                        .padding(.bottom, 10)
                        
                        ProfileStatsView(
                            videoCount: vm.videoCount,
                            inputAmount: vm.inputAmt,
                            followerCount: vm.followerCount
                        )
                        .padding(.bottom, 10)
                        
                        ProfileActionButtons(username: vm.user, pfp: vm.profilePicture)
                            .padding(.bottom, 15)
                        
                        VideoGridSection(videoThumbnails: vm.videoThumbnails, videoURLs: vm.videoURLs)
                            
                    }
                    .padding()
                }
            }
            .refreshable {
                if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                    vm.fetchData(uid: uid)
                } else {
                    print("Error: No current user for refresh.")
                }
            }
            .onAppear() {
                if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                    vm.fetchData(uid: uid)
                } else {
                    print("Error: No current user on appear.")
                }
                print("Loaded liked video thumbnails: \(vm.likedVideoThumbnails)")
                print(vm.dataReady)
            }
            // MARK: - Full Screen Profile Picture Overlay
            .overlay(
                Group {
                    if showingFullScreenProfilePicture, let urlString = fullScreenProfilePictureURL, let url = URL(string: urlString) {
                        // Use adaptive material for the background
                        Rectangle()
                            .fill(Material.ultraThinMaterial) // Adaptive translucent background
                            .ignoresSafeArea()
                        
                        // Center the content in the ZStack
                        ZStack {
                            // This ZStack will contain the AsyncImage and the Button, allowing the Button
                            // to be positioned relative to the AsyncImage's frame.
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit() // Display the full image, fitting the screen
                                    } else if phase.error != nil {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.red) // Error icon color
                                            .frame(width: 100, height: 100)
                                    } else {
                                        ProgressView() // Loading indicator
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity) // Make image fill available space
                                
                                // X button
                                Button {
                                    showingFullScreenProfilePicture = false
                                    fullScreenProfilePictureURL = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white) // White color for visibility on dark material
                                        .padding(15) // Adjust padding to position the button relative to the image
                                }
                            }
                        }
                        .padding(20) // Padding around the entire ZStack to keep content off edges
                        .transition(.opacity) // Smooth transition for appearance/disappearance
                    }
                }
            )
            .animation(.easeInOut, value: showingFullScreenProfilePicture) // Animate the transition
        }
    }
}

// MARK: - Subviews

struct ProfileHeaderView: View {
    let userName: String
    let profilePictureURL: String
    let languageDisplay: String
    let vm: ProfileViewModel
    
    // Bindings to control the full-screen view from the parent ProfileView
    @Binding var showingFullScreenProfilePicture: Bool
    @Binding var fullScreenProfilePictureURL: String?
    
    var body: some View {
        VStack {
            ZStack{
                Text(userName)
                    .font(.system(size: 27))
                    .bold()
                    .foregroundColor(.primary) // Adaptive text color
                HStack{
                    Spacer()
                    NavigationLink {
                        SettingsView(
                            likedVideos: vm.likedVideoThumbnails,
                            savedVideos: vm.savedVideoThumbnails
                        )
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .padding(10)
                            .foregroundColor(.primary) // Adaptive icon color
                    }
                }
            }
            
            // Use a Button to trigger the overlay visibility
            Button {
                showingFullScreenProfilePicture = true
                fullScreenProfilePictureURL = profilePictureURL
            } label: {
                if profilePictureURL != "" {
                    AsyncImage(url: URL(string: profilePictureURL)) { result in
                        result.image?
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle()) // Keep circular crop for the main profile view
                            .contentShape(Circle()) // Makes the whole circle tappable
                    }
                    .frame(width: 100, height: 100)
                    .padding(.bottom, 15)
                } else {
                    // Fallback image if profilePictureURL is empty
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.secondary) // Adaptive fallback icon color
                        .padding(.bottom, 15)
                }
            }
            
            Text(languageDisplay)
                .lineLimit(1)
                .padding(.bottom, 10)
                .foregroundColor(.primary) // Adaptive text color
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
            Buttons(text: "upload")
            Buttons(text: "share")
        }
    }
}

struct VideoGridSection: View {
    let videoThumbnails: [String]
    let videoURLs: [String]
    var emptyMsg: String = "No videos uploaded yet."
    
    var body: some View {
        if videoThumbnails.isEmpty {
            Text(emptyMsg)
                .foregroundColor(.secondary) // Adaptive text color
                .padding(.bottom, 15)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3),
                spacing: 0
            ) {
                ForEach(Array(videoThumbnails.enumerated()), id: \.element) { index, thumbnailURL in
                    Videos(
                        thumbnailURL: thumbnailURL,
                        videoURL: videoURLs[index],
                        index: index,
                        videoURLs: videoURLs
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(index >= videoThumbnails.count - (videoThumbnails.count % 3 == 0 ? 3 : videoThumbnails.count % 3) ? .clear : .primary.opacity(0.3)) // Adaptive separator line
                        }
                        .frame(maxWidth: .infinity),
                        alignment: .bottom
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor((index + 1) % 3 == 0 ? .clear : .primary.opacity(0.3)) // Adaptive separator line
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
                .foregroundColor(.primary) // Adaptive text color
            Text(text2)
                .font(.system(size: 15))
                .foregroundColor(.secondary) // Adaptive text color
        }
    }
}

struct Videos: View {
    let thumbnailURL: String
    let videoURL: String
    let index: Int
    let videoURLs: [String]
    
    var body: some View {
        if URL(string: videoURL) != nil {
            NavigationLink {
                VideoView(videos: videoURLs, startIndex: index)
            } label: {
                AsyncImage(url: URL(string: thumbnailURL)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    } else if phase.error != nil {
                        Color.red.frame(height: 180) // Error placeholder
                    } else {
                        Color.gray.frame(height: 180) // Loading placeholder
                    }
                }
            }
        } else {
            Color.gray.frame(height: 180) // Invalid URL placeholder
        }
    }
}

struct Buttons: View{
    let text: String
    
    var body: some View{
        Text(text)
            .foregroundColor(.white) // Hardcoded for brand color
            .fontWeight(.medium)
            .font(.system(size: 13))
            .padding()
            .frame(maxWidth: 100)
            .background(Color(red: 0.486, green: 0.227, blue: 0.929)) // Hardcoded custom purple
            .cornerRadius(10)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}
