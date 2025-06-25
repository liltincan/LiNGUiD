import SwiftUI
import Photos
import AVFoundation

struct UploadView: View {
    @State private var videoAssets: [PHAsset] = []
    @State private var selectedAssets: [PHAsset] = []
    @State private var isMultiSelect = false
    @State private var navigateToThumbnail = false
    @State private var uploadService = VideoUploadService()

    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

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
                        Button("Select One") {
                            isMultiSelect = false
                            selectedAssets.removeAll()
                        }
                        Button("Select Multiple") {
                            isMultiSelect = true
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
                .padding(.bottom, 20)

                // 🟣 Video Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 0) {
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
                }
                .padding(.horizontal, 2.5)
                .frame(maxHeight: .infinity, alignment: .bottom)

                Spacer()

                // 🟣 Continue Button
                if(!selectedAssets.isEmpty){
                    HStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(selectedAssets.reversed(), id: \.localIdentifier) { asset in
                                    VideoThumbnailMiniView(asset: asset)
                                        .frame(width: 24, height: 42.5) // keeps 9:16 aspect
                                }
                            }
                            .padding(.leading, 2.5)
                        }
                        .padding(.vertical, 2.5)
                        
                        Spacer()
                        
                        NavigationLink(
                            destination: AddThumbnailView(assets: selectedAssets),
                            isActive: $navigateToThumbnail
                        ) {
                            Button(action: {
                                navigateToThumbnail = true
                            }) {
                                Text("Next")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .disabled(selectedAssets.isEmpty)
                        .padding(.trailing, 2.5)
                    }
                    .padding(.bottom, 5)
                }
            }
        }
        .onAppear {
            loadVideos()
        }

        // Temporary video upload testing
        VStack {
            Button("Test API Connection") {
                testAPIConnection()
            }

            Button("Test Video Upload") {
                testVideoUpload()
            }
            Button("Test Mock Upload") {
                testWithMockVideo()
            }
        }
    }

    private func testAPIConnection() {
        Task {
            await uploadService.testConnection()
        }
    }

    // Helped function to convert PHAsset to Data
    private func convertAssetToData(asset: PHAsset) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: VideoUploadError(
                        message: "Could not get video URL from asset",
                        code: "asset_conversion_failed",
                        details: nil
                    ))
                    return
                }
                
                do {
                    let videoData = try Data(contentsOf: urlAsset.url)
                    continuation.resume(returning: videoData)
                } catch {
                    continuation.resume(throwing: VideoUploadError(
                        message: "Could not read video data",
                        code: "data_read_failed", 
                        details: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func testVideoUpload() {
        // Check if we have a selected video
        guard let firstAsset = selectedAssets.first else {
            print("No video selected. Please select a video first")
            return
        }

        print("Testing upload with selected video")

        Task {
            do {
                // Step 1: Convert PHAsset to Data
            let videoData = try await convertAssetToData(asset: firstAsset)
            print("Converted video to data: \(videoData.count) bytes")
            
            // Step 2: Upload to your Python API
            let response = try await uploadService.uploadVideo(
                videoData: videoData,
                filename: "test_video_\(Date().timeIntervalSince1970).mp4",
                category: "conversation", // Required by your API
                language: "auto",
                uploaderId: "test_user_123"
            )
            
            // Step 3: Success!
            print("UPLOAD SUCCESS!")
            print("Video ID: \(response.documentId)")
            print("Difficulty Level: \(response.level)")
            print("Language: \(response.language)")
            print("Keywords: \(response.keywords)")
            print("Transcript preview: \(response.transcript.prefix(100))...")
            print("Video URL: \(response.videoUrl)")
            
            } catch {
                print("UPLOAD FAILED:")
                print("   Error: \(error)")
                
                if let uploadError = error as? VideoUploadError {
                    print("   Code: \(uploadError.code ?? "unknown")")
                    print("   Details: \(uploadError.details ?? "none")")
                }
            }
        }
    }

    // Alternative: Test with a mock video
    private func testWithMockVideo() {
        print("Testing with mock video data...")
        
        // Create small mock video data (just for testing API communication)
        let mockVideoData = "mock video content".data(using: .utf8) ?? Data()
        
        Task {
            do {
                let response = try await uploadService.uploadVideo(
                    videoData: mockVideoData,
                    filename: "mock_test.mp4",
                    category: "test",
                    language: "auto",
                    uploaderId: "test_user"
                )
                
                print("Mock upload successful!")
                print("Response: \(response)")
                
            } catch {
                print("Mock upload failed: \(error)")
            }
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
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { authStatus in
            print("Photo library authorization status: \(authStatus)")
        
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let results = PHAsset.fetchAssets(with: options)
            print("Found \(results.count) videos in photo library")
            DispatchQueue.main.async {
                videoAssets = results.objects(at: IndexSet(0..<results.count))
                print("Loaded \(videoAssets.count) video assets")
            }
        }
    }
}

struct VideoThumbnailMiniView: View {
    let asset: PHAsset
    @State private var thumbnail: UIImage?

    var body: some View {
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
            }
        }
        .onAppear(perform: fetchThumbnail)
    }

    private func fetchThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.resizeMode = .fast

        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 225, height: 400),
                             contentMode: .aspectFill,
                             options: options) { image, _ in
            self.thumbnail = image
        }
    }
}


struct AddThumbnailView: View {
    let assets: [PHAsset]

    var body: some View {
        VStack {
            Text("Add Thumbnails")
                .font(.title)
                .foregroundColor(.white) // ensure text is visible
                .padding(.top, 10)
            
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        HStack {
                            VideoThumbnailMiniView(asset: asset)
                                .frame(width: 90, height: 160)
                            
                            Spacer()
                            
                            Text("Add/Edit thumbnail here")
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding()
                        .background(Color.black)
                        .cornerRadius(8)
                        
                        Divider()
                            .background(Color.white.opacity(1.0))
                    }
                }
                .padding(.horizontal, 10)
            }
            .background(Color.black.ignoresSafeArea())
            
            Button(action: {
                // Handle continue action
                print("Continue tapped")
            }) {
                Text("Upload")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 124/255, green: 58/255, blue: 237/255))

            }
            .padding(.vertical, 20)
            .padding(.horizontal, 10)

        }
        .background(Color.black.ignoresSafeArea()) // whole screen black
    }
}
//struct UploadView_Previews: PreviewProvider {
//    static var previews: some View {
//        UploadView()
//    }
//}
