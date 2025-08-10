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

    var totalToUpload: Int { enqueuedIds.count }
    var completedCount: Int { completedIds.count }
    var isUploadComplete: Bool { totalToUpload > 0 && completedCount == totalToUpload }

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
        // Decode task metadata once; keep it for cleanup + notifications
        var meta: PayloadMeta? = nil
        if let data = task.taskDescription?.data(using: .utf8) {
            meta = try? JSONDecoder().decode(PayloadMeta.self, from: data)
        }

        // Always clean up the multipart temp file (if we know it)
        if let m = meta {
            try? FileManager.default.removeItem(atPath: m.multipartPath)
        }

        // If we have metadata, notify listeners (optional but preserves your current behavior)
        if let m = meta {
            NotificationCenter.default.post(
                name: BackgroundUploader.finishedNote,
                object: nil,
                userInfo: ["localIdentifier": m.localIdentifier, "error": error as NSError? as Any]
            )
        }

        // Update UI state on main
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let m = meta {
                let nsErr = error as NSError?

                if nsErr == nil {
                    self.progressById[m.localIdentifier] = 1
                    self.completedIds.insert(m.localIdentifier)
                }
                else if nsErr?.domain == NSURLErrorDomain && nsErr?.code == NSURLErrorCancelled {
                    self.progressById.removeValue(forKey: m.localIdentifier)
                    self.enqueuedIds.removeAll { $0 == m.localIdentifier }
                }
                else {
                    self.progressById.removeValue(forKey: m.localIdentifier)
                }
            }

            // Advance the queue if this task was the active one
            if self.active?.taskIdentifier == task.taskIdentifier {
                self.active = nil
                self.activeId = nil
                self.kickstartIfIdle()
            }
        }
    }


    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [weak self] in
            self?.systemCompletionHandler?()
            self?.systemCompletionHandler = nil
        }
    }
}

extension BackgroundUploader {
    @MainActor
    func cancelUpload(id: String) {
        // cancel pending task if found
        if let i = pending.firstIndex(where: { decodeMeta(for: $0)?.localIdentifier == id }) {
            let task = pending.remove(at: i)
            task.cancel()
        }
        // cancel active task if it's the one
        else if let a = active, decodeMeta(for: a)?.localIdentifier == id {
            a.cancel()
            active = nil
            activeId = nil
        }

        // Shrink the batch size: treat cancelled as removed from the plan
        enqueuedIds.removeAll { $0 == id }
        progressById.removeValue(forKey: id)
        completedIds.remove(id) // in case it was accidentally marked

        // Move on if needed
        kickstartIfIdle()
    }

    @MainActor
    func cancelAll() {
        pending.forEach { $0.cancel() }
        pending.removeAll()

        active?.cancel()
        active = nil
        activeId = nil

        enqueuedIds.removeAll()
        completedIds.removeAll()
        progressById.removeAll()
    }

    // Decode helper for matching tasks to ids
    fileprivate func decodeMeta(for task: URLSessionTask) -> PayloadMeta? {
        guard let data = task.taskDescription?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PayloadMeta.self, from: data)
    }
}

