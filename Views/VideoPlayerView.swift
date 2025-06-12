//
//  VideoPlayerView.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import SwiftUI
import AVFoundation

struct VideoPlayerView: View {
    
    let url: URL //url of the video we want to play
    let videoId: String
    
    @State private var isPlaying = true //video should start by playing
    @State private var player: AVQueuePlayer = .init() //used to queue up videos for looping
    @State private var looper: AVPlayerLooper? //used to loop the video
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var isShareSheetPresented = false
    @State private var watchTimer: Timer? // timer for video watch time - Gerardo
    @State private var totalWatchTime: TimeInterval = 0 // total watch time - Gerardo
    @State private var hasBeenMarkedAsWatched = false
    
    @EnvironmentObject var userSession: UserSessionViewModel
    @StateObject var videoPlayerViewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            VideoPlayerLayerView(player: player) //layer view that visually represents the contents of the current player
                .onTapGesture {
                    togglePlayPause() // pauses/plays video upon user tap
                }
                .onAppear {
                    if let cached = VideoCache.shared.player(for: url) as? AVQueuePlayer {
                        player = cached //get the player from the cache if it already exists with the url
                        looper = AVPlayerLooper(player: cached, templateItem: AVPlayerItem(url: url)) //creates video looper
                        
                        
                    } else { //if not, we make it here
                        
                        let queuePlayer = AVQueuePlayer() //queue of player items
                        
                        looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url)) //creates video looper
                        VideoCache.shared.setPlayer(queuePlayer, for: url) //saves new queue player to the cache
                        player = queuePlayer //sets the new queue player as the player for the view
                    }
                    
                    if isPlaying { //plays as long as it wasn't manually paused by the user prior to disappearing
                        player.play()
                        startWatchTimer()
                    }
                    // marking current video as watched - Gerardo De La Torre 06/06/2025
                    Task {
                        guard let userID = userSession.currentUser?.id else { return }
                        await videoPlayerViewModel.markVideoAsWatched(videoId, userID: userID)
                    }
                }
                .onDisappear { //pauses upon disappearing
                    player.pause()
                    stopWatchTimer()
                }
            HStack {
                Spacer()

                VStack(spacing: 40) {
                    Button(action: {
                        isLiked.toggle()
                        if let user = userSession.currentUser,
                           let userId = user.id {
                            videoPlayerViewModel.toggleLike(
                                for: videoId,
                                userId: userId,
                                currentLikes: user.likedVideos ?? []
                            )
                        }

                    }) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(isLiked ? .red : .white)
                            .shadow(radius: 2)
                    }
                    .contentShape(Rectangle())

                    Button(action: {
                            // no logic yet
                        }) {
                            Image(systemName: "bubble.right")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .contentShape(Rectangle())

                    Button(action: {
                        isSaved.toggle()
                        
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(isSaved ? .yellow : .white)
                            .shadow(radius: 2)
                    }
                    .contentShape(Rectangle())
                    
                    Button(action: {
                        isShareSheetPresented = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .contentShape(Rectangle())
                    .sheet(isPresented: $isShareSheetPresented) {
                        ShareSheetView(videoId: videoId)
                            .presentationDetents([.medium, .large]) // Optional: defines height levels
                            .presentationDragIndicator(.visible)
                    }

                }
                .padding(.trailing)
            }
        }
    }

    private func togglePlayPause() {
        isPlaying.toggle() //toggles the boolean value for isPlaying
        if isPlaying {
            player.play()
            startWatchTimer()
        } else {
            player.pause()
            stopWatchTimer()
        }
    }
    
    /// Function to start the watch timer for a video
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-10
    private func startWatchTimer() {
        // Guard so we don't start the timer if it's already running
        guard watchTimer == nil else { return }
        
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in totalWatchTime += 0.1
            
            // Check if we've hit 1 second and haven't marked as watched yet
            if totalWatchTime >= 1.0 && !hasBeenMarkedAsWatched {
                hasBeenMarkedAsWatched = true
                Task { @MainActor in
                    guard let userID = userSession.currentUser?.id else { return }
                    await videoPlayerViewModel.markVideoAsWatched(videoId, userID: userID)
                }
            }
        }
    }
    
    /// Function to stop the watch timer for a video
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-10
    private func stopWatchTimer() {
        watchTimer?.invalidate()
        watchTimer = nil
    }
}


//#Preview {
    //VideoPlayerView(url: URL(string: //"https://www.youtube.com/embed/gMr8VMsRsz8")!, videoId: "gMr8VMsRsz8", //videoPlayerViewModel: VideoPlayerViewModel())
//}
