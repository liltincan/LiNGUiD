import Foundation

struct Video: Identifiable, Codable, Equatable {
    let id: String
    let url: URL
    let captions: [Captions]?
    let title: String
    let detectedLevel: Int
    let uploaderId: String
    let likes: Int
    let saves: Int
    let language: String
    static func == (lhs: Video, rhs: Video) -> Bool {
    return lhs.id == rhs.id
}
}

struct Captions: Codable, Equatable {
    let end: Double
    let start: Double
    let text: String
    let words: [String]?
}

