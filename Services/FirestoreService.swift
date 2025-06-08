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

    
    
}


