import FirebaseFirestore

final class FirestoreVideoRepository: VideoRepository {
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    
    func fetchVideos(afterID: String?, limit: Int, user:User, selectedLanguage: String) async throws -> [Video] {
//        var query = db.collection(videosCollection)
//            .order(by: "createdAt", descending: true)
//            .limit(to: limit)

        if let afterID = afterID {
            let doc = try await db.collection(videosCollection).document(afterID).collection("items").getDocuments()
//            query = query.start(afterDocument: lastDoc)
        } else{
            print("fail")
        }
        
        let userLevel = user.languagesData?[selectedLanguage]?.comprehensionLevel ?? 2
        
        let snapshot = try await db.collection(videosCollection).document(selectedLanguage).collection("items").getDocuments()
        //print("snapshot", snapshot)

        // Filtering out watched videos at document level (more efficient)
        let unwatchedDocuments = snapshot.documents.filter { document in
            !(user.watchedVideos?.contains(document.documentID) ?? false)
        }

        // Convert documents to video objects
        let unwatchedVideos: [Video] = unwatchedDocuments.compactMap { document in
            guard let urlString = document.data()["video_url"] as? String,
                  let url = URL(string: urlString),
                  let title = document.data()["title"] as? String,
                  let captionDicts = document.data()["captions"] as? [[String: Any]] else {
                return nil
            }

            let captions: [Captions] = captionDicts.compactMap { dict in
                guard let start = dict["start"] as? Double,
                      let end = dict["end"] as? Double,
                      let text = dict["text"] as? String else {
                    return nil
                }
                let words = dict["words"] as? [String]
                return Captions(end: end, start: start, text: text, words: words)
            }

            
            
            let detectedLevel = document.data()["detected_level"] as? Int ?? 2
            return Video(id: document.documentID, url: url, captions: captions, title: title, detectedLevel: detectedLevel)
        }

        // Filter: only include videos within ±1 of user's level - Gerardo De La Torre
        let finalVideos = unwatchedVideos.filter { video in
            video.detectedLevel >= (userLevel - 1) && video.detectedLevel <= (userLevel + 1)
        }
        
        // logging for total videos available for selected language
        print("Total videos in \(selectedLanguage): \(snapshot.documents.count)")
        print("User comprehension level: \(userLevel)")
        print("User watched video count: \(user.watchedVideos?.count ?? 0)")
        print("Unwatched videos: \(unwatchedDocuments.count)")
        print("Videos matching level \(userLevel-1)-\(userLevel+1): \(finalVideos.count)")

        // logging depending if we have videos available to show
        if finalVideos.isEmpty {
            print("No videos available after filtering. Showing watched videos instead")

            // Re-filter all videos by level only, ignoring watched status
            let allVideosAtLevel: [Video] = snapshot.documents.compactMap { document in
                guard let urlString = document.data()["video_url"] as? String,
                    let url = URL(string: urlString),
                    let title = document.data()["title"] as? String,
                    let captionDicts = document.data()["captions"] as? [[String: Any]] else {
                        return nil
                }
                let captions: [Captions] = captionDicts.compactMap { dict in
                    guard let start = dict["start"] as? Double,
                        let end = dict["end"] as? Double,
                        let text = dict["text"] as? String else {
                            return nil
                    }
                    let words = dict["words"] as? [String]
                    return Captions(end: end, start: start, text: text, words: words)
                }

                let detectedLevel = document.data()["detected_level"] as? Int ?? 2
                guard detectedLevel >= (userLevel - 1) && detectedLevel <= (userLevel + 1) else {
                    return nil
                }
                return Video(id: document.documentID, url: url, captions: captions, title: title, detectedLevel: detectedLevel)
            }
            return allVideosAtLevel
        } else {
            print("Returning \(finalVideos.count) videos to user")
        }
        return finalVideos
    }
}
