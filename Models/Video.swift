import Foundation

struct Video: Identifiable, Codable {
    let id: String
    let url: URL
    let title: String
    // TODO: add other metadata (duration, thumbnailURL, etc.)
    let detectedLevel: Int // detected difficulty level
}

