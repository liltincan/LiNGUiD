//
//  VideoPlayerLayerView.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import SwiftUI
import AVFoundation

struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer //player we'll use to create the layer view

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView() //view with video player layer that fills screen appropriately
        view.player = player //sets the view's player to the current player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player //updates with new player to represent visually
    }
}

//#Preview {
    //VideoPlayerLayerView()
//}
