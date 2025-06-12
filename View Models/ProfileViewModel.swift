import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation
import SwiftUICore

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var dataReady: Bool = false
    @Published var errorMessage: String?
    @Published var videoThumbnails: [String] = []
    @Published var videoURLs: [String] = []
    @Published var likedVideoThumbnails: [String] = []
    @Published var savedVideoThumbnails: [String] = []
    
    private let db = Firestore.firestore()
    private let userSession: UserSessionViewModel
    
    init(userSession: UserSessionViewModel) {
        self.userSession = userSession
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
        return String(Int(user?.globalWatchTime ?? 0))
    }
    
    var followerCount: String {
        return String(user?.followers?.count ?? 0)
    }
    
    var profilePictureURL: String {
        return user?.profilePhotoUrl ?? ""
    }
    
    var formattedLanguagesDisplay: String {
        guard let languagesData = user?.languagesData, !languagesData.isEmpty else {
            return "No languages selected"
        }
        
        let displayStrings: [String] = languagesData.compactMap { (languageName, langData) in
            guard let comprehensionLevel = langData.comprehensionLevel else {
                return nil
            }
            let languageCode = String(languageName.prefix(2))
            return "\(languageCode) (Lvl \(comprehensionLevel))"
        }
        
        return "En → " + displayStrings.joined(separator: ", ")
    }
    
    var allLanguageNames: Set<String> {
        guard let languagesData = user?.languagesData else {
            return Set<String>()
        }
        return Set(languagesData.keys)
    }
    
    // MARK: - Data Fetching
    func fetchUserData() async {
        await userSession.refreshUser()
        
        guard let currentUser = userSession.currentUser else {
            await MainActor.run {
                self.errorMessage = "No user session found"
                self.dataReady = true
            }
            return
        }
        
        await MainActor.run {
            self.user = currentUser
            self.errorMessage = nil
        }
        
        await fetchVideoThumbnails()
        await fetchLikedAndSavedThumbnails()
        
        await MainActor.run {
            self.dataReady = true
        }
    }
    
    func fetchUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            guard document.exists else {
                await MainActor.run {
                    self.errorMessage = "User document not found"
                    self.dataReady = true
                }
                return
            }
            
            let fetchedUser = try document.data(as: User.self)
            
            await MainActor.run {
                self.user = fetchedUser
                self.errorMessage = nil
            }
            
            await fetchVideoThumbnails()
            await fetchLikedAndSavedThumbnails()
            
            await MainActor.run {
                self.dataReady = true
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                self.dataReady = true
            }
        }
    }
    
    // MARK: - Update User Data
    func updateUser(_ updatedUser: User) async {
        guard let userId = updatedUser.id else {
            await MainActor.run {
                self.errorMessage = "User ID not found"
            }
            return
        }
        
        do {
            try db.collection("users").document(userId).setData(from: updatedUser, merge: true)
            
            await MainActor.run {
                self.user = updatedUser
                self.errorMessage = nil
            }
            
            await userSession.refreshUser()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update user: \(error.localizedDescription)"
            }
        }
    }
    
    func updateLanguageData(_ languageKey: String, _ languageData: LanguagesData) async {
        guard var currentUser = user, let userId = currentUser.id else {
            await MainActor.run {
                self.errorMessage = "No user data available"
            }
            return
        }
        
        if currentUser.languagesData == nil {
            currentUser.languagesData = [:]
        }
        currentUser.languagesData?[languageKey] = languageData
        
        let patch = FirestoreUserPatch(languagesData: [languageKey: languageData])
        
        do {
            try db.collection("users").document(userId).setData(from: patch, merge: true)
            
            await MainActor.run {
                self.user = currentUser
                self.errorMessage = nil
            }
            
            await userSession.refreshUser()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update language data: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Video Operations
    func addUploadedVideo(_ videoPath: String) async {
        guard var currentUser = user, let userId = currentUser.id else { return }
        
        if currentUser.uploadedVideos == nil {
            currentUser.uploadedVideos = []
        }
        
        currentUser.uploadedVideos?.append(videoPath)
        await updateUser(currentUser)
    }
    
    func addLikedVideo(_ videoPath: String) async {
        guard var currentUser = user, let userId = currentUser.id else { return }
        
        if currentUser.likedVideos == nil {
            currentUser.likedVideos = []
        }
        
        if !currentUser.likedVideos!.contains(videoPath) {
            currentUser.likedVideos?.append(videoPath)
            await updateUser(currentUser)
        }
    }
    
    func removeLikedVideo(_ videoPath: String) async {
        guard var currentUser = user else { return }
        
        currentUser.likedVideos?.removeAll { $0 == videoPath }
        await updateUser(currentUser)
    }
    
    func addSavedVideo(_ videoPath: String) async {
        guard var currentUser = user, let userId = currentUser.id else { return }
        
        if currentUser.savedVideos == nil {
            currentUser.savedVideos = []
        }
        
        if !currentUser.savedVideos!.contains(videoPath) {
            currentUser.savedVideos?.append(videoPath)
            await updateUser(currentUser)
        }
    }
    
    func removeSavedVideo(_ videoPath: String) async {
        guard var currentUser = user else { return }
        
        currentUser.savedVideos?.removeAll { $0 == videoPath }
        await updateUser(currentUser)
    }
    
    // MARK: - Private Helper Methods
    private func fetchVideoThumbnails() async {
        guard let uploadedVideos = user?.uploadedVideos, !uploadedVideos.isEmpty else {
            await MainActor.run {
                self.videoThumbnails = []
                self.videoURLs = []
            }
            return
        }
        
        let processedVideos = uploadedVideos.map { videoPath in
            videoPath.replacingOccurrences(of: "en/", with: "english/")
                .replacingOccurrences(of: "fr/", with: "french/")
                .replacingOccurrences(of: "ru/", with: "russian/")
                .replacingOccurrences(of: "es/", with: "spanish/")
        }
        
        var thumbnails = Array(repeating: "", count: processedVideos.count)
        var videoURLs = Array(repeating: "", count: processedVideos.count)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, path) in processedVideos.enumerated() {
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
    
    private func fetchLikedAndSavedThumbnails() async {
        // Fetch liked video thumbnails
        if let likedVideos = user?.likedVideos, !likedVideos.isEmpty {
            await fetchThumbnailsForVideos(likedVideos) { thumbnails in
                self.likedVideoThumbnails = thumbnails
            }
        }
        
        // Fetch saved video thumbnails
        if let savedVideos = user?.savedVideos, !savedVideos.isEmpty {
            await fetchThumbnailsForVideos(savedVideos) { thumbnails in
                self.savedVideoThumbnails = thumbnails
            }
        }
    }
    
    private func fetchThumbnailsForVideos(_ videoPaths: [String], completion: @escaping ([String]) -> Void) async {
        let processedVideos = videoPaths.map { videoPath in
            videoPath.replacingOccurrences(of: "en/", with: "english/")
                .replacingOccurrences(of: "fr/", with: "french/")
                .replacingOccurrences(of: "ru/", with: "russian/")
                .replacingOccurrences(of: "es/", with: "spanish/")
        }
        
        var thumbnails = Array(repeating: "", count: processedVideos.count)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, path) in processedVideos.enumerated() {
                group.addTask { [weak self] in
                    let components = path.split(separator: "/")
                    guard components.count == 3 else { return }
                    
                    let lang = String(components[0])
                    let docId = String(components[2])
                    
                    do {
                        let document = try await self?.db.collection("videos")
                            .document(lang)
                            .collection("items")
                            .document(docId)
                            .getDocument()
                        
                        guard let document = document, document.exists, let data = document.data() else { return }
                        
                        if let thumbnailURL = data["thumbnail_url"] as? String {
                            thumbnails[index] = thumbnailURL
                        }
                        
                    } catch {
                        print("Error fetching thumbnail for \(path):", error.localizedDescription)
                    }
                }
            }
        }
        
        await MainActor.run {
            completion(thumbnails)
        }
    }
}
