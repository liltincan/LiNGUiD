class DMVideoPreviewViewModel: ObservableObject {
    @Published var thumbnailURL: String?
    @Published var videoURL: String?
    
    private let db = Firestore.firestore()
    
    func fetchVideoInfo(from path: String) async {
        var thumbnails = [""]
        var videoURLs = [""]
        
        await fetchSingleVideoThumbnail(
            path: path,
            index: 0,
            thumbnails: &thumbnails,
            videoURLs: &videoURLs
        )
        
        DispatchQueue.main.async {
            self.thumbnailURL = thumbnails.first
            self.videoURL = videoURLs.first
        }
    }
    
    private func fetchSingleVideoThumbnail(path: String, index: Int, thumbnails: inout [String], videoURLs: inout [String]) async {
        let components = path.split(separator: "/")
        guard components.count == 3 else {
            print("Invalid path format: \(path)")
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
                print("No data for path \(path)")
                return
            }
            
            if let thumb = data["thumbnail_url"] as? String {
                thumbnails[index] = thumb
            }
            if let url = data["video_url"] as? String {
                videoURLs[index] = url
            }
        } catch {
            print("Error fetching video: \(error.localizedDescription)")
        }
    }
}
