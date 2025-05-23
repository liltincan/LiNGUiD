import Foundation

@MainActor
class VideoFeedViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false

    private let repository: VideoRepository
    private var lastID: String?

    init(repository: VideoRepository = DependencyContainer.shared.resolve()) {
        self.repository = repository
    }

    func loadInitial() async {
        // TODO: load first page
    }

    func loadMore() async {
        // TODO: load next page
    }
}
