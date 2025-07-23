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
    struct UploadingVideo: Identifiable {
        let id = UUID()
        let localIdentifier: String
        let thumbnail: UIImage
        var isUploading: Bool
    }
    
    @Published var totalToUpload: Int = 0
    @Published var completedCount: Int = 0
    @Published var uploadingVideos: [UploadingVideo] = []
    @Published var currentIndex: Int = 0
    
    var totalCount: Int { uploadingVideos.count }
    var onUploadFinished: (() -> Void)?

    private var uploadTasks: [String: Task<Void, Never>] = [:]

    func addUploadingVideos(_ assets: [PHAsset], thumbnails: [String: UIImage]) {
        totalToUpload = assets.count // <- set this once
        for asset in assets {
            let id = asset.localIdentifier
            let thumbnail = thumbnails[id] ?? UIImage(systemName: "video")!
            let uploadingVideo = UploadingVideo(localIdentifier: id, thumbnail: thumbnail, isUploading: true)
            uploadingVideos.append(uploadingVideo)
        }
    }

    func startUpload(for asset: PHAsset, using uploadClosure: @escaping () async -> Void) {
        let id = asset.localIdentifier
        let task = Task {
            await uploadClosure()
        }
        uploadTasks[id] = task
    }

    func cancelUpload(for localIdentifier: String) {
        uploadTasks[localIdentifier]?.cancel()
        uploadTasks.removeValue(forKey: localIdentifier)
        uploadingVideos.removeAll { $0.localIdentifier == localIdentifier }
    }

    func markUploaded(_ id: String) {
        guard let index = uploadingVideos.firstIndex(where: { $0.localIdentifier == id }) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.uploadingVideos.removeAll { $0.localIdentifier == id }
            self.uploadTasks.removeValue(forKey: id)
            self.completedCount += 1

            // Trigger refresh
            self.onUploadFinished?()

            // If this was the last upload, schedule a cleanup/reset
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
        uploadingVideos.removeAll()
        totalToUpload = 0
        completedCount = 0
    }

}
