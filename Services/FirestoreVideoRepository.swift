import FirebaseFirestore

final class FirestoreVideoRepository: VideoRepository {
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    
    func fetchVideos(afterID: String?, limit: Int) async throws -> [Video] {
        var query = db.collection(videosCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let afterID = afterID {
            let lastDoc = try await db.collection(videosCollection).document(afterID).getDocument()
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { document in
            guard let urlString = document.data()["url"] as? String,
                  let url = URL(string: urlString),
                  let title = document.data()["title"] as? String else {
                return nil
            }
            
            return Video(id: document.documentID, url: url, title: title)
        }
    }
}
