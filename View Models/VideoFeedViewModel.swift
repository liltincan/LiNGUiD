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
    
    func fetchInitialVideos() async {
        guard !isLoading else { return }
        guard let userID = authService.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let userDoc = try await db.collection("users").document(userID).getDocument()
            let user = try userDoc.data(as: User.self)

            // Fetch all target languages (fallback logic if empty)
            let languageList: [String]
            if let targetList = user.targetLanguageList, !targetList.isEmpty {
                languageList = targetList.map { $0.lowercased() }
            } else {
                languageList = user.languagesData?.keys.map { $0.lowercased() } ?? ["french"]
            }

            selectedLanguage = languageList.first // Can be used to set UI filters

            print("Fetching videos for targetLanguageList: \(languageList)")

            let newVideos = try await repository.fetchVideos(
                afterID: nil,
                limit: pageSize,
                user: user,
                selectedLanguages: languageList
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
              let userID = authService.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let userDoc = try await db.collection("users").document(userID).getDocument()
            let user = try userDoc.data(as: User.self)

            let languageList: [String]
            if let targetList = user.targetLanguageList, !targetList.isEmpty {
                languageList = targetList.map { $0.lowercased() }
            } else {
                languageList = user.languagesData?.keys.map { $0.lowercased() } ?? ["french"]
            }

            selectedLanguage = languageList.first // for UI, optional

            let newVideos = try await repository.fetchVideos(
                afterID: lastID,
                limit: pageSize,
                user: user,
                selectedLanguages: languageList
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

