//
//  BackgroundUploader.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 8/9/25.
//

import Foundation
import UIKit
import Combine

final class BackgroundUploader: NSObject, ObservableObject {
    static let shared = BackgroundUploader()

    static let progressNote = Notification.Name("BGUploadProgress")
    static let finishedNote  = Notification.Name("BGUploadFinished")

    // Live per-item progress (0…1)
    @Published private(set) var progressById: [String: Double] = [:]

    // NEW: queue state so UI can compute steps without UploadManager
    @Published private(set) var enqueuedIds: [String] = []      // in order
    @Published private(set) var activeId: String?               // current uploading id
    @Published private(set) var completedIds: Set<String> = []  // finished ids

    // NEW: convenience computed values for the bar
    var totalToUpload: Int { enqueuedIds.count }
    var completedCount: Int { completedIds.count }
    var isUploadComplete: Bool { totalToUpload > 0 && completedCount == totalToUpload }

    /// 0…1 for the current item (holds at 1 when complete so bar stays full briefly)
    var barProgressNormalized: Double {
        if isUploadComplete { return 1 }
        guard let id = activeId else { return 0 }
        return progressById[id] ?? 0
    }

    private let sessionId = "com.linguid.video.background.session"
    private var session: URLSession!
    private var systemCompletionHandler: (() -> Void)?

    private var pending: [URLSessionUploadTask] = []
    private var active: URLSessionUploadTask?

    private override init() {
        super.init()
        session = makeSession()
    }

    func recreateSessionIfNeeded(identifier: String) {
        guard identifier == sessionId else { return }
        if session == nil {
            session = makeSession()
        }
    }

    func setSystemCompletionHandler(_ handler: @escaping () -> Void) {
        systemCompletionHandler = handler
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: sessionId)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.httpMaximumConnectionsPerHost = 1 // sequential
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    struct PayloadMeta: Codable {
        let localIdentifier: String
        let filename: String
        let category: String
        let language: String
        let uploaderId: String?
        let multipartPath: String
    }

    // MARK: - Public API

    func enqueue(
        videoFileURL: URL,
        thumbnailJPEG: Data?,
        filename: String,
        category: String,
        language: String,
        uploaderId: String?,
        localIdentifier: String
    ) throws {
        let request = try buildRequest()
        let multipartURL = try writeMultipartToDisk(
            videoFileURL: videoFileURL,
            thumbnailJPEG: thumbnailJPEG,
            filename: filename,
            category: category,
            language: language,
            uploaderId: uploaderId
        )

        var task = session.uploadTask(with: request, fromFile: multipartURL)

        let meta = PayloadMeta(
            localIdentifier: localIdentifier,
            filename: filename,
            category: category,
            language: language,
            uploaderId: uploaderId,
            multipartPath: multipartURL.path
        )
        let metaData = try JSONEncoder().encode(meta)
        task.taskDescription = String(data: metaData, encoding: .utf8)

        // NEW: seed UI state
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.enqueuedIds.contains(localIdentifier) {
                self.enqueuedIds.append(localIdentifier)
            }
            self.progressById[localIdentifier] = 0
        }

        pending.append(task)
        kickstartIfIdle()
    }

    func percent(for localIdentifier: String) -> Double {
        (progressById[localIdentifier] ?? 0) * 100
    }

    // MARK: - Internals

    private func kickstartIfIdle() {
        guard active == nil, !pending.isEmpty else { return }
        active = pending.removeFirst()
        if
            let metaJSON = active?.taskDescription?.data(using: .utf8),
            let meta = try? JSONDecoder().decode(PayloadMeta.self, from: metaJSON)
        {
            DispatchQueue.main.async { [weak self] in
                self?.activeId = meta.localIdentifier     // NEW: tell UI which one is running
            }
        }
        active?.resume()
    }

    private func buildRequest() throws -> URLRequest {
        guard let url = URL(string: "https://makechicken.onrender.com/api/upload_video") else {
            throw NSError(domain: "BGUploader", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return req
    }

    private let boundary = "Boundary-\(UUID().uuidString)"

    private func writeMultipartToDisk(
        videoFileURL: URL,
        thumbnailJPEG: Data?,
        filename: String,
        category: String,
        language: String,
        uploaderId: String?
    ) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("multipart")
        var data = Data()

        func append(_ s: String) { data.append(s.data(using: .utf8)!) }
        func addText(name: String, value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        addText(name: "category", value: category)
        addText(name: "language", value: language)
        if let uploaderId { addText(name: "uploader_id", value: uploaderId) }
        addText(name: "topics", value: "[]")
        addText(name: "level", value: "auto")

        if let thumb = thumbnailJPEG {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"thumbnail\"; filename=\"thumb.jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            data.append(thumb)
            append("\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: video/mp4\r\n\r\n")
        let fh = try FileHandle(forReadingFrom: videoFileURL)
        if let chunk = try? fh.readToEnd() { data.append(chunk) }
        try? fh.close()
        append("\r\n")
        append("--\(boundary)--\r\n")

        try data.write(to: tmp, options: .atomic)
        return tmp
    }
    
    @MainActor
    func clearFinishedBatchVisuals() {
        // Only clear if nothing is uploading anymore
        guard isUploadComplete else { return }
        enqueuedIds.removeAll()
        completedIds.removeAll()
        progressById.removeAll()
        activeId = nil
    }
}

// MARK: - URLSession Delegates
extension BackgroundUploader: URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard
            totalBytesExpectedToSend > 0,
            let metaJSON = task.taskDescription?.data(using: .utf8),
            let meta = try? JSONDecoder().decode(PayloadMeta.self, from: metaJSON)
        else { return }

        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)

        // Legacy broadcast (optional)
        NotificationCenter.default.post(
            name: BackgroundUploader.progressNote,
            object: nil,
            userInfo: ["localIdentifier": meta.localIdentifier, "progress": progress]
        )

        // Update published progress
        DispatchQueue.main.async { [weak self] in
            self?.progressById[meta.localIdentifier] = progress
            // keep activeId accurate even if the system reorders callbacks
            if self?.activeId != meta.localIdentifier {
                self?.activeId = meta.localIdentifier
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        defer {
            if
                let metaJSON = task.taskDescription?.data(using: .utf8),
                let meta = try? JSONDecoder().decode(PayloadMeta.self, from: metaJSON) {
                try? FileManager.default.removeItem(atPath: meta.multipartPath)
            }
        }

        guard
            let metaJSON = task.taskDescription?.data(using: .utf8),
            let meta = try? JSONDecoder().decode(PayloadMeta.self, from: metaJSON)
        else { return }

        NotificationCenter.default.post(
            name: BackgroundUploader.finishedNote,
            object: nil,
            userInfo: ["localIdentifier": meta.localIdentifier, "error": error as NSError? as Any]
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if error == nil {
                self.progressById[meta.localIdentifier] = 1
                self.completedIds.insert(meta.localIdentifier)
            }
            // advance queue
            if self.active?.taskIdentifier == task.taskIdentifier {
                self.active = nil
                self.activeId = nil
                self.kickstartIfIdle()
            }

            // Optional: when the whole batch is done, you can clear after a delay
            // if self.isUploadComplete {
            //   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //     self.enqueuedIds.removeAll()
            //     self.completedIds.removeAll()
            //     self.progressById.removeAll()
            //   }
            // }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [weak self] in
            self?.systemCompletionHandler?()
            self?.systemCompletionHandler = nil
        }
    }
}
