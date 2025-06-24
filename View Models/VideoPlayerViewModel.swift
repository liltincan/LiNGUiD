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
    @Published var isSavingWord: Bool = false
    @Published var wordSaved: Bool = false
    @Published var word: String?

    
    func saveUnknownWord(to userId: String, targetLanguage: String, savedWord:String, languagesData: [String: LanguagesData]) {
        isSavingWord = true
        word = savedWord
        wordSaved = false

        firestoreService.addUnknownWord(
            forUserId: userId,
            targetLanguage: targetLanguage,
            languagesData: languagesData
        ) { result in
            DispatchQueue.main.async {
                self.isSavingWord = false
                switch result {
                case .success:
                    self.wordSaved = true

                    // Auto-hide message after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.wordSaved = false
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }




    
    func toggleLike(for videoId: String, userId: String, currentLikes: [String], language: String?) {
        var updatedLikes = currentLikes
        let isLiking = !currentLikes.contains(videoId)

        if currentLikes.contains(videoId) {
            updatedLikes.removeAll { $0 == videoId }
        } else {
            updatedLikes.append(videoId)
        }

        firestoreService.updateLikedVideos(forUserId: userId, likedVideos: updatedLikes) { result in
            switch result {
            case .success:
                // Record engagement event for likes - Gerardo
                if isLiking {
                    Task {
                        await self.recordEngagementEvent(
                            videoId: videoId,
                            userID: userId,
                            eventType: "like",
                            language: language
                        )
                    }
                }
                break
            case .failure(let error):
                print("🔍 Like update failed: \(error)")
                self.errorMessage = error.localizedDescription
            }
        }
    }

    
    func toggleSave(for videoId: String, userId: String, currentSaves: [String], language: String?) {
        var updatedSaves = currentSaves
        let isSaving = !currentSaves.contains(videoId)
        
        if currentSaves.contains(videoId) {
            updatedSaves.removeAll { $0 == videoId }
        } else {
            updatedSaves.append(videoId)
        }

        firestoreService.updateSavedVideos(forUserId: userId, savedVideos: updatedSaves) { result in
            switch result {
            case .success:
                // Record engagement event for saves - Gerardo
                if isSaving {
                    Task {
                        await self.recordEngagementEvent(
                            videoId: videoId,
                            userID: userId,
                            eventType: "save",
                            language: language
                        )
                    }
                }
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

    /// Function to record a video being shared
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-15
    func recordShare(for videoId: String, userId: String, language: String?) async {
        await recordEngagementEvent(
            videoId: videoId,
            userID: userId,
            eventType: "share",
            language: language
        )
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
        } catch {
            print("Failed to record watch session: \(error)")
        }
    }

    /// Function to record engagement events (likes, shares, comments)
    /// - Author: Gerardo De La Torre
    /// - Date: 2025-06-15
    func recordEngagementEvent(videoId: String, userID: String, eventType: String, language: String?) async {
        let db = Firestore.firestore()

        do {
            let eventData: [String: Any] = [
                "userId": userID,
                "videoId": videoId,
                "eventType": eventType,
                "timestamp": FieldValue.serverTimestamp(),
                "language": language ?? "unkown"
            ]

            try await db.collection("engagement_events").addDocument(data: eventData)
        } catch {
            print("Failed to record engagement events: \(error)")
        }
    }
}
