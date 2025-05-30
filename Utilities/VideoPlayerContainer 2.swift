//
//  VideoPlayerContainer.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import Foundation
import SwiftUI
import AVFoundation
import AppIntents

struct VideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<VideoPlayerContainer>) -> UIViewController {
        let controller = UIViewController()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = controller.view.bounds
        controller.view.layer.addSublayer(playerLayer)
            
        context.coordinator.layer = playerLayer
        return controller
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<VideoPlayerContainer>) {
        context.coordinator.layer?.frame = uiViewController.view.bounds
    }

    class Coordinator {
        var layer: AVPlayerLayer?
    }
}
