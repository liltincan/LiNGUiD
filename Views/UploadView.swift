//Created by Tahmidul Karim

import SwiftUI
import Photos
import AVFoundation
import PhotosUI
import AVKit
import TOCropViewController
import FirebaseAuth


struct UploadView: View {
    var onComplete: (() -> Void)? = nil
    
    @State private var videoAssets: [PHAsset] = []
    @State private var selectedAssets: [PHAsset] = []
    @State private var isMultiSelect = true
    @State private var navigateToThumbnail = false
    @State private var uploadService = VideoUploadService()
    @State private var thumbnailOverrides: [String: UIImage] = [:]
    @State private var compressedVideoURLs: [String: URL] = [:]
    @State private var isCompressing = false

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
//                HStack {
//                    Menu {
//                        Button("Select One") {
//                            isMultiSelect = false
//                            selectedAssets.removeAll()
//                        }
//                        Button("Select Multiple") {
//                            isMultiSelect = true
//                            selectedAssets.removeAll()
//                        }
//                    } label: {
//                        HStack {
//                            Text("Select \(isMultiSelect ? "Multiple" : "One")")
//                            Image(systemName: "chevron.down")
//                        }
//                        .foregroundColor(.white)
//                        .padding(.horizontal)
//                    }
//
//                    Spacer()
//                }
//                .padding(.bottom, 20)

