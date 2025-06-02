import FirebaseFirestore

final class FirestoreVideoRepository: VideoRepository {
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    
    func fetchVideos(afterID: String?, limit: Int, user:User, selectedLanguage: String) async throws -> [Video] {
//        var query = db.collection(videosCollection)
//            .order(by: "createdAt", descending: true)
//            .limit(to: limit)
        
//        if let afterID = afterID {
//            let doc = try await db.collection(videosCollection).document(afterID).collection("items").getDocuments()
////            query = query.start(afterDocument: lastDoc)
//        } else{
//            print("fail")
//        }
        
        let userLevel = user.languagesData?[selectedLanguage]?.comprehensionLevel ?? 2
        let snapshot = try await db.collection(videosCollection).document(afterID ?? "").collection("items").getDocuments()
        print("snapshot", snapshot)
        return snapshot.documents.compactMap { document in
            guard let urlString = document.data()["video_url"] as? String,
                  let url = URL(string: urlString),
                  let title = document.data()["title"] as? String else {
                return nil
            }
            
            let detectedLevel = document.data()["detected_level"] as? Int ?? 2
            
            // Filter: only include videos within ±1 of user's level - Gerardo De La Torre
            guard detectedLevel >= (userLevel - 1) && detectedLevel <= (userLevel + 1) else {
                return nil
            }
            
            return Video(id: document.documentID, url: url, title: title, detectedLevel: detectedLevel)
        }
    }
}
