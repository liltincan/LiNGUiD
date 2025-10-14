//
//  FirestoreService.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/30/25.
//

import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class FirestoreService {  //talks to Firebase so users are not doing it directly
    static let shared = FirestoreService()  //singleton instance of FirebaseService to be used everywhere
    internal let db = Firestore.firestore()  //database instance

    func updateNumberOfComments(videoId: String, language: String) async {
        let db = Firestore.firestore()
        do {
            let videoRef = db.collection("videos").document(language)
                .collection("items").document(videoId)
            try await videoRef.updateData([
                "commentCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("Error updating comment count: \(error.localizedDescription)")
        }
    }
    
    func deleteVideo(videoId: String, uid: String, language: String) async {
        let db = Firestore.firestore()
        
        do {
            // 1. Get video document path that's stored in users' liked/saved arrays
            let videoRef = db.collection("videos").document(language).collection("items").document(videoId)
            let videoPath = "\(language)/items/\(videoId)"
            
            // 2. Query all users who have liked or saved this video
            let usersWithVideoLiked = try await db.collection("users")
                .whereField("likedVideos", arrayContains: videoPath)
                .getDocuments()
            
            let usersWithVideoSaved = try await db.collection("users")
                .whereField("savedVideos", arrayContains: videoPath)
                .getDocuments()
            
            // 3. Remove video from liked videos
            for userDoc in usersWithVideoLiked.documents {
                if var likedVideos = userDoc.data()["likedVideos"] as? [String] {
                    likedVideos.removeAll { $0 == videoPath }
                    try await db.collection("users").document(userDoc.documentID).updateData([
                        "likedVideos": likedVideos
                    ])
                    print("✅ Removed from liked videos for user: \(userDoc.documentID)")
                }
            }
            
            // 4. Remove video from saved videos
            for userDoc in usersWithVideoSaved.documents {
                if var savedVideos = userDoc.data()["savedVideos"] as? [String] {
                    savedVideos.removeAll { $0 == videoPath }
                    try await db.collection("users").document(userDoc.documentID).updateData([
                        "savedVideos": savedVideos
                    ])
                    print("✅ Removed from saved videos for user: \(userDoc.documentID)")
                }
            }
            
            // 5. Remove from uploader's uploadedVideos
            let uploaderRef = db.collection("users").document(uid)
            let uploaderSnapshot = try await uploaderRef.getDocument()
            
            if let data = uploaderSnapshot.data(),
               var uploadedVideos = data["uploadedVideos"] as? [String] {
                uploadedVideos.removeAll { $0 == videoPath }
                try await uploaderRef.updateData(["uploadedVideos": uploadedVideos])
                print("✅ Removed video \(videoPath) from uploadedVideos.")
            }
            
            // 6. Delete video document from Firestore
            try await videoRef.delete()
            print("✅ Firestore video document deleted.")
            
            // 7. Delete video file from Firebase Storage - improved approach
            let storageRef = Storage.storage().reference(forURL: "gs://linguid-fe2b7.firebasestorage.app")
            let videoFolderRef = storageRef.child("videos/\(language)")
            
            // List all files in the video folder to find the actual file
            do {
                let listResult = try await videoFolderRef.listAll()
                var videoDeleted = false
                
                for item in listResult.items {
                    let itemName = item.name
                    // Check if the file name matches our video ID (without extension)
                    let nameWithoutExtension = (itemName as NSString).deletingPathExtension
                    if nameWithoutExtension == videoId {
                        try await item.delete()
                        print("✅ Video deleted from storage: \(itemName)")
                        videoDeleted = true
                        break
                    }
                }
                
                if !videoDeleted {
                    print("⚠️ Video file not found in storage for videoId: \(videoId)")
                }
                
            } catch {
                print("❌ Error listing/deleting video files: \(error.localizedDescription)")
                
                // Fallback to the original approach if listing fails
                let possibleExtensions = ["MOV", "mov", "mp4"]
                for ext in possibleExtensions {
                    do {
                        let videoStorageRef = storageRef.child("videos/\(language)/\(videoId).\(ext)")
                        try await videoStorageRef.delete()
                        print("✅ Video deleted from storage: \(videoId).\(ext)")
                        break // Exit loop once we successfully delete one
                    } catch {
                        // Continue to next extension if this one fails
                        continue
                    }
                }
            }
            
            // 8. Delete all thumbnail files
            let thumbnailDirRef = storageRef.child("thumbnails/\(uid)/\(videoId)")
            
            do {
                let listResult = try await thumbnailDirRef.listAll()

                if listResult.items.isEmpty {
                    print("⚠️ No thumbnails found for \(videoId)")
                } else {
                    for item in listResult.items {
                        try await item.delete()
                        print("✅ Deleted thumbnail: \(item.name)")
                    }
                    print("✅ All thumbnails deleted from thumbnails/\(uid)/\(videoId)")
                }
            } catch {
                print("❌ Error deleting thumbnails: \(error.localizedDescription)")
            }

        } catch {
            print("❌ Error deleting video: \(error.localizedDescription)")
        }
    }
    
    /// Deletes all user data including videos, thumbnails, profile picture, and Firestore document
    func deleteAllUserData() async throws {
        guard let user = Auth.auth().currentUser else {
            throw UserDataDeletionError.notAuthenticated
        }
        
        let uid = user.uid
        print("Starting complete user data deletion for user: \(uid)")
        
        // 1. Get user document to retrieve uploaded videos
        let userDoc = try await db.collection("users").document(uid).getDocument()
        guard let userData = userDoc.data() else {
            throw UserDataDeletionError.userDataNotFound
        }
        
        // 2. Delete all uploaded videos and their thumbnails
        if let uploadedVideos = userData["uploadedVideos"] as? [String] {
            print("Found \(uploadedVideos.count) uploaded videos to delete")
            
            for videoPath in uploadedVideos {
                let pathComponents = videoPath.split(separator: "/")
                if pathComponents.count == 3 {
                    let language = String(pathComponents[0])
                    let videoId = String(pathComponents[2])
                    
                    do {
                        await deleteVideo(videoId: videoId, uid: uid, language: language)
                        print("✅ Deleted video: \(videoPath)")
                    } catch {
                        print("❌ Error deleting video \(videoPath): \(error.localizedDescription)")
                        // Continue with other videos even if one fails
                    }
                }
            }
        }
        
        // 3. Delete profile picture from Storage
        await deleteProfilePicture(uid: uid)
        
        // 4. Remove user from other users' liked/saved videos (if any remain)
        try await removeUserFromAllVideoInteractions(uid: uid)
        
        // 5. Delete user's Firestore document
        try await db.collection("users").document(uid).delete()
        print("✅ User Firestore document deleted")
        
        // 6. Delete Firebase Auth user via cloud function
        try await deleteUserAuthViaCloudFunction(uid: uid)
        print("✅ Firebase Auth user deleted via cloud function")
        
        print("✅ Complete user data deletion completed successfully")
    }
    
    /// Deletes the user's profile picture from Storage
    private func deleteProfilePicture(uid: String) async {
        let storageRef = Storage.storage().reference()
        let profileImagesRef = storageRef.child("profile_photos/\(uid)/profile.jpg")
        
        do {
            try await profileImagesRef.delete()
            print("✅ Profile picture deleted from Storage")
        } catch StorageErrorCode.objectNotFound {
            print("ℹ️ Profile picture not found in Storage (may not have been set)")
        } catch {
            print("❌ Error deleting profile picture: \(error.localizedDescription)")
        }
    }
    
    /// Removes user references from any remaining video interactions
    private func removeUserFromAllVideoInteractions(uid: String) async throws {
        // Query for any users who might still have this user's videos in their liked/saved arrays
        // This is a safety measure in case some references weren't cleaned up during video deletion
        
        let allUsersSnapshot = try await db.collection("users").getDocuments()
        
        for userDoc in allUsersSnapshot.documents {
            var needsUpdate = false
            var updateData: [String: Any] = [:]
            
            // Check liked videos
            if let likedVideos = userDoc.data()["likedVideos"] as? [String] {
                let filteredLiked = likedVideos.filter { videoPath in
                    // Remove any video paths that might reference deleted videos
                    let pathComponents = videoPath.split(separator: "/")
                    if pathComponents.count == 3 {
                        let videoId = String(pathComponents[2])
                        // This is a basic check - in a more sophisticated system,
                        // you might want to verify if the video actually exists
                        return !videoId.isEmpty
                    }
                    return true
                }
                
                if filteredLiked.count != likedVideos.count {
                    updateData["likedVideos"] = filteredLiked
                    needsUpdate = true
                }
            }
            
            // Check saved videos
            if let savedVideos = userDoc.data()["savedVideos"] as? [String] {
                let filteredSaved = savedVideos.filter { videoPath in
                    let pathComponents = videoPath.split(separator: "/")
                    if pathComponents.count == 3 {
                        let videoId = String(pathComponents[2])
                        return !videoId.isEmpty
                    }
                    return true
                }
                
                if filteredSaved.count != savedVideos.count {
                    updateData["savedVideos"] = filteredSaved
                    needsUpdate = true
                }
            }
            
            if needsUpdate {
                try await db.collection("users").document(userDoc.documentID).updateData(updateData)
                print("✅ Cleaned up video references for user: \(userDoc.documentID)")
            }
        }
    }
    
    /// Deletes Firebase Auth user via cloud function
    private func deleteUserAuthViaCloudFunction(uid: String) async throws {
        guard let url = URL(string: "https://us-central1-linguid-fe2b7.cloudfunctions.net/deleteUserAccount") else {
            throw UserDataDeletionError.invalidCloudFunctionURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["uid": uid]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UserDataDeletionError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                if let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = responseData["status"] as? String, status == "success" {
                    print("✅ Auth user deleted successfully via cloud function")
                    return
                }
            }
            
            // Handle error response
            if let errorData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw UserDataDeletionError.cloudFunctionError(errorMessage)
            }
            
            throw UserDataDeletionError.unknownCloudFunctionError
            
        } catch {
            print("Cloud function request error: \(error)")
            throw UserDataDeletionError.networkError(error.localizedDescription)
        }
    }

    func getUserProfilePicture(forUserId uid: String) async throws -> String? {
        let snapshot = try await db.collection("users").document(uid)
            .getDocument()

        guard let data = snapshot.data() else {
            return nil
        }
        return data["profilePhotoUrl"] as? String
    }

    func getUserCountry(forUserId uid: String) async throws -> String? {
        let snapshot = try await db.collection("users").document(uid)
            .getDocument()

        guard let data = snapshot.data() else {
            return nil
        }
        return data["country"] as? String
    }

    func getCurrentUser(completion: @escaping (Result<User, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {  //makes sure user exists
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {  //fails if corresponding document does not exist
                completion(.failure(error))
                return
            }

            if let user = try? snapshot?.data(as: User.self) {
                completion(.success(user))  //The user is returned with the success value
            } else {
                completion(.failure(NSError(domain: "", code: -1)))
            }
        }
    }

    func addUnknownWord(
        forUserId uid: String,
        targetLanguage: String,
        languagesData: [String: LanguagesData],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            let encoded = try Firestore.Encoder().encode(languagesData)
            db.collection("users").document(uid).updateData([
                "languagesData": encoded
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func updateLikedVideos(
        forUserId uid: String,
        likedVideos: [String],
        likedVideoId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let batch = db.batch()

        let userRef = db.collection("users").document(uid)
        let path = likedVideoId.split(separator: "/")
        guard path.count == 3 else {
            completion(.failure(NSError(domain: "InvalidVideoId", code: -1)))
            return
        }
        let videoRef = db.collection("videos").document(String(path[0])).collection(String(path[1])).document(String(path[2]))

        batch.updateData(["likedVideos": likedVideos], forDocument: userRef)

        let incrementValue = likedVideos.contains(likedVideoId) ? 1 : -1
        batch.updateData(["likes": FieldValue.increment(Int64(incrementValue))], forDocument: videoRef)

        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func updateSavedVideos(
        forUserId uid: String,
        savedVideos: [String],
        savedVideoId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Update user's saved videos list
        db.collection("users").document(uid).updateData([
            "savedVideos": savedVideos
        ]) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Update the video's save count
            let path = savedVideoId.split(separator: "/")
            guard path.count == 3 else {
                completion(
                    .failure(
                        NSError(
                            domain: "InvalidVideoId",
                            code: -1,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Invalid video ID format"
                            ]
                        )
                    )
                )
                return
            }

            let incrementValue = savedVideos.contains(savedVideoId) ? 1 : -1

            self?.db.collection("videos")
                .document(String(path[0]))
                .collection(String(path[1]))
                .document(String(path[2]))
                .updateData([
                    "saves": FieldValue.increment(Int64(incrementValue))
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
    }

    func getVideoURL(
        for videoId: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        db.collection("videos").document(videoId).getDocument {
            snapshot,
            error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(),
                let urlString = data["url"] as? String,
                let url = URL(string: urlString)
            else {
                completion(
                    .failure(
                        NSError(
                            domain: "",
                            code: -1,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Invalid URL data"
                            ]
                        )
                    )
                )
                return
            }

            completion(.success(url))
        }
    }

    func updateUserLanguagePreferences(
        nativeLanguages: Set<String>,
        targetLanguages: Set<String>,
        languageLevels: [String: String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "NoUID", code: -1)))
            return
        }

        let db = Firestore.firestore()

        let languageCodes: [String: String] = [
            "Afrikaans": "af", "Arabic": "ar", "Armenian": "hy",
            "Azerbaijani": "az", "Belarusian": "be",
            "Bosnian": "bs", "Bulgarian": "bg", "Catalan": "ca",
            "Chinese": "zh", "Croatian": "hr",
            "Czech": "cs", "Danish": "da", "Dutch": "nl", "English": "en",
            "Estonian": "et",
            "Finnish": "fi", "French": "fr", "Galician": "gl", "German": "de",
            "Greek": "el",
            "Hebrew": "he", "Hindi": "hi", "Hungarian": "hu", "Icelandic": "is",
            "Indonesian": "id",
            "Italian": "it", "Japanese": "ja", "Kannada": "kn", "Kazakh": "kk",
            "Korean": "ko",
            "Latvian": "lv", "Lithuanian": "lt", "Macedonian": "mk",
            "Malay": "ms", "Maori": "mi",
            "Marathi": "mr", "Nepali": "ne", "Norwegian": "no", "Persian": "fa",
            "Polish": "pl",
            "Portuguese": "pt", "Romanian": "ro", "Russian": "ru",
            "Serbian": "sr", "Slovak": "sk",
            "Slovenian": "sl", "Spanish": "es", "Swahili": "sw",
            "Swedish": "sv", "Tagalog": "tl",
            "Tamil": "ta", "Thai": "th", "Turkish": "tr", "Ukrainian": "uk",
            "Urdu": "ur",
            "Vietnamese": "vi", "Welsh": "cy",
        ]

        let levelMapping: [String: Int] = [
            "Just Starting": 1,
            "Beginner": 2,
            "Intermediate": 3,
            "Advanced": 4,
            "Expert": 5,
        ]

        let firstNative =
            nativeLanguages.first.flatMap { languageCodes[$0.capitalized] }
            ?? ""
        let firstTarget =
            targetLanguages.first.flatMap { languageCodes[$0] } ?? ""
        let nativeLanguageList = nativeLanguages.compactMap {
            languageCodes[$0]
        }
        let targetLanguageList = targetLanguages.compactMap {
            languageCodes[$0]
        }

        let userRef = db.collection("users").document(uid)

        userRef.getDocument(completion: { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Decode existing languagesData if it exists
            var existingData: [String: LanguagesData] = [:]
            if let raw = snapshot?.data()?["languagesData"]
                as? [String: [String: Any]]
            {
                for (code, value) in raw {
                    do {
                        let decoded = try Firestore.Decoder().decode(
                            LanguagesData.self,
                            from: value
                        )
                        existingData[code] = decoded
                    } catch {
                        print("⚠️ Failed to decode \(code): \(error)")
                    }
                }
            }

            // Merge new data

            for language in targetLanguages {
                guard
                    let code = languageCodes[language],
                    let levelStr = languageLevels[language],
                    let level = levelMapping[levelStr]
                else { continue }

                let existing = existingData[code]

                let updated = LanguagesData(
                    savedWords: existing?.savedWords,
                    comprehensionLevel: level,
                    dailyGoal: existing?.dailyGoal,
                    isBeginnerLevel: existing?.isBeginnerLevel,
                    motivation: existing?.motivation,
                    timestamp: Date(),
                    watchTime: existing?.watchTime
                )


                existingData[code] = updated
            }

            // Encode for Firestore
            var encodedLanguagesData: [String: [String: Any]] = [:]
            do {
                for (code, data) in existingData {
                    encodedLanguagesData[code] = try Firestore.Encoder().encode(
                        data
                    )
                }

                let dataToSave: [String: Any] = [
                    "nativeLanguage": firstNative,
                    "targetLanguage": firstTarget,
                    "nativeLanguageList": nativeLanguageList,
                    "targetLanguageList": targetLanguageList,
                    "languagesData": encodedLanguagesData,
                ]

                userRef.updateData(dataToSave) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        })
    }

    func updateUserCountry(
        country: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey: "User not logged in"
                        ]
                    )
                )
            )
            return
        }

        let userRef = db.collection("users").document(userId)

        // Use updateData to add/modify only the 'country' field
        userRef.updateData(["country": country]) { error in
            if let error = error {
                print(
                    "Error updating country for user \(userId): \(error.localizedDescription)"
                )
                completion(.failure(error))
            } else {
                print(
                    "Country '\(country)' successfully added/updated for user \(userId)."
                )
                completion(.success(()))
            }
        }
    }

    func updateUsername(
        username: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(
                .failure(
                    NSError(
                        domain: "auth",
                        code: 401,
                        userInfo: [
                            NSLocalizedDescriptionKey: "User not authenticated"
                        ]
                    )
                )
            )
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        userRef.updateData(["userName": username]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // In FirestoreService.swift
    func getOnboardingStatus(
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "NoUID", code: -1)))
            return
        }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let status =
                snapshot?.data()?["didCompleteOnboarding"] as? Bool ?? false
            completion(.success(status))
        }
    }

    func setOnboardingStatus(
        completed: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "NoUID", code: -1)))
            return
        }

        db.collection("users").document(uid).updateData([
            "didCompleteOnboarding": completed
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

extension FirestoreService {
    func updateOnboardingStatus(completed: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AuthError.noUser
        }
        try await db.collection("users").document(uid).updateData([
            "didCompleteOnboarding": completed
        ])
    }

    func getOnboardingStatus() async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AuthError.noUser
        }
        let doc = try await db.collection("users").document(uid).getDocument()
        return doc.data()?["didCompleteOnboarding"] as? Bool ?? false
    }

    enum AuthError: Error {
        case noUser
    }
}


