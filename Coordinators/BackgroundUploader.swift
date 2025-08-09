//
//  BackgroundUploader.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 8/9/25.
//

import Foundation
import UIKit

final class BackgroundUploader: NSObject {
    static let shared = BackgroundUploader()

    // Notifications your UI can observe
    static let progressNote = Notification.Name("BGUploadProgress")
    static let finishedNote = Notification.Name("BGUploadFinished")

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
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    struct PayloadMeta: Codable {
        let localIdentifier: String       // PHAsset.localIdentifier (for your UI list)
        let filename: String
        let category: String
        let language: String
        let uploaderId: String?
        let multipartPath: String         // temp file path we created
    }

    /// Public entry: create multipart file on disk + start upload task
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

        // stash metadata for progress/rehydration
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

        // queue, don't start yet
        pending.append(task)
        kickstartIfIdle()
    }

    private func kickstartIfIdle() {
        guard active == nil, !pending.isEmpty else { return }
        active = pending.removeFirst()
        active?.resume()
    }

    // MARK: - Helpers

    private func buildRequest() throws -> URLRequest {
        guard let url = URL(string: "https://makechicken.onrender.com/api/upload_video") else {
            throw NSError(domain: "BGUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        // Content-Type for multipart will be set inside file body; here we duplicate the same boundary
        // but servers are fine as long as the body is correct. We'll set header exactly to match the body boundary:
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
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("multipart")
        var data = Data()

        func append(_ string: String) {
            data.append(string.data(using: .utf8)!)
        }

        // text field
        func addText(name: String, value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        addText(name: "category", value: category)
        addText(name: "language", value: language)
        if let uploaderId { addText(name: "uploader_id", value: uploaderId) }

        // Optional: keep API happy with defaults
        addText(name: "topics", value: "[]")
        addText(name: "level", value: "auto")

        // thumbnail (optional)
        if let thumb = thumbnailJPEG {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"thumbnail\"; filename=\"thumb.jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            data.append(thumb)
            append("\r\n")
        }

        // video file  **IMPORTANT: name must be "file"**
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
}

// MARK: - URLSessionDelegate
extension BackgroundUploader: URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {

    // Progress
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        print("[BG] progress \(totalBytesSent)/\(totalBytesExpectedToSend)")
        guard
            let metaJSON = task.taskDescription?.data(using: .utf8),
            let meta = try? JSONDecoder().decode(PayloadMeta.self, from: metaJSON)
        else { return }

        let progress = totalBytesExpectedToSend > 0 ? Double(totalBytesSent) / Double(totalBytesExpectedToSend) : 0
        NotificationCenter.default.post(
            name: BackgroundUploader.progressNote,
            object: nil,
            userInfo: [
                "localIdentifier": meta.localIdentifier,
                "progress": progress
            ]
        )
    }

    // Finish (success or error)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("[BG] didComplete \(task.taskIdentifier). error:", error as Any)
        defer {
            // Cleanup multipart temp file
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
            userInfo: [
                "localIdentifier": meta.localIdentifier,
                "error": error as NSError? as Any
            ]
        )
        if active?.taskIdentifier == task.taskIdentifier {
            active = nil
            kickstartIfIdle()
        }
    }

    // System wakes us when all background events for this session have been delivered
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("[BG] urlSessionDidFinishEvents")
        DispatchQueue.main.async { [weak self] in
            self?.systemCompletionHandler?()
            self?.systemCompletionHandler = nil
        }
    }
}
