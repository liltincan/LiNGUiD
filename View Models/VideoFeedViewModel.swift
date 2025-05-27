import Foundation

@MainActor
class VideoFeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false

    private let repository: VideoRepository
    private var lastID: String?
    private let pageSize = 10

    init(repository: VideoRepository = DependencyContainer.shared.resolve()) {
        self.repository = repository
    }

    func fetchInitialVideos() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let newVideos = try await repository.fetchVideos(afterID: nil, limit: pageSize)
            videos = newVideos
            lastID = newVideos.last?.id
        } catch {
            print("Error loading initial videos: \(error)")
        }
    }

    func fetchMoreVideos() async {
        guard !isLoading, let lastID = lastID else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let newVideos = try await repository.fetchVideos(afterID: lastID, limit: pageSize)
            videos.append(contentsOf: newVideos)
            self.lastID = newVideos.last?.id
        } catch {
            print("Error loading more videos: \(error)")
        }
    }
}
