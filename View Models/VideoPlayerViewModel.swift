//
//  VideoPlayerViewModel.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 6/1/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class VideoPlayerViewModel: ObservableObject {
    private let firestoreService = FirestoreService.shared
    @Published var errorMessage: String?

    
    func toggleLike(for videoId: String, userId: String, currentLikes: [String]) {
        var updatedLikes = currentLikes
        if currentLikes.contains(videoId) {
            updatedLikes.removeAll { $0 == videoId }
        } else {
            updatedLikes.append(videoId)
        }

        firestoreService.updateLikedVideos(forUserId: userId, likedVideos: updatedLikes) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    
    func toggleSave(for videoId: String, userId: String, currentSaves: [String]) {
        var updatedSaves = currentSaves
        if currentSaves.contains(videoId) {
            updatedSaves.removeAll { $0 == videoId }
        } else {
            updatedSaves.append(videoId)
        }

        firestoreService.updateSavedVideos(forUserId: userId, savedVideos: updatedSaves) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Function to mark fetched videos as watched
    /// - Author: Gerardo De La Torre. 
    /// - Date: 2025-06-06
    func markVideoAsWatched(_ videoID: String, userID: String) async {
        let db = Firestore.firestore()
        
        do {
            try await db.collection("users").document(userID).updateData([
                "watchedVideos": FieldValue.arrayUnion([videoID])
            ])
        } catch {
            print("Failed to mark video as watched: \(error)")
        }
    }

    /// Function to record watch sessions 
    /// - Author: Gerardo De La Torre.
    /// - Date: 2025-06-15
    func recordWatchSession(videoId: String, userID: String, watchTime: TimeInterval, language: String?) async {
        let db = Firestore.firestore()

        do {
            // Create a watch session document
            let sessionData: [String: Any] = [
                "userId": userID,
                "videoId": videoId,
                "watchTime": watchTime,
                "timestamp": FieldValue.serverTimestamp(),
                "language": language ?? "unknown"
            ]

            // Store in a watch_sessions collection
            try await db.collection("watch_sessions").addDocument(data: sessionData)

            print("Recorded watch time session: \(watchTime) seconds for video \(videoId)")
        } catch {
            print("Failed to record watch session: \(error)")
        }
    }
}
