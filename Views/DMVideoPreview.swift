struct DMVideoPreview: View {
    @StateObject private var vm = DMVideoPreviewViewModel()
    
    let videoPath: String // "language/items/documentId"
    let posterUsername: String
    let posterPFPURL: String?
    
    var body: some View {
        ZStack {
            if let urlStr = vm.thumbnailURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.2))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipped()
                    case .failure:
                        Color.gray.frame(height: 250)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Color.gray.frame(height: 250)
            }
            
            // Play button overlay
            Image(systemName: "play.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            // Poster info at bottom
            VStack {
                Spacer()
                HStack {
                    if let pfp = posterPFPURL, let pfpURL = URL(string: pfp) {
                        AsyncImage(url: pfpURL) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(Color.gray)
                        }
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 30, height: 30)
                    }
                    Text(posterUsername)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(10)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), .clear]), startPoint: .bottom, endPoint: .top)
                )
            }
        }
        .frame(height: 250)
        .cornerRadius(12)
        .clipped()
        .onAppear {
            Task {
                await vm.fetchVideoInfo(from: videoPath)
            }
        }
    }
}
