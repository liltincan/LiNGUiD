import Foundation

protocol VideoRepository {
    /// Fetches a page of videos; if `afterID` is nil, fetch first page
    func fetchVideos(afterID: String?, limit: Int) async throws -> [Video]
}
