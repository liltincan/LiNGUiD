import Foundation

struct Video: Identifiable, Codable {
    let id: String
    let url: URL
    let captions: [Captions]
    let title: String
    // TODO: add other metadata (duration, thumbnailURL, etc.)
    let detectedLevel: Int // detected difficulty level
}

struct Captions: Codable {
    let end: Double
    let start: Double
    let text: String
    let words: [String]?
}

