//
//  VideoPlayerView.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let url: URL //url of video we want to play
    @State private var isPlaying = true //used to check if video is currently being played
    @State private var observer: Any? //used to monitor video completion
        
    private var player: AVPlayer {
        VideoCache.shared.player(for: url) ?? AVPlayer(url: url)  //searches cache for video player with url and creates one if it doesn't exist
    }
    
    var body: some View {
        VideoPlayer(player: player) //create video player from the AV player created with URL
            .scaledToFill()
            .ignoresSafeArea()
            .onTapGesture { // play/pause on tap
                togglePlayPause()
            }
            .onAppear { //initiate video loop as soon as it's shown on screen
                startLooping()
                if isPlaying { //only play video if user did not manually pause it before scrolling away
                    player.play()
                }
            }
            .onDisappear { //pause video when it leaves the screen
                player.pause()
            }
    }
    
    private func togglePlayPause() {
        isPlaying.toggle() //switches boolean value of isPlaying
        isPlaying ? player.play() : player.pause() //plays if set to playing, pauses if not
    }
    
    private func startLooping() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) {_ in
            player.seek(to: .zero) //checks to see when video finishes in entirety and resets it to the beginning
            
            if isPlaying { //only play video if user did not manually pause it before scrolling
                player.play()
            }
        }
    }
}

#Preview {
    VideoPlayerView(url: URL(string: "https://www.w3schools.com/html/mov_bbb.mp4")!)
}

