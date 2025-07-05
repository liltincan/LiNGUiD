import Foundation
import FirebaseFirestore

protocol VideoRepository {
    func fetchVideos(afterID: String?, limit: Int, user: User, selectedLanguage: String) async throws -> [Video]
    
    func fetchVideoById(videoId: String, user: User, selectedLanguage: String) async throws -> Video?
}
