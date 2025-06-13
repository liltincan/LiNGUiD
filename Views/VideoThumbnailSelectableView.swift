import SwiftUI
import Photos

struct VideoThumbnailSelectableView: View {
    let asset: PHAsset
    let index: Int?    // If selected, show index
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(9/16, contentMode: .fill)
                        .border(Color.white.opacity(0.8), width: 1)
                        .clipped()
                } else {
                    Color.gray
                        .aspectRatio(9/16, contentMode: .fill)
                        .border(Color.white.opacity(0.8), width: 1)
                }
            }
            .onAppear(perform: fetchThumbnail)

            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 24, height: 24)
                .background(isSelected ? Circle().fill(Color(red: 124/255, green: 58/255, blue: 237/255)
) : Circle().fill(Color.black.opacity(0.5)))
                .overlay(
                    Text(index != nil ? "\(index!)" : "")
                        .foregroundColor(.white)
                        .font(.caption2)
                )
                .padding(6)
        }
    }

    private func fetchThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 900, height: 1600),
                             contentMode: .aspectFill,
                             options: options) { image, _ in
            self.thumbnail = image
        }
    }

}
