import SwiftUI
import Photos

struct UploadView: View {
    @State private var videoAssets: [PHAsset] = []
    @State private var selectedAssets: [PHAsset] = []
    @State private var isMultiSelect = true

    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 🟣 Header
                Text("Upload")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                    .padding(.bottom, 30)

                // 🟣 Selection Menu
                HStack {
                    Menu {
                        Button("Select Multiple") {
                            isMultiSelect = true
                            selectedAssets.removeAll()
                        }
                        Button("Select One") {
                            isMultiSelect = false
                            selectedAssets.removeAll()
                        }
                    } label: {
                        HStack {
                            Text("Select \(isMultiSelect ? "Multiple" : "One")")
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.horizontal, 5)
                .padding(.bottom, 20)

                // 🟣 Video Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(videoAssets, id: \.localIdentifier) { asset in
                            VideoThumbnailSelectableView(
                                asset: asset,
                                index: selectedAssets.firstIndex(of: asset).map { $0 + 1 },
                                isSelected: selectedAssets.contains(asset)
                            )
                            .onTapGesture {
                                handleSelection(for: asset)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Spacer()

                // 🟣 Continue Button
                Button(action: {
                    // Upload logic
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAssets.isEmpty ? Color(red: 72/255, green: 28/255, blue: 119/255) : Color(red: 124/255, green: 58/255, blue: 237/255))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedAssets.isEmpty)
                .padding(.vertical, 20)
                .padding(.horizontal, 50)
            }
        }
        .onAppear {
            loadVideos()
        }
    }

    private func handleSelection(for asset: PHAsset) {
        if selectedAssets.contains(asset) {
            selectedAssets.removeAll { $0 == asset }
        } else {
            if isMultiSelect {
                selectedAssets.append(asset)
            } else {
                selectedAssets = [asset]
            }
        }
    }

    private func loadVideos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let results = PHAsset.fetchAssets(with: options)
            DispatchQueue.main.async {
                videoAssets = results.objects(at: IndexSet(0..<results.count))
            }
        }
    }
}

struct UploadView_Previews: PreviewProvider {
    static var previews: some View {
        UploadView()
    }
}
