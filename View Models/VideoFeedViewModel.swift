import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class VideoFeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var selectedLanguage: String?
    @Published var errorMessage: String?
    
    private let repository: VideoRepository
    private let authService: AuthService
    private let db = Firestore.firestore()
    private var lastID: String?
    private let pageSize = 10
    @Published var deepLinkedVideoIndex: Int?
    
    init(repository: VideoRepository = DependencyContainer.shared.resolve(), authService: AuthService = DependencyContainer.shared.resolve()) {
        self.repository = repository
        self.authService = authService
    }
    
    func getAvailableLanguages(for user: User) -> [String] {
        guard let languagesData = user.languagesData else { return [] }
        return Array(languagesData.keys)
    }
    
    func fetchInitialVideos(for language: String? = nil) async {
        guard !isLoading else { return }
        
        guard let userID = authService.currentUserID else { return }
        print("Current user ID:", authService.currentUserID ?? "nil") // checking user is actually logged in
        
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch full user object from Firestore
            let userDoc = try await db.collection("users").document(userID).getDocument()
            let user = try userDoc.data(as: User.self)
            
            // debugging code
            print("WATCHED COUNT CHECK: \(user.watchedVideos?.count ?? 0)")
            // Determine which language to use
            /*
             Commenting out because we now have a targetLanguage property in User Model. We could delete later
             let targetLanguage : String
             if let language = language {
             targetLanguage = language
             } else if let firstLanguage = user.languagesData?.keys.first {
             targetLanguage = firstLanguage.lowercased()
             } else {
             print("User has no target languages, using 'russian' as fallback")
             targetLanguage = "russian"
             }*/
            
            // 1. check if targetLanguage is empty (it shoudn't)
            // if empty, fall back to the first language from languagesData
            // if that is also empty, default to "french"
            let targetLanguage = user.targetLanguage.isEmpty ?
            (user.languagesData?.keys.first?.lowercased() ?? "french") :
            user.targetLanguage.lowercased()
            
            selectedLanguage = targetLanguage // stores the language for future use.
            print("User languages:", user.languagesData?.keys ?? []) // check if user has language data
            
            let newVideos = try await repository.fetchVideos(
                afterID: targetLanguage,
                limit: pageSize,
                user: user,
                selectedLanguage: targetLanguage
            )
            
            for video in newVideos {
                DispatchQueue.global(qos: .background).async {
                    _ = VideoAssetCache.shared.asset(for: video.url)
                }
            }
            
            videos = newVideos
            lastID = newVideos.last?.id
        } catch {
            print("Error loading initial videos: \(error)")
        }
        
    }
    
    func fetchMoreVideos() async {
        guard !isLoading,
              let lastID = lastID,
              let userID = authService.currentUserID,
              let currentLanguage = selectedLanguage else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch full user object from Firestore
            let userDoc = try await db.collection("users").document(userID).getDocument()
            let user = try userDoc.data(as: User.self)
            let newVideos = try await repository.fetchVideos(
                afterID: lastID,
                limit: pageSize,
                user: user,
                selectedLanguage: currentLanguage // Use stored language
            )
            videos.append(contentsOf: newVideos)
            self.lastID = newVideos.last?.id
        } catch {
            print("Error loading more videos: \(error)")
        }
    }
    
    @MainActor
    func resetVideos(startingWith videoId: String) async {
        videos = []
        await fetchInitialVideos()

        // Check if video is missing after initial fetch
        if !videos.contains(where: { $0.id == videoId }) {
            do {
                guard let userID = authService.currentUserID else { return }
                let userDoc = try await db.collection("users").document(userID).getDocument()
                let user = try userDoc.data(as: User.self)

                let targetLanguage = user.targetLanguage.isEmpty ?
                    (user.languagesData?.keys.first?.lowercased() ?? "french") :
                    user.targetLanguage.lowercased()

                selectedLanguage = targetLanguage

                if let deepLinkedVideo = try await repository.fetchVideoById(
                    videoId: videoId,
                    user: user,
                    selectedLanguage: targetLanguage
                ) {
                    // Insert at front
                    print("Deep linked video FOUND:", deepLinkedVideo.title)
                    videos.insert(deepLinkedVideo, at: 0)

                    // Also update deepLinkedVideoIndex to 0 explicitly
                    deepLinkedVideoIndex = 0
                } else {
                    print("Deep linked video NOT FOUND in repository for ID:", videoId)
                }

            } catch {
                print("Failed to fetch deep-linked video separately: \(error)")
            }
        } else {
            // If video is already in videos, update index accordingly
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                deepLinkedVideoIndex = index
            }
        }
    }

}

