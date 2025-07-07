import AVKit
import SwiftUI
import Foundation

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @State private var currentIndex = 0
    @ObservedObject var userSession: UserSessionViewModel
    
    // Add optional starting video ID parameter
    let startingVideoId: String?
    
    @State private var hasScrolledToInitialVideo = false
    
    // Add initializer to accept optional video ID
    init(userSession: UserSessionViewModel, startingVideoId: String? = nil) {
        self.userSession = userSession
        self.startingVideoId = startingVideoId
        print("startingVideoId: \(String(describing: startingVideoId))")
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let error = vm.errorMessage {
                Text(error)
                    .font(.title3)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if vm.videos.isEmpty {
                Text("No videos found.")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            } else {
                VerticalVideoFeed(
                    videos: vm.videos,
                    currentIndex: $currentIndex,
                    userSession: userSession,
                    vm: vm,
                    startingVideoId: startingVideoId,
                    hasScrolledToInitialVideo: $hasScrolledToInitialVideo
                )
            }
        }
        .ignoresSafeArea()
        .task(id: startingVideoId) {
            hasScrolledToInitialVideo = false
            if let id = startingVideoId {
                await vm.resetVideos(startingWith: id)
            } else {
                await vm.fetchInitialVideos()
            }
        }
        .onChange(of: vm.deepLinkedVideoIndex) { newIndex in
            if let newIndex = newIndex {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    currentIndex = newIndex
                }
            }
        }
    }
    
    private func setInitialVideoIndex(for videoId: String) {
        if let index = vm.videos.firstIndex(where: { $0.id == videoId }) {
            currentIndex = index
        }
    }
}

struct VerticalVideoFeed: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    @ObservedObject var userSession: UserSessionViewModel
    @ObservedObject var vm: VideoFeedViewModel
    let startingVideoId: String?

    @Binding var hasScrolledToInitialVideo: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(videos, id: \.id) { video in
                            let index = videos.firstIndex(where: { $0.id == video.id }) ?? 0

                            FeedVideoPage(
                                video: video,
                                isActive: index == currentIndex,
                                userSession: userSession,
                                language: vm.selectedLanguage,
                                containerWidth: screenWidth,
                                containerHeight: screenHeight
                            )
                            .frame(width: screenWidth, height: screenHeight)
                            .id(video.id) // Use stable video ID for scrolling
                            .background(
                                GeometryReader { itemGeo in
                                    Color.clear
                                        .onAppear {
                                            checkIfCentered(index: index, geometry: itemGeo, screenHeight: screenHeight)
                                        }
                                        .onChange(of: itemGeo.frame(in: .global)) { _, _ in
                                            checkIfCentered(index: index, geometry: itemGeo, screenHeight: screenHeight)
                                        }
                                }
                            )
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .onChange(of: videos) { newVideos in
                    guard !hasScrolledToInitialVideo,
                          let startingVideoId = startingVideoId,
                          newVideos.contains(where: { $0.id == startingVideoId }) else { return }

                    currentIndex = newVideos.firstIndex(where: { $0.id == startingVideoId }) ?? 0

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(startingVideoId, anchor: .center)
                        hasScrolledToInitialVideo = true
                    }
                }
                .onChange(of: currentIndex) { oldIndex, newIndex in
                    if newIndex >= videos.count - 2 && !vm.isLoading {
                        Task { await vm.fetchMoreVideos() }
                    }
                }
            }
        }
        .background(Color.black)
    }
    
    private func checkIfCentered(index: Int, geometry: GeometryProxy, screenHeight: CGFloat) {
        let frame = geometry.frame(in: .global)
        let screenCenter = screenHeight / 2
        let itemCenter = frame.midY
        let distanceFromCenter = abs(itemCenter - screenCenter)
        
        if distanceFromCenter < screenHeight / 4 {
            if index != currentIndex {
                currentIndex = index
            }
        }
    }
    
    private func scrollToStartingVideoIfNeeded(proxy: ScrollViewProxy, videos: [Video]) {
        guard !hasScrolledToInitialVideo,
              let startingVideoId = startingVideoId,
              let index = videos.firstIndex(where: { $0.id == startingVideoId }) else {
            return
        }
        currentIndex = index // Set before scroll

        DispatchQueue.main.async {
            proxy.scrollTo(index, anchor: .center)
            hasScrolledToInitialVideo = true
        }
    }
}

struct FeedVideoPage: View {
    let video: Video
    let isActive: Bool
    @ObservedObject var userSession: UserSessionViewModel
    let language: String?
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    
    @State private var uploaderPfp: String?
    
    var body: some View {
        ZStack {
            Color.black
            
            VideoPlayerView(
                url: video.url,
                videoId: video.id,
                language: language,
                uploaderId: video.uploaderId,
                uploaderPfp: uploaderPfp,
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                isActive: isActive,
                captions: video.captions
            )
            .environmentObject(userSession)
            .id(video.id)
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
