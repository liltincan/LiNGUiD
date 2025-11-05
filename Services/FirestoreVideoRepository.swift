import FirebaseFirestore

final class FirestoreVideoRepository: VideoRepository {
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    
    func fetchVideos(afterID: String?, limit: Int, user: User, selectedLanguages: [String]) async throws -> [Video] {
        var allVideos: [Video] = []

        for lang in selectedLanguages {
            let langCode = lang.lowercased()
            let userLevel = user.languagesData?[langCode]?.comprehensionLevel ?? 2

            var query = db.collection(videosCollection)
                .document(langCode)
                .collection("items")
                .order(by: FieldPath.documentID())
            if let afterID = afterID {
                query = query.start(after: [afterID])
            }
            query = query.limit(to: limit * 10) // Fetch more to allow for engagement sorting after filtering
            let snapshot = try await query.getDocuments()

            let unwatchedDocuments = snapshot.documents.filter { document in
                !(user.watchedVideos?.contains(document.documentID) ?? false)
            }

            let videos: [Video] = unwatchedDocuments.compactMap { document in
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

                let detectedLevel = document.data()["detected_level"] as? Int ?? 2
                let title = document.data()["title"] as? String ?? ""
                let commentCount = document.data()["commentCount"] as? Int ?? 0
                let shares = document.data()["shares"] as? Int ?? 0

                return Video(
                    id: document.documentID,
                    url: url,
                    captions: captions,
                    title: title,
                    detectedLevel: detectedLevel,
                    uploaderId: uploaderId,
                    likes: likes,
                    saves: saves,
                    commentCount: commentCount,
                    shares: shares,
                    language: langCode
                )
            }

            let filtered = videos.filter {
                $0.detectedLevel >= (userLevel - 1) && $0.detectedLevel <= (userLevel + 1)
            }

            allVideos.append(contentsOf: filtered)
        }

        // Sort by engagement score: likes + saves + comments + shares, descending
        let sortedVideos = allVideos.sorted { (video1, video2) -> Bool in
            let score1 = video1.likes + video1.saves + video1.commentCount + video1.shares
            let score2 = video2.likes + video2.saves + video2.commentCount + video2.shares
            return score1 > score2
        }

        return Array(sortedVideos.prefix(limit))
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
        let commentCount = data["commentCount"] as? Int ?? 0
        let shares = data["shares"] as? Int ?? 0
        let title = data["title"] as? String ?? ""
        return Video(id: videoId, url: url, captions: captions, title: title, detectedLevel: detectedLevel, uploaderId: uploaderId, likes: likes, saves: saves, commentCount: commentCount, shares: shares, language: langCode)
    }




}

