//
//  DeepLinkCoordinator.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 6/6/25.
//
import Foundation

class DeepLinkCoordinator: ObservableObject {
    @Published var deepLinkVideoID: String?

    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "learnwithlinguid.com",
              let path = components.path.removingPercentEncoding,
              path.starts(with: "/videos/") else {
            DispatchQueue.main.async {
                self.deepLinkVideoID = nil
            }
            return
        }

        let videoId = path.replacingOccurrences(of: "/videos/", with: "")
        
        DispatchQueue.main.async {
            // Reset first to ensure .onChange fires every time, even for same ID
            self.deepLinkVideoID = nil
            self.deepLinkVideoID = videoId
        }
    }
    
    func deepLinkToVideo(with videoId: String) {
        DispatchQueue.main.async {
            self.deepLinkVideoID = nil
            self.deepLinkVideoID = videoId
        }
    }
}
