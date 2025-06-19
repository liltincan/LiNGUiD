import AVKit
import SwiftUI

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @State private var currentIndex = 0
    @ObservedObject var userSession: UserSessionViewModel

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
                VerticalVideoFeed(videos: vm.videos, currentIndex: $currentIndex, userSession: userSession, vm: vm)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            Task { await vm.fetchInitialVideos() }
        }
    }
}

struct VerticalVideoFeed: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    @ObservedObject var userSession: UserSessionViewModel
    @ObservedObject var vm: VideoFeedViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(videos.indices, id: \.self) { index in
                            FeedVideoPage(
                                video: videos[index],
                                isActive: index == currentIndex,
                                userSession: userSession,
                                language: vm.selectedLanguage,
                                containerWidth: screenWidth,
                                containerHeight: screenHeight
                            )
                            .frame(width: screenWidth, height: screenHeight)
                            .id(index)
                            .background(
                                GeometryReader { itemGeo in
                                    Color.clear
                                        .onAppear {
                                            checkIfCentered(index: index, geometry: itemGeo, screenHeight: screenHeight)
                                        }
                                        .onChange(of: itemGeo.frame(in: .global)) { oldFrame, newFrame in
                                            checkIfCentered(index: index, geometry: itemGeo, screenHeight: screenHeight)
                                        }
                                }
                            )
                            
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .onAppear {
                    currentIndex = 0
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
}

struct FeedVideoPage: View {
    let video: Video
    let isActive: Bool
    @ObservedObject var userSession: UserSessionViewModel
    let language: String?
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    var body: some View {
        ZStack {
            Color.black
            VideoPlayerView(
                url: video.url,
                videoId: video.id,
                language: language,
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                isActive: isActive,
                captions: video.captions
            )
            .environmentObject(userSession)
        }
        .frame(width: containerWidth, height: containerHeight)
    }
}