extension FirestoreService {
    func addUnknownWordDelta(
        forUserId uid: String,
        targetLanguage: String,
        wordTarget: String,
        wordNative: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        func normalize(_ s: String) -> String {
            var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            t = t.trimmingCharacters(in: .punctuationCharacters)
            t = t.precomposedStringWithCompatibilityMapping
                 .folding(options: .diacriticInsensitive, locale: .current)
                 .lowercased()
            return t
        }

        db.runTransaction({ (txn, errorPointer) -> Any? in
            // 1) Read document (catch throws; DO NOT rethrow)
            let snap: DocumentSnapshot
            do {
                snap = try txn.getDocument(ref)
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }

            // 2) Extract arrays
            let root = snap.data() ?? [:]
            let languages = root["languagesData"] as? [String: Any] ?? [:]
            let langNode = languages[targetLanguage] as? [String: Any] ?? [:]
            let saved = langNode["savedWords"] as? [String: Any] ?? [:]

            var unknown = saved["unknownWords"] as? [[String: Any]] ?? []
            let known  = saved["knownWords"]  as? [[String: Any]] ?? []

            // 3) De-dupe across BOTH lists
            let key = normalize(wordTarget)
            let existsInUnknown = unknown.contains { normalize(($0["target"] as? String) ?? "") == key }
            let existsInKnown   = known.contains   { normalize(($0["target"] as? String) ?? "") == key }

            guard !existsInUnknown && !existsInKnown else {
                // Already saved somewhere; nothing to do
                return nil
            }

            // 4) Append and write back ONLY the branch we changed
            unknown.append(["target": wordTarget, "native": wordNative])

            txn.updateData(
                ["languagesData.\(targetLanguage).savedWords.unknownWords": unknown],
                forDocument: ref
            )
            return nil
        }, completion: { _, err in
            if let err = err { completion(.failure(err)) }
            else { completion(.success(())) }
        })
    }
}



// MARK: - Custom Error Types for User Data Deletion
enum UserDataDeletionError: LocalizedError {
    case notAuthenticated
    case userDataNotFound
    case partialDeletionFailure(String)
    case invalidCloudFunctionURL
    case invalidResponse
    case cloudFunctionError(String)
    case unknownCloudFunctionError
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .userDataNotFound:
            return "User data not found in Firestore"
        case .partialDeletionFailure(let message):
            return "Some data could not be deleted: \(message)"
        case .invalidCloudFunctionURL:
            return "Invalid cloud function URL"
        case .invalidResponse:
            return "Invalid response from cloud function"
        case .cloudFunctionError(let message):
            return "Cloud function error: \(message)"
        case .unknownCloudFunctionError:
            return "Unknown cloud function error"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
