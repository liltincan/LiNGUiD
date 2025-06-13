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
            "Arabic": "Ar", "Chinese": "Zh", "English": "En", "French": "Fr", "German": "De",
            "Italian": "It", "Portuguese": "Pt", "Russian": "Ru", "Spanish": "Es",
            "Afrikaans": "Af", "Armenian": "Hy", "Azerbaijani": "Az", "Belarusian": "Be",
            "Bosnian": "Bs", "Bulgarian": "Bg", "Catalan": "Ca", "Croatian": "Hr", "Czech": "Cs",
            "Danish": "Da", "Dutch": "Nl", "Estonian": "Et", "Finnish": "Fi", "Galician": "Gl",
            "Greek": "El", "Hebrew": "He", "Hindi": "Hi", "Hungarian": "Hu", "Icelandic": "Is",
            "Indonesian": "Id", "Japanese": "Ja", "Kannada": "Kn", "Kazakh": "Kk", "Korean": "Ko",
            "Latvian": "Lv", "Lithuanian": "Lt", "Macedonian": "Mk", "Malay": "Ms", "Maori": "Mi",
            "Marathi": "Mr", "Nepali": "Ne", "Norwegian": "No", "Persian": "Fa", "Polish": "Pl",
            "Romanian": "Ro", "Serbian": "Sr", "Slovak": "Sk", "Slovenian": "Sl", "Swahili": "Sw",
            "Swedish": "Sv", "Tagalog": "Tl", "Tamil": "Ta", "Thai": "Th", "Turkish": "Tr",
            "Ukrainian": "Uk", "Urdu": "Ur", "Vietnamese": "Vi", "Welsh": "Cy"
        ]
        
        let nativeCodes = nativeLanguages.compactMap { languageCodes[$0] }
        let firstNative = nativeCodes.first ?? ""
        
        
        let levelMapping: [String: Int] = [
            "Just Starting": 1,
            "Beginner": 2,
            "Intermediate": 3,
            "Advanced": 4,
            "Fluent": 5
        ]
        
        var languagesData: [String: LanguagesData] = [:]
        for target in targetLanguages {
            guard let code = languageCodes[target],
                  let levelStr = languageLevels[target],
                  let level = levelMapping[levelStr] else {
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


