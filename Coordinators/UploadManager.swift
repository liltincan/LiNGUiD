//
//  UploadManager.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 7/9/25.
//

import Foundation
import SwiftUI
import Photos

@MainActor
class UploadManager: ObservableObject {
    struct UploadingVideo: Identifiable, Equatable {
        let id: UUID
        let localIdentifier: String
        let thumbnail: UIImage
        let uploadId: String // Used to poll backend progress
        var progress: Double // 0.0 to 1.0
        var isUploading: Bool
        var filename: String
        
        static func == (lhs: UploadingVideo, rhs: UploadingVideo) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    @Published var totalToUpload: Int = 0
    @Published var completedCount: Int = 0
    @Published var uploadingVideos: [UploadingVideo] = []
    @Published var currentIndex: Int = 0
    
    var totalCount: Int { uploadingVideos.count }
    var onUploadFinished: (() -> Void)?

    private var uploadTasks: [String: Task<Void, Never>] = [:]
    private var pollingTasks: [String: Task<Void, Never>] = [:]

    // Add videos to upload queue, each with a unique uploadId
    func addUploadingVideos(_ assets: [PHAsset], thumbnails: [String: UIImage]) {
        totalToUpload = assets.count
        for asset in assets {
            let id = asset.localIdentifier
            let thumbnail = thumbnails[id] ?? UIImage(systemName: "video")!
            let uploadId = UUID().uuidString // Generate a unique uploadId for backend
            let filename = "video_\(Date().timeIntervalSince1970).mp4"
            let uploadingVideo = UploadingVideo(
                id: UUID(),
                localIdentifier: id,
                thumbnail: thumbnail,
                uploadId: uploadId,
                progress: 0.0,
                isUploading: true,
                filename: filename
            )
            uploadingVideos.append(uploadingVideo)
        }
    }

    // Start upload and polling for progress
    func startUpload(for asset: PHAsset, using uploadClosure: @escaping (_ uploadId: String) async -> Void) {
        guard let video = uploadingVideos.first(where: { $0.localIdentifier == asset.localIdentifier }) else { return }
        let id = asset.localIdentifier
        let uploadId = video.uploadId
        let task = Task {
            await uploadClosure(uploadId)
        }
        uploadTasks[id] = task
        startPollingProgress(for: uploadId, localIdentifier: id)
    }

    // Poll backend for progress
    private func startPollingProgress(for uploadId: String, localIdentifier: String) {
        let pollingTask = Task {
            while let index = uploadingVideos.firstIndex(where: { $0.uploadId == uploadId && $0.isUploading }) {
                do {
                    let percent = try await fetchProgress(uploadId: uploadId)
                    await MainActor.run {
                        uploadingVideos[index].progress = percent / 100.0
                    }
                    if percent >= 100 {
                        break
                    }
                } catch {
                    print("Polling error for uploadId \(uploadId):", error)
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        pollingTasks[uploadId] = pollingTask
    }

    // Fetch progress from backend
    private func fetchProgress(uploadId: String) async throws -> Double {
        guard let url = URL(string: "https://your-backend-url/upload_progress/\(uploadId)") else { return 0 }
        let (data, _) = try await URLSession.shared.data(from: url)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let progress = json["progress"] as? Double {
            return progress
        }
        return 0
    }

    func cancelUpload(for localIdentifier: String) {
        uploadTasks[localIdentifier]?.cancel()
        uploadTasks.removeValue(forKey: localIdentifier)
        if let video = uploadingVideos.first(where: { $0.localIdentifier == localIdentifier }) {
            pollingTasks[video.uploadId]?.cancel()
            pollingTasks.removeValue(forKey: video.uploadId)
        }
        uploadingVideos.removeAll { $0.localIdentifier == localIdentifier }
    }

    func markUploaded(_ id: String) {
        guard let index = uploadingVideos.firstIndex(where: { $0.localIdentifier == id }) else { return }
        let uploadId = uploadingVideos[index].uploadId
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.uploadingVideos.removeAll { $0.localIdentifier == id }
            self.uploadTasks.removeValue(forKey: id)
            self.pollingTasks[uploadId]?.cancel()
            self.pollingTasks.removeValue(forKey: uploadId)
            self.completedCount += 1
            self.onUploadFinished?()
            if self.completedCount == self.totalToUpload {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.reset()
                }
            }
        }
    }
    
    func reset() {
        uploadTasks.values.forEach { $0.cancel() }
        uploadTasks.removeAll()
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
        uploadingVideos.removeAll()
        totalToUpload = 0
        completedCount = 0
    }
}
