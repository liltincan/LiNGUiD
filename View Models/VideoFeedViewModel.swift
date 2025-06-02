import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class VideoFeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    
    private let repository: VideoRepository
    private let authService: AuthService
    private let db = Firestore.firestore()
    private var lastID: String?
    private let pageSize = 10

    init(repository: VideoRepository = DependencyContainer.shared.resolve(), authService: AuthService = DependencyContainer.shared.resolve()) {
        self.repository = repository
        self.authService = authService
    }

    func fetchInitialVideos() async {
        guard !isLoading else { return }
        
        guard let userID = authService.currentUserID else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch full user object from Firestore
            let userDoc = try await db.collection("users").document(userID).getDocument()
            let user = try userDoc.data(as: User.self)
            
            
            let newVideos = try await repository.fetchVideos(
                afterID: "russian",
                limit: pageSize,
                user: user,
                selectedLanguage: "russian"
            )
            videos = newVideos
            lastID = newVideos.last?.id
        } catch {
            print("Error loading initial videos: \(error)")
        }
    }

    func fetchMoreVideos() async {
        guard !isLoading else { return }
        
        guard let userID = authService.currentUserID else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch full user object from Firestore
            let userDoc = try await db.collection("users").document(userID).getDocument()
            let user = try userDoc.data(as: User.self)
            let newVideos = try await repository.fetchVideos(
                afterID: "russian",
                limit: pageSize,
                user: user,
                selectedLanguage: "russian"
            )
            videos.append(contentsOf: newVideos)
            self.lastID = newVideos.last?.id
        } catch {
            print("Error loading more videos: \(error)")
        }
    }
}
