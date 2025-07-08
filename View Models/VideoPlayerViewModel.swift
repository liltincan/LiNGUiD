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
    
    func toggleLike(for videoId: String, userId: String, currentLikes: [String], language: String?, completion: @escaping (Bool) -> Void) {
        var updatedLikes = currentLikes
        let isLiking = !currentLikes.contains(videoId)

        if currentLikes.contains(videoId) {
            updatedLikes.removeAll { $0 == videoId }
        } else {
            updatedLikes.append(videoId)
        }

        firestoreService.updateLikedVideos(forUserId: userId, likedVideos: updatedLikes) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(isLiking) // Return the new state
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
                case .failure(let error):
                    print("🔍 Like update failed: \(error)")
                    self.errorMessage = error.localizedDescription
                    completion(!isLiking) // Revert state on failure
                }
            }
        }
    }

    func toggleSave(for videoId: String, userId: String, currentSaves: [String], language: String?, completion: @escaping (Bool) -> Void) {
        var updatedSaves = currentSaves
        let isSaving = !currentSaves.contains(videoId)
        
        if currentSaves.contains(videoId) {
            updatedSaves.removeAll { $0 == videoId }
        } else {
            updatedSaves.append(videoId)
        }

        firestoreService.updateSavedVideos(forUserId: userId, savedVideos: updatedSaves) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(isSaving) // Return the new state
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
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(!isSaving) // Revert state on failure
                }
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

    /// Function to record watch sessions and update user watch time statistics
    /// - Author: Gerardo De La Torre.
    /// - Date: 2025-06-15
    /// - Updated: 2025-01-08 - Added watch time aggregation 
    func recordWatchSession(videoId: String, userID: String, watchTime: TimeInterval, language: String?) async {
        let db = Firestore.firestore()
        let languageKey = (language ?? "unknown").lowercased()
        
        // Get current date string for daily tracking
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())

        do {
            // 1. Create a watch session document
            let sessionData: [String: Any] = [
                "userId": userID,
                "videoId": videoId,
                "watchTime": watchTime,
                "timestamp": FieldValue.serverTimestamp(),
                "language": language ?? "unknown"
            ]

            // Store in a watch_sessions collection
            try await db.collection("watch_sessions").addDocument(data: sessionData)
            
            // 2. Update user's aggregated watch time statistics
            let userRef = db.collection("users").document(userID)
            
            try await db.runTransaction { transaction, errorPointer in
                let userDocument: DocumentSnapshot
                do {
                    userDocument = try transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Get current global watch time
                let currentGlobalWatchTime = userDocument.data()?["globalWatchTime"] as? Double ?? 0
                let newGlobalWatchTime = currentGlobalWatchTime + watchTime
                
                // Get current languages data
                var languagesData = userDocument.data()?["languagesData"] as? [String: [String: Any]] ?? [:]
                
                // Initialize language data if it doesn't exist
                if languagesData[languageKey] == nil {
                    languagesData[languageKey] = [:]
                }
                
                // Get/initialize watch time data for this language
                var languageWatchTime = languagesData[languageKey]?["watchTime"] as? [String: Any] ?? [:]
                
                // Update total watch time for this language
                let currentLanguageTotal = languageWatchTime["total"] as? Double ?? 0
                languageWatchTime["total"] = currentLanguageTotal + watchTime
                
                // Update daily watch time for this language
                var dailyWatchTime = languageWatchTime["daily"] as? [String: Double] ?? [:]
                let currentDailyTime = dailyWatchTime[todayKey] ?? 0
                dailyWatchTime[todayKey] = currentDailyTime + watchTime
                languageWatchTime["daily"] = dailyWatchTime
                
                // Update the language data
                languagesData[languageKey]?["watchTime"] = languageWatchTime
                
                // Prepare update data
                let updateData: [String: Any] = [
                    "globalWatchTime": newGlobalWatchTime,
                    "languagesData": languagesData
                ]
                
                // Update the user document
                transaction.updateData(updateData, forDocument: userRef)
                
                print("🎯 Watch Time Aggregation - Added \(watchTime)s to user \(userID)")
                print("   - Global: \(currentGlobalWatchTime)s → \(newGlobalWatchTime)s")
                print("   - \(languageKey): \(currentLanguageTotal)s → \(currentLanguageTotal + watchTime)s")
                print("   - Daily (\(todayKey)): \(currentDailyTime)s → \(currentDailyTime + watchTime)s")
                
                return nil
            }
            
        } catch {
            print("Failed to record watch session or update user statistics: \(error)")
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
