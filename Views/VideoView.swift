import SwiftUI
import AVKit

struct VideoView: View {
    let fromProfile: Bool
    let ownProfile: Bool
    let videos: [Video]
    @State private var currentIndex: Int
    @ObservedObject var userSession: UserSessionViewModel
    @Binding var selectedTab: Int
    init(videos: [Video], userSession: UserSessionViewModel, startIndex: Int, selectedTab: Binding<Int>, fromProfile: Bool, ownProfile: Bool) {
        self.videos = videos
        print(videos)
        self.userSession = userSession
        _currentIndex = State(initialValue: startIndex)
        self._selectedTab = selectedTab
        self.fromProfile = fromProfile
        self.ownProfile = ownProfile
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if videos.isEmpty {
                Text("No videos found.")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            } else {
                if(fromProfile){
                    VerticalVideoScrollView(
                        videos: videos,
                        currentIndex: $currentIndex,
                        userSession: userSession,
                        selectedTab: $selectedTab,
                        fromProfile: true,
                        ownProfile: false
                    )
                }else{
                    VerticalVideoScrollView(
                        videos: videos,
                        currentIndex: $currentIndex,
                        userSession: userSession,
                        selectedTab: $selectedTab,
                        fromProfile: false,
                        ownProfile: true
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct VerticalVideoScrollView: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    @ObservedObject var userSession: UserSessionViewModel
    @State private var hasInitialized = false
    @Binding var selectedTab: Int
    let fromProfile: Bool
    let ownProfile: Bool
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(videos, id: \.id) { video in
                            let index = videos.firstIndex(where: { $0.id == video.id }) ?? 0
                            if(fromProfile){
                                VideoPageView(
                                    video: video,
                                    isActive: index == currentIndex,
                                    userSession: userSession,
                                    containerWidth: screenWidth,
                                    containerHeight: screenHeight,
                                    selectedTab: $selectedTab,
                                    fromProfile: true,
                                    ownProfile: false
                                )
                                .frame(width: screenWidth, height: screenHeight)
                                .id(video.id)  // Using stable video ID
                            } else{
                                VideoPageView(
                                    video: video,
                                    isActive: index == currentIndex,
                                    userSession: userSession,
                                    containerWidth: screenWidth,
                                    containerHeight: screenHeight,
                                    selectedTab: $selectedTab,
                                    fromProfile: false,
                                    ownProfile: true
                                )
                                .frame(width: screenWidth, height: screenHeight)
                                .id(video.id)  // Using stable video ID
                            }
                        }
                    }
                    .background(
                        GeometryReader { scrollGeo in
                            Color.clear
                                .onChange(of: scrollGeo.frame(in: .global)) { oldFrame, newFrame in
                                    // Only update index after initialization is complete
                                    if hasInitialized {
                                        updateCurrentIndex(scrollOffset: newFrame.minY, screenHeight: screenHeight)
                                    }
                                }
                        }
                    )
                }
                .scrollTargetBehavior(.paging)
                .onAppear {
                    if currentIndex >= videos.count {
                        currentIndex = 0
                    }
                    
                    // Scroll to initial position using video ID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if currentIndex < videos.count {
                            proxy.scrollTo(videos[currentIndex].id, anchor: .top)
                            
                            // Mark as initialized after scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                hasInitialized = true
                            }
                        }
                    }
                }
                .onChange(of: videos) { oldVideos, newVideos in
                    if currentIndex >= newVideos.count {
                        currentIndex = 0
                    }
                    hasInitialized = false
                }
            }
        }
        .background(Color.black)
    }
    
    private func updateCurrentIndex(scrollOffset: CGFloat, screenHeight: CGFloat) {
        let newIndex = Int(round(-(scrollOffset) / screenHeight))
        let clampedIndex = max(0, min(newIndex, videos.count - 1))
        
        if clampedIndex != currentIndex {
            currentIndex = clampedIndex
        }
    }
}

struct VideoPageView: View {
    let video: Video
    let isActive: Bool
    @ObservedObject var userSession: UserSessionViewModel
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    @Binding var selectedTab: Int
    @State private var uploaderPfp: String?
    let fromProfile: Bool
    let ownProfile: Bool
    
    var body: some View {
        ZStack {
            Color.black
            if(fromProfile){
                VideoPlayerView(
                    url: video.url,
                    videoId: video.id,
                    language: video.language,
                    uploaderId: video.uploaderId,
                    uploaderPfp: uploaderPfp,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight,
                    isActive: isActive,
                    captions: video.captions,
                    videoLikes: video.likes,
                    videoSaves: video.saves,
                    commentCount: video.commentCount,
                    selectedTab: $selectedTab,
                    showingInFullScreen: true,
                    ownProfile: false
                )
                .environmentObject(userSession)
                .id(video.id)
            } else{
                VideoPlayerView(
                    url: video.url,
                    videoId: video.id,
                    language: video.language,
                    uploaderId: video.uploaderId,
                    uploaderPfp: uploaderPfp,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight,
                    isActive: isActive,
                    captions: video.captions,
                    videoLikes: video.likes,
                    videoSaves: video.saves,
                    commentCount: video.commentCount,
                    selectedTab: $selectedTab,
                    showingInFullScreen: false,
                    ownProfile: true
                )
                .environmentObject(userSession)
                .id(video.id)
            }
        }
        .frame(width: containerWidth, height: containerHeight)
        .onAppear {
            // Fetch profile picture asynchronously when view appears
            Task {
                do {
                    uploaderPfp = try await FirestoreService.shared.getUserProfilePicture(forUserId: video.uploaderId)
                } catch {
                    print("Error fetching uploader profile picture: \(error.localizedDescription)")
                    uploaderPfp = nil
                }
            }
        }
    }
}
