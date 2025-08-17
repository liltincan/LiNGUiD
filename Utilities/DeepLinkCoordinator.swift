import Foundation
import SwiftUI

class DeepLinkCoordinator: ObservableObject {
    @Published var deepLinkVideoID: String?
    @Published var deepLinkProfileID: String?

    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "learnwithlinguid.com",
              let path = components.path.removingPercentEncoding else {
            return
        }

        print("🔗 DeepLink: Processing URL \(url.absoluteString)")
        
        // Handle video deep links
        if path.starts(with: "/videos/") {
            let videoId = path.replacingOccurrences(of: "/videos/", with: "")
            print("🔗 DeepLink: Video ID extracted: \(videoId)")
            
            // Reset state before setting new values
            DispatchQueue.main.async {
                // First reset both values
                print("🔗 DeepLink: Resetting deep link state for URL video")
                self.deepLinkProfileID = nil
                self.deepLinkVideoID = nil
                
                // Then set the new value after a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("🔗 DeepLink: Setting video ID from URL: \(videoId)")
                    self.deepLinkVideoID = videoId
                }
            }
            return
        }
        
        // Handle profile deep links
        if path.starts(with: "/profiles/") {
            let profileId = path.replacingOccurrences(of: "/profiles/", with: "")
            print("🔗 DeepLink: Profile ID extracted: \(profileId)")
            
            // Reset state before setting new values
            DispatchQueue.main.async {
                // First reset both values
                print("🔗 DeepLink: Resetting deep link state for URL profile")
                self.deepLinkVideoID = nil
                self.deepLinkProfileID = nil
                
                // Then set the new value after a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("🔗 DeepLink: Setting profile ID from URL: \(profileId)")
                    self.deepLinkProfileID = profileId
                }
            }
            return
        }
        
        print("🔗 DeepLink: No valid path found in URL")
    }
    
    func deepLinkToVideo(with videoId: String) {
        print("🔗 DeepLink: Direct video link request: \(videoId)")
        DispatchQueue.main.async {
            // First reset both values
            print("🔗 DeepLink: Resetting deep link state for direct video")
            self.deepLinkProfileID = nil
            self.deepLinkVideoID = nil
            
            // Then set the new value after a longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔗 DeepLink: Setting video ID directly: \(videoId)")
                self.deepLinkVideoID = videoId
            }
        }
    }
    
    func deepLinkToProfile(with profileId: String) {
        print("🔗 DeepLink: Direct profile link request: \(profileId)")
        DispatchQueue.main.async {
            // First reset both values
            print("🔗 DeepLink: Resetting deep link state")
            self.deepLinkVideoID = nil
            self.deepLinkProfileID = nil
            
            // Then set the new value after a longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔗 DeepLink: Setting profile ID: \(profileId)")
                self.deepLinkProfileID = profileId
            }
        }
    }
}
