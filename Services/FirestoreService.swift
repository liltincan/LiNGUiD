//
//  FirestoreService.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/30/25.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth

class FirestoreService { //talks to Firebase so users are not doing it directly
    static let shared = FirestoreService() //singleton instance of FirebaseService to be used everywhere
    internal let db = Firestore.firestore() //database instance
    
    
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
    
    func updateLikedVideos(forUserId uid: String, likedVideos: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).updateData(["likedVideos": likedVideos])
    }
    
    func updateSavedVideos(forUserId uid: String, savedVideos: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).updateData(["savedVideos": savedVideos])
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
        
        let languageCodes: [String: String] = [
            "Arabic": "ar", "Chinese": "zh", "English": "en", "French": "fr", "German": "de",
            "Italian": "it", "Portuguese": "pt", "Russian": "ru", "Spanish": "es",
            "Afrikaans": "af", "Armenian": "hy", "Azerbaijani": "az", "Belarusian": "be",
            "Bosnian": "bs", "Bulgarian": "bg", "Catalan": "ca", "Croatian": "hr", "Czech": "cs",
            "Danish": "da", "Dutch": "nl", "Estonian": "et", "Finnish": "fi", "Galician": "gl",
            "Greek": "el", "Hebrew": "he", "Hindi": "hi", "Hungarian": "hu", "Icelandic": "is",
            "Indonesian": "id", "Japanese": "ja", "Kannada": "kn", "Kazakh": "kk", "Korean": "ko",
            "Latvian": "lv", "Lithuanian": "lt", "Macedonian": "mk", "Malay": "ms", "Maori": "mi",
            "Marathi": "mr", "Nepali": "ne", "Norwegian": "no", "Persian": "fa", "Polish": "pl",
            "Romanian": "ro", "Serbian": "sr", "Slovak": "sk", "Slovenian": "sl", "Swahili": "sw",
            "Swedish": "sv", "Tagalog": "tl", "Tamil": "ta", "Thai": "th", "Turkish": "tr",
            "Ukrainian": "uk", "Urdu": "ur", "Vietnamese": "vi", "Welsh": "cy"
        ]
        
        let nativeCodes = nativeLanguages.compactMap { languageCodes[$0] }
        let firstNative = nativeCodes.first ?? ""
        
        let targetCodes = targetLanguages.compactMap{ languageCodes[$0] }
        let targetLanguage = targetCodes.first ?? ""

        var languagesData: [String: LanguagesData] = [:]
        for target in targetLanguages {
            guard let code = languageCodes[target],
                  let levelStr = languageLevels[target],
                  let level = Int(levelStr) else {
                continue
            }

            languagesData[code] = LanguagesData(comprehensionLevel: level, timestamp: Date())
        }

        do {
            var encodedLanguagesData: [String: [String: Any]] = [:]
            for (code, data) in languagesData {
                let encodedData = try Firestore.Encoder().encode(data)
                encodedLanguagesData[code] = encodedData
            }

            let data: [String: Any] = [
                "nativeLanguage": firstNative,
                "nativeLanguageList": nativeCodes,
                "languagesData": encodedLanguagesData
            ]

            db.collection("users").document(uid).updateData(data) { error in
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
    
}