                // 🟣 Video Grid
                GeometryReader { geometry in
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
                    .frame(maxHeight: geometry.size.height) // 🔧 adjust 180 based on header & buttons
                }

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
                            destination: AddThumbnailView(
                                assets: selectedAssets,
                                compressedVideoURLs: compressedVideoURLs,
                                onComplete: {
                                    navigateToThumbnail = false
                                    onComplete?()  // tells ProfileView to pop UploadView
                                },
                                thumbnailOverrides: $thumbnailOverrides
                            ),
                            isActive: $navigateToThumbnail
                        ) {
                            Button(action: {
                                isCompressing = true

                                Task {
                                    isCompressing = true

                                    for asset in selectedAssets {
                                        if compressedVideoURLs[asset.localIdentifier] == nil {
                                            if let url = await compressVideo(from: asset) {
                                                compressedVideoURLs[asset.localIdentifier] = url
                                            }
                                        }
                                    }

                                    isCompressing = false
                                    navigateToThumbnail = true
                                }
                            }) {
                                Text("Next")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.appPrimaryColor)
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
        .animation(.easeInOut, value: isCompressing)
        .onAppear {
            loadVideos()
        }
        .allowsHitTesting(!isCompressing)
        .overlay(
            Group {
                if isCompressing {
                    ZStack {
                        Color.black.opacity(0.9)
                            .ignoresSafeArea()
//                        GeometryReader { geo in
//                            VStack{
//                                Spacer()
//                                    .frame(height: min(geo.size.height * 0.5, 275))
//                                
//                                ProgressView("Processing Video\(selectedAssets.count == 1 ? "" : "s")")
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                    .foregroundColor(.white)
//                                    .font(.headline)
//                                Text("This may take a few moments")
//                                    .foregroundColor(.white)
//                                    .font(.subheadline)
//                                
//                                Spacer()
//                            }
//                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        }
                    }
                }
            }
        )
    }
    
    private func compressVideo(from asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .automatic // original quality
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avURLAsset = avAsset as? AVURLAsset else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: avURLAsset.url)
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
    var overrideImage: UIImage? = nil // ← allow override image
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let override = overrideImage {
                Image(uiImage: override)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .padding(1)               // Inner padding for border
                    .background(Color.white)  // Acts as the uniform border
                    .clipped()
            } else if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .padding(1)
                    .background(Color.white)
                    .clipped()
            } else {
                Image(uiImage: UIImage(systemName: "video") ?? UIImage())
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .padding(1)
                    .background(Color.white)
                    .clipped()
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

extension PHAsset: Identifiable {
    public var id: String { localIdentifier }
}
struct CroppingImage: Identifiable {
    let id = UUID()
    let image: UIImage
}


struct AddThumbnailView: View {
    let assets: [PHAsset]
    let compressedVideoURLs: [String: URL]
    
    var onComplete: (() -> Void)? = nil
    
    @State private var uploadService = VideoUploadService()
    @State private var isUploading = false

    @Binding var thumbnailOverrides: [String: UIImage]
    @State private var showingPickerFor: PHAsset?
    @State private var showingFrameSelectorFor: PHAsset?
    @State private var croppingImage: CroppingImage?
    @State private var croppingSourceAsset: PHAsset?
    
    @EnvironmentObject var uploadManager: UploadManager
    @Environment(\.dismiss) var dismiss

    @State private var isProcessing = false
    @State private var compressedVideoURL: [String: URL] = [:]
    
    var body: some View {
        VStack {
            Text("Edit Thumbnails")
                .font(.title)
                .foregroundColor(.white)
                .padding(.top, 10)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        HStack {
                            VideoThumbnailMiniView(
                                asset: asset,
                                overrideImage: thumbnailOverrides[asset.localIdentifier]
                            )
                            .frame(width: 90, height: 160)

                            Spacer()

                            Button(action: {
                                showingFrameSelectorFor = asset
                            }) {
                                Text("Edit Thumbnail")
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.appPrimaryColor)
                                    .cornerRadius(8)
                            }

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

            Button(action: {
                isProcessing = true // Show full screen overlay immediately

                Task.detached(priority: .userInitiated) {
                    var tempCompressedURLs: [String: URL] = [:]

                    // Compress videos
                    for asset in assets {
                        if let compressedURL = await compressVideo(from: asset) {
                            tempCompressedURLs[asset.localIdentifier] = compressedURL
                        }
                    }

                    // Upload videos
                    await MainActor.run {
                        compressedVideoURL = tempCompressedURLs
                        uploadManager.addUploadingVideos(assets, thumbnails: thumbnailOverrides)
                    }

                    for asset in assets {
                        let id = asset.localIdentifier
                        await uploadManager.startUpload(for: asset) {
                            do {
                                let data = try Data(contentsOf: tempCompressedURLs[id]!)
                                let thumbData = thumbnailOverrides[id]?.jpegData(compressionQuality: 0.9)

                                _ = try await uploadService.uploadVideo(
                                    videoData: data,
                                    filename: getVideoFilename(from: asset),
                                    category: "general",
                                    language: "auto",
                                    uploaderId: Auth.auth().currentUser?.uid,
                                    thumbnailData: thumbData
                                )

                                await MainActor.run {
                                    uploadManager.markUploaded(id)
                                }

                            } catch {
                                print("⚠️ Upload failed for \(id): \(error)")
                            }
                        }
                    }

                    // Hide overlay + navigate back to profile
                    await MainActor.run {
                        onComplete?()
                        isProcessing = false
                    }
                }
            }) {
                Text("Upload")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: 60)
                    .background(Color.appPrimaryColor)
                    .cornerRadius(8)
            }
            .disabled(isProcessing)
            .padding(.bottom, 10)
            .padding(.horizontal, 10)

        }
        .onAppear {
            preloadDefaultThumbnails()
        }
        .fullScreenCover(item: $showingPickerFor) { asset in
            ImagePickerView { image in
                // Crop this image before assigning
                croppingImage = CroppingImage(image: image)
                croppingSourceAsset = asset
                showingPickerFor = nil
            }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $showingFrameSelectorFor) { asset in
            if let url = compressedVideoURLs[asset.localIdentifier] {
                VideoScrubberSelector(
                    videoURL: url,
                    onCancel: { showingFrameSelectorFor = nil },
                    onFrameSelected: { image in
                        thumbnailOverrides[asset.localIdentifier] = image
                        showingFrameSelectorFor = nil
                    },
                    onPickFromLibrary: {
                        showingFrameSelectorFor = nil
                        showingPickerFor = asset
                    }
                )
            } else {
                Text("Error: Compressed video not found.")
            }
        }
        .sheet(item: $croppingImage) { cropping in
            TOCropView(
                image: cropping.image,
                onCropped: { croppedImage in
                    if let asset = croppingSourceAsset {
                        thumbnailOverrides[asset.localIdentifier] = croppedImage
                    }
                    croppingImage = nil
                    croppingSourceAsset = nil
                },
                onCancel: {
                    //User tapped cancel in crop — go back to picker
                    if let asset = croppingSourceAsset {
                        showingPickerFor = asset
                    }
                    croppingImage = nil
                }
            )
        }
        .overFullScreen(isPresented: $isProcessing) {
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView("Processing Videos…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .font(.headline)
                    Text("This may take a few moments")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
            .preferredColorScheme(.dark)
        }
        .background(Color.black.ignoresSafeArea())
        
    }
    
    private func loadVideoData(asset: PHAsset) async throws -> Data {
        if let compressedURL = compressedVideoURLs[asset.localIdentifier] {
            return try Data(contentsOf: compressedURL)
        } else {
            return try await convertAssetToData(asset: asset)
        }
    }
    
    private func uploadSelectedVideo() {
        guard let firstAsset = assets.first else {
            print("No video to upload")
            return
        }

        isUploading = true

        Task {
            do {
                // Convert PSAsset to Data
                let videoData: Data
                
                if let compressedURL = compressedVideoURLs[firstAsset.localIdentifier] {
                    print("✅ Using compressed video at: \(compressedURL)")
                    videoData = try Data(contentsOf: compressedURL)
                } else {
                    print("⚠️ No compressed video found. Falling back to PHAsset conversion.")
                    videoData = try await convertAssetToData(asset: firstAsset)
                }
                
                let thumbnailImage = thumbnailOverrides[firstAsset.localIdentifier]
                let thumbnailData = thumbnailImage?.jpegData(compressionQuality: 0.9)

                let response = try await uploadService.uploadVideo(
                    videoData: videoData,
                    filename: getVideoFilename(from: firstAsset),
                    category: "general",
                    language: "auto",
                    uploaderId: Auth.auth().currentUser?.uid,
                    thumbnailData: thumbnailData
                )

                print("UPLOAD SUCCESS!")
                print("Filename: \(getVideoFilename(from: firstAsset))")
                print("Level: \(response.level)")
                print("Language: \(response.language)")
                print("Keywords: \(response.keywords)")
                
                isUploading = false
            } catch {
                print("Upload failed: \(error)")
                isUploading = false
            }
        }
    }
    
    private func compressVideo(from asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avAsset = avAsset else {
                    continuation.resume(returning: nil)
                    return
                }

                let compressedURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")

                guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPreset1280x720) else {
                    continuation.resume(returning: nil)
                    return
                }

                exportSession.outputURL = compressedURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true

                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: compressedURL)
                    default:
                        print("Compression failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func getVideoFilename(from asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            return resource.originalFilename
        }
        // Fallback if we can't get the original filename
        return "video_\(Date().timeIntervalSince1970).mp4"
    }
    
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
    
    private func preloadDefaultThumbnails() {
        for asset in assets {
            let id = asset.localIdentifier
            if thumbnailOverrides[id] != nil { continue }

            PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                guard let avAsset = avAsset else { return }

                let generator = AVAssetImageGenerator(asset: avAsset)
                generator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: 0.1, preferredTimescale: 600)

                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                        let uiImage = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async {
                            if thumbnailOverrides[id] == nil {
                                thumbnailOverrides[id] = uiImage
                            }
                        }
                    } catch {
                        print("Failed to generate thumbnail for \(id): \(error)")
                    }
                }
            }
        }
    }


}

