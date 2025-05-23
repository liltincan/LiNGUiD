import FirebaseFirestore

final class FirestoreVideoRepository: VideoRepository {
    private let db = Firestore.firestore()

    func fetchVideos(afterID: String?, limit: Int) async throws -> [Video] {
        // TODO: implement Firestore paginated query
        fatalError("Not implemented")
    }
}
