//
//  OtherUserProfileViewModel.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 7/10/25.
//

// MARK: - Other User Profile ViewModel
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var dataReady: Bool = false
    @Published var errorMessage: String?
    @Published var videoThumbnails: [String] = []
    @Published var videoURLs: [String] = []
    @Published var isFollowing: Bool = false
    @Published var nativeLanguage: String? = nil
    @Published var country: String? = nil
    @Published var isPro: Bool = false
    
    // New: Store complete Video objects
    @Published var uploadedVideoArray: [Video] = []
    
    private let db = Firestore.firestore()
    private let userId: String
    private let videosCollection = "videos"
    
    init(userId: String) {
        self.userId = userId
    }
    
    //checking pro status
    var isProUser: Bool {
        return isPro
    }

    // MARK: - Computed Properties
    var userName: String {
        return user?.userName ?? ""
    }
    
    var primaryLanguage: String {
        guard let languagesData = user?.languagesData,
              let firstLanguageName = languagesData.keys.first else {
            return ""
        }
        return String(firstLanguageName.prefix(2))
    }
    
    var comprehensionLevel: String {
        guard let languagesData = user?.languagesData,
              let firstLanguageName = languagesData.keys.first,
              let langData = languagesData[firstLanguageName],
              let level = langData.comprehensionLevel else {
            return ""
        }
        return String(level)
    }
    
    var videoCount: String {
        return String(user?.uploadedVideos?.count ?? 0)
    }
    
    var inputAmount: String {
        let totalSeconds = user?.globalWatchTime ?? 0
        let totalMinutes = Int(totalSeconds / 60)  // Convert seconds to minutes
        return String(totalMinutes)
    }
    
    var followerCount: String {
        return String(user?.followers?.count ?? 0)
    }
    
    var profilePictureURL: String {
        return user?.profilePhotoUrl ?? ""
    }
    
    var nativeLanguageDisplay: String {
        return user?.nativeLanguage?.capitalized ?? ""
    }
    
    var formattedLanguagesDisplay: String {
        if let languagesData = user?.languagesData {
            let nativeLanguage: String = user?.nativeLanguage?.capitalized ?? ""
            let targetLanguage: String = user?.targetLanguage.capitalized ?? languagesData.keys.first?.capitalized ?? ""
            let comprehensionLevel: Int = languagesData[targetLanguage.lowercased()]?.comprehensionLevel ?? 0
            
            // If we didn't find the level for target language, try the first available language
            if comprehensionLevel == 0, let firstLanguageKey = languagesData.keys.first {
                let fallbackLevel = languagesData[firstLanguageKey]?.comprehensionLevel ?? 0
                return "\(nativeLanguage) → \(targetLanguage) (Lvl.\(fallbackLevel))"
            }
            
            return "\(nativeLanguage) → \(targetLanguage) (Lvl.\(comprehensionLevel))"
        }
        
        return ""
    }
    
    //fetching target language
    var targetLanguageList: [String] {
        user?.targetLanguageList ?? []
    }

    // MARK: - Data Fetching
    func fetchUserData(userSession: UserSessionViewModel) async {
        // Reset all state variables first
        await MainActor.run {
            self.dataReady = false
            self.user = nil
            self.videoThumbnails = []
            self.videoURLs = []
            self.uploadedVideoArray = []
            self.isFollowing = false
            self.errorMessage = nil
        }
        
        print("🔄 Fetching user data for ID: \(userId)")
        
        do {
            // First, quickly load basic user data to show profile header
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard document.exists else {
                await MainActor.run {
                    self.errorMessage = "User document not found"
                    self.dataReady = true
                }
                return
            }
            
            let fetchedUser = try document.data(as: User.self)
            let isPro = document.data()?["isPro"] as? Bool ?? false
            
            await MainActor.run {
                self.user = fetchedUser
                self.nativeLanguage = fetchedUser.nativeLanguage?.capitalized
                self.country = fetchedUser.country?.capitalized
                self.isPro = isPro
                self.errorMessage = nil
                
                // Set dataReady to true after basic user data is loaded
                // This allows the UI to show the profile header while videos load
                self.dataReady = true
            }
            
            print("✅ Basic user data loaded for ID: \(userId)")
            
            // Load following status in parallel with video data
            async let followingTask = checkIfFollowing(userSession: userSession)
            
            // Load video data in parallel tasks
            async let thumbnailsTask = fetchVideoThumbnails()
            async let videosTask = fetchUploadedVideoObjects()
            
            // Wait for all tasks to complete
            _ = await (followingTask, thumbnailsTask, videosTask)
            
            print("✅ All user data loaded for ID: \(userId)")

            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                self.dataReady = true
            }
        }
    }
    
    // MARK: - Follow/Unfollow Functionality
    func followUser() async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != userId else { return }
        
        do {
            // Add to current user's following list
            try await db.collection("users").document(currentUserId).updateData([
                "following": FieldValue.arrayUnion([userId])
            ])
            
            // Add to other user's followers list
            try await db.collection("users").document(userId).updateData([
                "followers": FieldValue.arrayUnion([currentUserId])
            ])
            
            await MainActor.run {
                self.isFollowing = true
                // Update follower count
                if var currentUser = self.user {
                    if currentUser.followers == nil {
                        currentUser.followers = []
                    }
                    if !currentUser.followers!.contains(currentUserId) {
                        currentUser.followers!.append(currentUserId)
                        self.user = currentUser
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to follow user: \(error.localizedDescription)"
            }
        }
    }
    
    func unfollowUser() async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != userId else { return }
        
        do {
            // Remove from current user's following list
            try await db.collection("users").document(currentUserId).updateData([
                "following": FieldValue.arrayRemove([userId])
            ])
            
            // Remove from other user's followers list
            try await db.collection("users").document(userId).updateData([
                "followers": FieldValue.arrayRemove([currentUserId])
            ])
            
            await MainActor.run {
                self.isFollowing = false
                // Update follower count
                if var currentUser = self.user {
                    currentUser.followers?.removeAll { $0 == currentUserId }
                    self.user = currentUser
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Video Object Fetching Methods
    private func fetchUploadedVideoObjects() async {
        guard let uploadedVideoPaths = user?.uploadedVideos, !uploadedVideoPaths.isEmpty else {
            await MainActor.run {
                self.uploadedVideoArray = []
            }
            return
        }
        
        let videos = await fetchVideoObjectsFromPaths(uploadedVideoPaths)
        
        await MainActor.run {
            self.uploadedVideoArray = videos
        }
    }
    
    private func fetchVideoObjectsFromPaths(_ paths: [String]) async -> [Video] {
        var videos: [Video] = []
        
        await withTaskGroup(of: Video?.self) { group in
            for path in paths {
                group.addTask { [weak self] in
                    await self?.fetchVideoObjectFromPath(path)
                }
            }
            
            for await video in group {
                if let video = video {
                    videos.append(video)
                }
            }
        }
        
        return videos
    }
    
    private func fetchVideoObjectFromPath(_ path: String) async -> Video? {
        let components = path.split(separator: "/")
        guard components.count == 3 else {
            print("Invalid path format: \(path) - Skipping video fetch.")
            return nil
        }
        
        let lang = String(components[0])
        let docId = String(components[2])
        
        do {
            let document = try await db.collection(videosCollection)
                .document(lang)
                .collection("items")
                .document(docId)
                .getDocument()
            
            guard document.exists, let data = document.data() else {
                print("Video document missing or no data for \(path)")
                return nil
            }
            
            guard let urlString = data["video_url"] as? String,
                  let url = URL(string: urlString),
                  let likes = data["likes"] as? Int,
                  let saves = data["saves"] as? Int,
                  let language = data["language_detected"] as? String,
                  let uploaderId = data["uploaderId"] as? String,
                  let captionDicts = data["captions"] as? [[String: Any]] else {
                print("Malformed video data for path: \(path)")
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
            let title = data["title"] as? String ?? "Untitled"
            return Video(
                id: docId,
                url: url,
                captions: captions,
                title: title,
                detectedLevel: detectedLevel,
                uploaderId: uploaderId,
                likes: likes,
                saves: saves,
                commentCount: commentCount,
                shares: shares,
                language: language
            )
            
        } catch {
            print("Error fetching video object for \(path):", error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Private Helper Methods
    private func checkIfFollowing(userSession: UserSessionViewModel) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != userId else {
            await MainActor.run {
                self.isFollowing = false
            }
            return
        }
        
        do {
            let document = try await db.collection("users").document(currentUserId).getDocument()
            
            if let data = document.data(),
               let following = data["following"] as? [String] {
                await MainActor.run {
                    self.isFollowing = following.contains(self.userId)
                }
            } else {
                await MainActor.run {
                    self.isFollowing = false
                }
            }
        } catch {
            await MainActor.run {
                self.isFollowing = false
            }
        }
    }
    
    private func fetchVideoThumbnails() async {
        guard let uploadedVideos = user?.uploadedVideos, !uploadedVideos.isEmpty else {
            await MainActor.run {
                self.videoThumbnails = []
                self.videoURLs = []
            }
            return
        }
        
        var thumbnails = Array(repeating: "", count: uploadedVideos.count)
        var videoURLs = Array(repeating: "", count: uploadedVideos.count)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, path) in uploadedVideos.enumerated() {
                group.addTask { [weak self] in
                    await self?.fetchSingleVideoThumbnail(path: path, index: index, thumbnails: &thumbnails, videoURLs: &videoURLs)
                }
            }
        }
        
        await MainActor.run {
            self.videoThumbnails = thumbnails
            self.videoURLs = videoURLs
        }
    }
    
    private func fetchSingleVideoThumbnail(path: String, index: Int, thumbnails: inout [String], videoURLs: inout [String]) async {
        let components = path.split(separator: "/")
        guard components.count == 3 else {
            print("Invalid path format: \(path) - Skipping thumbnail fetch.")
            return
        }
        
        let lang = String(components[0])
        let docId = String(components[2])
        
        do {
            let document = try await db.collection("videos")
                .document(lang)
                .collection("items")
                .document(docId)
                .getDocument()
            
            guard document.exists, let data = document.data() else {
                print("Thumbnail document missing or no data for \(path)")
                return
            }
            
            if let thumbnailURL = data["thumbnail_url"] as? String {
                thumbnails[index] = thumbnailURL
            }
            
            if let videoURL = data["video_url"] as? String {
                videoURLs[index] = videoURL
            }
            
        } catch {
            print("Error fetching thumbnail for \(path):", error.localizedDescription)
        }
    }
}
