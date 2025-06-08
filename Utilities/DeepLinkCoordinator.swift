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
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if components?.host == "learnwithlinguid.com",
           let path = components?.path,
           path.starts(with: "/videos/") {
            let videoId = path.replacingOccurrences(of: "/videos/", with: "")
            deepLinkVideoID = videoId
        }
    }
}
