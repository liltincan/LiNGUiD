//
//  FirestoreService.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/30/25.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class FirestoreService { //talks to Firebase so users are not doing it directly
    static let shared = FirestoreService() //singleton instance of FirebaseService to be used everywhere
    internal let db = Firestore.firestore() //database instance
    
    func updateNumberOfComments(videoId: String, language: String) async {
        let db = Firestore.firestore()
        do {
            let videoRef = db.collection("videos").document(language).collection("items").document(videoId)
            try await videoRef.updateData([
                "commentCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("Error updating comment count: \(error.localizedDescription)")
        }
    }
    func deleteVideo(videoId: String, uid: String, language: String) async {
        let db = Firestore.firestore()
        let videoPath = "\(language)/items/\(videoId)"
        
        do {
            // 1. Remove from user's uploadedVideos
            let userRef = db.collection("users").document(uid)
            let snapshot = try await userRef.getDocument()
            
            if let data = snapshot.data(),
               var uploadedVideos = data["uploadedVideos"] as? [String] {
                uploadedVideos.removeAll { $0 == videoPath }
                try await userRef.updateData(["uploadedVideos": uploadedVideos])
                print("✅ Removed video \(videoPath) from uploadedVideos.")
            } else {
                print("⚠️ No uploadedVideos found or data cast failed.")
            }
            
            // 2. Delete video document from Firestore
            let videoRef = db
                .collection("videos")
                .document(language)
                .collection("items")
                .document(videoId)
            
            try await videoRef.delete()
            print("✅ Firestore video document deleted.")
            
            // 3. Delete video file from Firebase Storage
            let storageRef = Storage.storage().reference(forURL: "gs://linguid-fe2b7.firebasestorage.app")
            let videoStorageRef = storageRef.child("videos/\(language)/\(videoId).MOV")
            try await videoStorageRef.delete()
            print("✅ Video deleted from storage.")
            
        } catch {
            print("❌ Error deleting video: \(error.localizedDescription)")
        }
    }


    func getUserProfilePicture(forUserId uid: String) async throws -> String? {
        let snapshot = try await db.collection("users").document(uid).getDocument()

        guard let data = snapshot.data() else {
            return nil
        }
        return data["profilePhotoUrl"] as? String
    }
    
    func getUserCountry(forUserId uid: String) async throws -> String? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        
        guard let data = snapshot.data() else {
            return nil
        }
        return data["country"] as? String
    }
    
    func getCurrentUser(completion: @escaping (Result<User, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { //makes sure user exists
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error { //fails if corresponding document does not exist
                completion(.failure(error))
                return
            }
            
            if let user = try? snapshot?.data(as: User.self) {
                completion(.success(user)) //The user is returned with the success value
            } else {
                completion(.failure(NSError(domain: "", code: -1)))
            }
        }
    }
    
    func addUnknownWord(forUserId uid: String, targetLanguage: String, languagesData: [String: LanguagesData], completion: @escaping (Result<Void, Error>) -> Void) {
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

    func updateLikedVideos(forUserId uid: String, likedVideos: [String], likedVideoId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Update user's liked videos list
        db.collection("users").document(uid).updateData(["likedVideos": likedVideos]) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Update the video's like count
            let path = likedVideoId.split(separator: "/")
            guard path.count == 3 else {
                completion(.failure(NSError(domain: "InvalidVideoId", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video ID format"])))
                return
            }
            
            let incrementValue = likedVideos.contains(likedVideoId) ? 1 : -1
            
            self?.db.collection("videos")
                .document(String(path[0]))
                .collection(String(path[1]))
                .document(String(path[2]))
                .updateData(["likes": FieldValue.increment(Int64(incrementValue))]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
    }
    
    func updateSavedVideos(forUserId uid: String, savedVideos: [String], savedVideoId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Update user's saved videos list
        db.collection("users").document(uid).updateData(["savedVideos": savedVideos]) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // Update the video's save count
            let path = savedVideoId.split(separator: "/")
            guard path.count == 3 else {
                completion(.failure(NSError(domain: "InvalidVideoId", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video ID format"])))
                return
            }

            let incrementValue = savedVideos.contains(savedVideoId) ? 1 : -1

            self?.db.collection("videos")
                .document(String(path[0]))
                .collection(String(path[1]))
                .document(String(path[2]))
                .updateData(["saves": FieldValue.increment(Int64(incrementValue))]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
    }

    
    func getVideoURL(for videoId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        db.collection("videos").document(videoId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(),
                  let urlString = data["url"] as? String,
                  let url = URL(string: urlString) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL data"])))
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
            "Afrikaans": "af", "Arabic": "ar", "Armenian": "hy", "Azerbaijani": "az", "Belarusian": "be",
            "Bosnian": "bs", "Bulgarian": "bg", "Catalan": "ca", "Chinese": "zh", "Croatian": "hr",
            "Czech": "cs", "Danish": "da", "Dutch": "nl", "English": "en", "Estonian": "et",
            "Finnish": "fi", "French": "fr", "Galician": "gl", "German": "de", "Greek": "el",
            "Hebrew": "he", "Hindi": "hi", "Hungarian": "hu", "Icelandic": "is", "Indonesian": "id",
            "Italian": "it", "Japanese": "ja", "Kannada": "kn", "Kazakh": "kk", "Korean": "ko",
            "Latvian": "lv", "Lithuanian": "lt", "Macedonian": "mk", "Malay": "ms", "Maori": "mi",
            "Marathi": "mr", "Nepali": "ne", "Norwegian": "no", "Persian": "fa", "Polish": "pl",
            "Portuguese": "pt", "Romanian": "ro", "Russian": "ru", "Serbian": "sr", "Slovak": "sk",
            "Slovenian": "sl", "Spanish": "es", "Swahili": "sw", "Swedish": "sv", "Tagalog": "tl",
            "Tamil": "ta", "Thai": "th", "Turkish": "tr", "Ukrainian": "uk", "Urdu": "ur",
            "Vietnamese": "vi", "Welsh": "cy"
        ]

        let levelMapping: [String: Int] = [
            "Just Starting": 1,
            "Beginner": 2,
            "Intermediate": 3,
            "Advanced": 4,
            "Expert": 5
        ]

        // 1. First native language code
        let firstNative = nativeLanguages.first.flatMap { languageCodes[$0.capitalized] } ?? ""
        // 2. First target language code
        let firstTarget = targetLanguages.first.flatMap { languageCodes[$0] } ?? ""

        // 3. Native language list (converted to codes)
        let nativeLanguageList = nativeLanguages.compactMap { languageCodes[$0] }

        // 4. Build languagesData dictionary
        var languagesData: [String: LanguagesData] = [:]
        for language in targetLanguages {
            //print("⚠️ Not Skipping \(language) \(languageLevels[language]): Missing code or level")
            guard
                let code = languageCodes[language],
                let levelStr = languageLevels[language],
                let level = levelMapping[levelStr]
                
            else {
                //print("⚠️ Skipping \(language) \(languageLevels[language]): Missing code or level")
                continue
            }

            languagesData[code] = LanguagesData(comprehensionLevel: level, timestamp: Date())
        }

        // 5. Encode to Firestore format
        do {
            var encodedLanguagesData: [String: [String: Any]] = [:]
            for (code, data) in languagesData {
                encodedLanguagesData[code] = try Firestore.Encoder().encode(data)
            }

            let dataToSave: [String: Any] = [
                "nativeLanguage": firstNative,
                "targetLanguage": firstTarget,
                "nativeLanguageList": nativeLanguageList,
                "languagesData": encodedLanguagesData
            ]

            db.collection("users").document(uid).updateData(dataToSave) { error in
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
    
    func updateUserCountry(
        country: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }

        let userRef = db.collection("users").document(userId)

        // Use updateData to add/modify only the 'country' field
        userRef.updateData(["country": country]) { error in
            if let error = error {
                print("Error updating country for user \(userId): \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Country '\(country)' successfully added/updated for user \(userId).")
                completion(.success(()))
            }
        }
    }
    
    func updateUsername(username: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
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
    func getOnboardingStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "NoUID", code: -1)))
            return
        }
        
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let status = snapshot?.data()?["didCompleteOnboarding"] as? Bool ?? false
            completion(.success(status))
        }
    }

    func setOnboardingStatus(completed: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
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
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.noUser }
        try await db.collection("users").document(uid).updateData([
            "didCompleteOnboarding": completed
        ])
    }
    
    func getOnboardingStatus() async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.noUser }
        let doc = try await db.collection("users").document(uid).getDocument()
        return doc.data()?["didCompleteOnboarding"] as? Bool ?? false
    }
    
    enum AuthError: Error {
        case noUser
    }
}



