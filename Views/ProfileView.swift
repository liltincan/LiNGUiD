import SwiftUI
import FirebaseAuth

struct ProfileView: View {
      @StateObject private var vm = ProfileViewModel()
      @EnvironmentObject var state: AppState
       
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
//                                          languageDisplay: "En → \(String(vm.language)) (Lvl \(String(vm.lvl)))",
                                          languageDisplay: vm.formattedLanguagesDisplay,
                                          vm: vm
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
                        vm.fetchData(uid: FirebaseAuth.Auth.auth().currentUser!.uid)
//                        vm.fetchData(uid: "ZzQKRM0coDg7yl4CIyfeHp5wLVv1")
                  }
                  .onAppear() {
                      vm.fetchData(uid: FirebaseAuth.Auth.auth().currentUser!.uid)
//                        vm.fetchData(uid: "ZzQKRM0coDg7yl4CIyfeHp5wLVv1")
                        print("Loaded liked video thumbnails: \(vm.likedVideoThumbnails)")
                        print(vm.dataReady)
                  }
            }
      }
}

// MARK: - Subviews

struct ProfileHeaderView: View {
      let userName: String
      let profilePictureURL: String
      let languageDisplay: String
      let vm: ProfileViewModel
       
      var body: some View {
            VStack {
                  ZStack{
                        Text(userName)
                              .font(.system(size: 27))
                              .bold()
//                              .foregroundColor(.white)
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
//                                          .foregroundColor(.white)
                                          .padding(10)
                                          .foregroundColor(.primary)
                              }
                        }
                  }
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
//                              .foregroundColor(.white)
                              .padding(.bottom, 15)
                  }
                   
                  Text(languageDisplay)
//                        .font(.system(size: 20))
                        .lineLimit(1)
//                        .foregroundColor(.white)
                        .padding(.bottom, 10)
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
                        .foregroundColor(.gray)
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
                                                .foregroundColor(index >= videoThumbnails.count - (videoThumbnails.count % 3 == 0 ? 3 : videoThumbnails.count % 3) ? .clear : .white)
                                    }
                                    .frame(maxWidth: .infinity),
                                    alignment: .bottom
                              )
                              .overlay(
                                    HStack {
                                          Spacer()
                                          Rectangle()
                                                .frame(width: 1)
                                                .foregroundColor((index + 1) % 3 == 0 ? .clear : .white)
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

// MARK: - Reusable Components

struct Stats: View {
      let text1: String
      let text2: String
       
      var body: some View {
            VStack{
                  Text(text1)
                        .font(.system(size: 20))
//                        .foregroundColor(.white)
                        .bold()
                  Text(text2)
                        .font(.system(size: 15))
//                        .foregroundColor(.white)
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
            .font(.system(size: 13))
            .padding()
            .frame(maxWidth: 100)
            .background(Color(red: 0.486, green: 0.227, blue: 0.929))
            .cornerRadius(10)
//            .foregroundColor(.primary)
      }
}

struct ProfileView_Previews: PreviewProvider {
      static var previews: some View {
            ProfileView()
                  .environmentObject(AppState())
      }
}