struct ImagePickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        picker.overrideUserInterfaceStyle = .dark
        
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { image, error in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self.onImagePicked(uiImage)
                    }
                }
            }
        }
    }
}

struct VideoScrubberSelector: View {
    let videoURL: URL
    let onCancel: () -> Void
    let onFrameSelected: (UIImage) -> Void
    let onPickFromLibrary: () -> Void


    @State private var playerItem: AVPlayerItem?
    @State private var videoAsset: AVAsset?
    @State private var currentFrame: UIImage?
    @State private var currentTime: CMTime = .zero

    var body: some View {
        VStack {
            ZStack {
                Text("Select Thumbnail")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                HStack {
                    Button(action: {
                        onCancel()
                    }) {
                        Image("Return_Button")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 20)

                    Spacer()
                }
            }
            if let currentFrame = currentFrame {
                Image(uiImage: currentFrame)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxHeight: 600)
                    .padding(.vertical, 20)
            } else {
                Color.gray
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxHeight: 600)
                    .padding(.vertical, 20)
            }

            if let duration = videoAsset?.duration.seconds {
                VStack(spacing: 16) {
                    // Keep the slider
                    Slider(value: Binding(
                        get: { currentTime.seconds },
                        set: { newValue in
                            let newTime = CMTime(seconds: newValue, preferredTimescale: 600)
                            currentTime = newTime
                            generateThumbnail(at: newTime)
                        }
                    ), in: 0...duration)
                    .tint(Color.appPrimaryColor)
                    .padding(.horizontal, 30)

                    // Replace the old HStack with this one
                    HStack(spacing: 12) {
                        Button(action: onPickFromLibrary) {
                            Text("Pick from Photos")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.appPrimaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }

                        Spacer()

                        Button(action: {
                            if let currentFrame = currentFrame {
                                onFrameSelected(currentFrame)
                            }
                        }) {
                            Text("Use This Frame")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.appPrimaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 30)
                }
            }
        }
        .onAppear {
            loadAsset()
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func loadAsset() {
        let asset = AVAsset(url: videoURL)
        self.videoAsset = asset
        generateThumbnail(at: .zero)
    }

    private func generateThumbnail(at time: CMTime) {
        guard let asset = videoAsset else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        DispatchQueue.global().async {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.currentFrame = uiImage
                }
            } catch {
                print("Failed to generate thumbnail: \(error)")
            }
        }
    }
}

