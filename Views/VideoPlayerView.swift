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
    
    @State private var isPlaying = true //video should start by playing
    @State private var player: AVQueuePlayer = .init() //used to queue up videos for looping
    @State private var looper: AVPlayerLooper? //used to loop the video

    var body: some View {
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
                }
            }
            .onDisappear { //pauses upon disappearing
                player.pause()
            }
    }

    private func togglePlayPause() {
        isPlaying.toggle() //toggles the boolean value for isPlaying
        isPlaying ? player.play() : player.pause() //plays if true, pauses if not
    }
    
}


#Preview {
    VideoPlayerView(url: URL(string: "https://www.w3schools.com/html/mov_bbb.mp4")!)
}

