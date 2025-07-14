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
        
        let langCode = selectedLanguage.lowercased()
        let snapshot = try await db.collection(videosCollection).document(langCode).collection("items").getDocuments()

        //print("snapshot", snapshot)

        // Filtering out watched videos at document level (more efficient)
        let unwatchedDocuments = snapshot.documents.filter { document in
            !(user.watchedVideos?.contains(document.documentID) ?? false)
        }

        // Convert documents to video objects
        let unwatchedVideos: [Video] = unwatchedDocuments.compactMap { document in
            guard let urlString = document.data()["video_url"] as? String,
                  let url = URL(string: urlString),
                  let likes = document.data()["likes"] as? Int,
                  let saves = document.data()["saves"] as? Int,
                  let uploaderId = document.data()["uploaderId"] as? String,
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
            let title = document.data()["title"] as? String ?? ""
            let detectedLevel = document.data()["detected_level"] as? Int ?? 2
            return Video(id: document.documentID, url: url, captions: captions, title: title, detectedLevel: detectedLevel, uploaderId: uploaderId, likes: likes, saves: saves, language: langCode)
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
                    let likes = document.data()["likes"],
                    let saves = document.data()["saves"],
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
                
                let uploaderId = document.data()["uploaderId"] as? String ?? ""
                let title = document.data()["title"] as? String ?? ""
                
                return Video(id: document.documentID, url: url, captions: captions, title: title, detectedLevel: detectedLevel, uploaderId: uploaderId, likes: likes as! Int, saves: saves as! Int, language: langCode)
            }
            return allVideosAtLevel
        } else {
            print("Returning \(finalVideos.count) videos to user")
        }
        return finalVideos
    }
    
    func fetchVideoById(videoId: String, user: User, selectedLanguage: String) async throws -> Video? {
        let langCode = selectedLanguage.lowercased()
        let docRef = db.collection(videosCollection)
                        .document(langCode)
                        .collection("items")
                        .document(videoId)

        let docSnapshot = try await docRef.getDocument()
        guard let data = docSnapshot.data() else {
            print("No document found for videoId \(videoId) in language: \(selectedLanguage)")
            return nil
        }

        // Check if user has watched this video (optional, based on your filtering logic)
        if user.watchedVideos?.contains(videoId) == true {
            print("User has already watched video \(videoId)")
            // Optionally return nil or continue based on your needs
        }

        guard
            let urlString = data["video_url"] as? String,
            let url = URL(string: urlString),
            let likes = data["likes"] as? Int,
            let saves = data["saves"] as? Int,
            let uploaderId = data["uploaderId"] as? String,
            let captionDicts = data["captions"] as? [[String: Any]]
        else {
            print("Malformed video data for videoId \(videoId)")
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

        let detectedLevel = data["detected_level"] as? Int ?? 2
        
        let title = data["title"] as? String ?? ""
        return Video(id: videoId, url: url, captions: captions, title: title, detectedLevel: detectedLevel, uploaderId: uploaderId, likes: likes, saves: saves, language: langCode)
    }




}

