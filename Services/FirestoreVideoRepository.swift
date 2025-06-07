import FirebaseFirestore

final class FirestoreVideoRepository: VideoRepository {
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    
    func fetchVideos(afterID: String?, limit: Int, user:User, selectedLanguage: String) async throws -> [Video] {
        print("🔍 FETCH VIDEOS PARAMS:")
            print("   afterID: '\(afterID ?? "nil")'")
            print("   selectedLanguage: '\(selectedLanguage)'")
        print("🎯 USER DEBUG:")
            print("   User ID: \(user.id ?? "no-id")")
            print("   Watched videos count: \(user.watchedVideos?.count ?? 0)")
            print("   First 3 watched: \(Array((user.watchedVideos ?? []).prefix(3)))")
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
        
        //print("User level for \(selectedLanguage):", userLevel) // debugging code
        //print("Looking for videos in: videos/\(afterID ?? "")/items") // debugging code
        
        let snapshot = try await db.collection(videosCollection).document(selectedLanguage).collection("items").getDocuments()
        print("snapshot", snapshot)
        print("🔍 SNAPSHOT DEBUG:")
        print("   Total documents in snapshot: \(snapshot.documents.count)")
        print("   Selected language: '\(selectedLanguage)'")
        print("   First 3 document IDs: \(snapshot.documents.prefix(3).map { $0.documentID })")

        //print("Total documents found:", snapshot.documents.count) // debugging code
        let finalVideos: [Video] = snapshot.documents.compactMap { document in
            // Filtering to skip already watched videos - Gerardo 06/06/2025
            print("🔍 Checking video: \(document.documentID)") // debug code

            let isWatched = user.watchedVideos?.contains(document.documentID) ?? false
            print("Is video watched? \(isWatched)") // debug code
            
            guard !isWatched else {
                print("Video filtered out, already watched") // debug code
                return nil // Skip this video, user has already watched it.
            }
            print("Video not watched yet, keeped") // debug code
            
            guard let urlString = document.data()["video_url"] as? String,
                  let url = URL(string: urlString),
                  let title = document.data()["title"] as? String else {
                return nil
            }
            
            let detectedLevel = document.data()["detected_level"] as? Int ?? 2
            //print("Video '\(title)' has level \(detectedLevel), user level \(userLevel)") // debugging code
            print("🎯 Video \(document.documentID): detectedLevel=\(detectedLevel), userLevel=\(userLevel)")
            // Filter: only include videos within ±1 of user's level - Gerardo De La Torre
            guard detectedLevel >= (userLevel - 1) && detectedLevel <= (userLevel + 1) else {
                //print("Video '\(title)' has level \(detectedLevel), user level \(userLevel)") // debugging code
                return nil
            }
            
            return Video(id: document.documentID, url: url, title: title, detectedLevel: detectedLevel)
        }
        print("🎬 FINAL RESULTS: Returning \(finalVideos.count) videos to display")
        return finalVideos
    }
}
