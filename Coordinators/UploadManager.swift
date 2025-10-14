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
        var progress: Double = 0
        var filename: String = ""
    }
    
    @Published var totalToUpload: Int = 0
    @Published var completedCount: Int = 0
    @Published var uploadingVideos: [UploadingVideo] = []
    @Published var currentIndex: Int = 0
    
    var totalCount: Int { uploadingVideos.count }
    var onUploadFinished: (() -> Void)?

    private var uploadTasks: [String: Task<Void, Never>] = [:]

    init() {
        NotificationCenter.default.addObserver(
            forName: BackgroundUploader.finishedNote,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let localId = note.userInfo?["localIdentifier"] as? String else { return }

            let ok = (note.userInfo?["ok"] as? Bool) ?? {
                let status = note.userInfo?["statusCode"] as? Int ?? 0
                let err = note.userInfo?["error"] as? NSError
                return (200..<300).contains(status) && err == nil
            }()

            if ok {
                self.markUploaded(localId)
            } else {
                self.handleUploadFailed(localId)
            }
        }

//        NotificationCenter.default.addObserver(
//            forName: BackgroundUploader.finishedNote,
//            object: nil,
//            queue: .main
//        ) { [weak self] note in
//            guard let localId = note.userInfo?["localIdentifier"] as? String else { return }
//            self?.markUploaded(localId)
//        }
    }

    func addUploadingVideos(_ assets: [PHAsset], thumbnails: [String: UIImage]) {
        totalToUpload = assets.count
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
        uploadingVideos.removeAll()
        totalToUpload = 0
        completedCount = 0
    }

    @MainActor
    func removeUploadingVideo(id: String) {
        if let i = uploadingVideos.firstIndex(where: { $0.localIdentifier == id }) {
            uploadingVideos.remove(at: i)
            objectWillChange.send()
        }
    }
    
    @MainActor
    private func handleUploadFailed(_ id: String) {
        uploadingVideos.removeAll { $0.localIdentifier == id }
        if totalToUpload > 0 { totalToUpload -= 1 }

        if completedCount == totalToUpload {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.reset()
            }
        }
    }

}
extension UploadManager {
    var progress: Double {
        guard totalToUpload > 0 else { return 0 }

        let totalSteps = totalToUpload + 1
        let currentStep = min(completedCount + 1, totalSteps)

        return Double(currentStep) / Double(totalSteps)
    }

    var isUploadComplete: Bool {
        completedCount == totalToUpload
    }
}