struct TOCropView: UIViewControllerRepresentable {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    let onCancel: () -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> TOCropViewController {
        let cropController = TOCropViewController(image: image)
        cropController.delegate = context.coordinator
        cropController.toolbar.tintColor = UIColor(Color.appPrimaryColor)
        
        // Optional: Lock aspect ratio to 9:16
        cropController.aspectRatioPreset = .presetCustom
        cropController.customAspectRatio = CGSize(width: 9, height: 16)
        cropController.aspectRatioLockEnabled = true
        cropController.resetAspectRatioEnabled = false
        cropController.cropView.cropRegionInsets = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)

        return cropController
    }

    func updateUIViewController(_ uiViewController: TOCropViewController, context: Context) {}

    class Coordinator: NSObject, TOCropViewControllerDelegate {
        var parent: TOCropView

        init(parent: TOCropView) {
            self.parent = parent
        }

        func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
            cropViewController.dismiss(animated: true)
            parent.onCropped(image)
        }

        func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
            cropViewController.dismiss(animated: true)
            parent.onCancel()
        }
    }
}

struct OverFullScreen<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content
    let animated: Bool
    let transitionStyle: UIModalTransitionStyle

    init(isPresented: Binding<Bool>,
         animated: Bool = true,
         transitionStyle: UIModalTransitionStyle = .crossDissolve,
         @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.animated = animated
        self.transitionStyle = transitionStyle
        self.content = content
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present
        if isPresented {
            if context.coordinator.hostingController == nil {
                let host = UIHostingController(rootView: AnyView(content()))
                host.modalPresentationStyle = .overFullScreen
                host.modalTransitionStyle = transitionStyle
                // Make background clear so SwiftUI content can show a dimmer Color behind it.
                host.view.backgroundColor = .clear

                // Present from the container controller
                uiViewController.present(host, animated: animated) {
                    context.coordinator.hostingController = host
                }
            } else {
                context.coordinator.hostingController?.rootView = AnyView(content())
            }
        } else {
            // Dismiss
            if let host = context.coordinator.hostingController {
                host.dismiss(animated: animated) {
                    context.coordinator.hostingController = nil
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var hostingController: UIHostingController<AnyView>?
    }
}

extension View {
    func overFullScreen<ModalContent: View>(
        isPresented: Binding<Bool>,
        animated: Bool = true,
        transitionStyle: UIModalTransitionStyle = .crossDissolve,
        @ViewBuilder content: @escaping () -> ModalContent
    ) -> some View {
        background(
            OverFullScreen(isPresented: isPresented,
                           animated: animated,
                           transitionStyle: transitionStyle,
                           content: { content().eraseToAnyView() })
                .frame(width: 0, height: 0)
        )
    }
}

fileprivate extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

//struct UploadView_Previews: PreviewProvider {
//    static var previews: some View {
//        UploadView()
//    }
//}
