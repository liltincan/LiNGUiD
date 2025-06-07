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
            
            
            // Determine which language to use
            let targetLanguage : String
            if let language = language {
                targetLanguage = language
            } else {
                targetLanguage = user.targetLanguage
            }
            if(targetLanguage == ""){
                errorMessage = "Target language not set, set the target language in firestore add manually\ntargetLanguage: 'de' "
            }else{
                errorMessage = nil
                selectedLanguage = targetLanguage // stores the language for future use.
                
                print("User languages:", user.languagesData?.keys ?? []) // check if user has language data
                
                let newVideos = try await repository.fetchVideos(
                    afterID: targetLanguage,
                    limit: pageSize,
                    user: user,
                    selectedLanguage: targetLanguage
                )
                
                videos = newVideos
                lastID = newVideos.last?.id
                print(" videos",videos)
            }
            
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
}
