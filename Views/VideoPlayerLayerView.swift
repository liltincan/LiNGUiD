import SwiftUI
import AVKit

struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = player
        view.videoGravity = .resizeAspectFill
        view.backgroundColor = UIColor.systemBackground
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
    }
}
