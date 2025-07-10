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

    @Published var uploadingVideos: [UploadingVideo] = []
    @Published var currentIndex: Int = 0
    var totalCount: Int { uploadingVideos.count }

    private var uploadTasks: [String: Task<Void, Never>] = [:]

    func addUploadingVideos(_ assets: [PHAsset], thumbnails: [String: UIImage]) {
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
        if let index = uploadingVideos.firstIndex(where: { $0.localIdentifier == id }) {
            uploadingVideos[index].isUploading = false
        }
        uploadTasks.removeValue(forKey: id)
    }

    func reset() {
        uploadTasks.values.forEach { $0.cancel() }
        uploadTasks.removeAll()
        uploadingVideos.removeAll()
    }
}
