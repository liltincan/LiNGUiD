//
//  PlayerView.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import SwiftUI
import AVFoundation

class PlayerView: UIView {
    private let playerLayer = AVPlayerLayer() //visually represents the context of our AVPlayer

    var player: AVPlayer? { //derived from the player layer above
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame) //gets the dimensions of the screen for the bounds using CGRect
        playerLayer.videoGravity = .resizeAspectFill //makes sure it maintains aspect ratio but fills screen
        layer.addSublayer(playerLayer) //adds to current layer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented") //I'm not quite sure how that works yet
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

#Preview {
    PlayerView()
}
