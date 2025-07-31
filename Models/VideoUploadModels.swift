//
//  VideoUploadService.swift
//  LiNGUiD
//
//  Created by Gerardo De La Torre on 6/24/25.
//

import Foundation
import UIKit

// MARK: - API Response Models

/// Response from the Python upload API
struct VideoUploadResponse: Codable {
    let success: Bool
    let level: Int
    let transcript: String
    let captions: [CaptionSegment]
    let keywords: [String]
    let language: String
    let videoUrl: String
    let thumbnailUrl: String?
    let documentId: String
    
    enum CodingKeys: String, CodingKey {
        case success, level, transcript, captions, keywords, language
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case documentId = "document_id"
    }
}

/// Individual caption segment with timing
struct CaptionSegment: Codable, Identifiable {
    let id = UUID()
    let text: String
    let start: Double
    let end: Double
    let words: [WordTiming]?
    
    enum CodingKeys: String, CodingKey {
        case text, start, end, words
    }
}

/// Word-level timing information
struct WordTiming: Codable, Identifiable {
    let id = UUID()
    let word: String
    let start: Double
    let end: Double
    let probability: Double
    
    enum CodingKeys: String, CodingKey {
        case word, start, end, probability
    }
}

// MARK: - Error Handling

/// Error response from the API
struct VideoUploadError: Codable, Error {
    let message: String
    let code: String?
    let details: String?
    
    var localizedDescription: String {
        return message
    }
}

// MARK: - Request Models

/// Upload request parameters
struct VideoUploadRequest {
    let videoData: Data
    let thumbnailData: Data?
    let language: String
    let category: String
    let topics: [String]
    let level: String
    let uploaderId: String?
    let filename: String
    
    /// Convert topics array to JSON string for API
    var topicsJSON: String {
        guard let data = try? JSONEncoder().encode(topics),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

// MARK: - Progress Tracking

/// Upload progress information
struct UploadProgress {
    let bytesUploaded: Int64
    let totalBytes: Int64
    let phase: UploadPhase
    let message: String
    
    var progress: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(bytesUploaded) / Double(totalBytes)
    }
}

/// Different phases of the upload process
enum UploadPhase: String, CaseIterable {
    case preparing = "Preparing upload..."
    case uploading = "Uploading video..."
    case processing = "Processing video..."
    case transcribing = "Transcribing audio..."
    case analyzing = "Analyzing language..."
    case finalizing = "Finalizing..."
    case completed = "Upload complete!"
    case failed = "Upload failed"
}

// MARK: - Convenience Extensions

extension VideoUploadResponse {
    /// Convert API response to your existing Video model (if needed)
    func toVideoMetadata(uploader: String) -> [String: Any] {
        return [
            "id": documentId,
            "level": level,
            "uploader": uploader,
            "timestamp": Date(),
            "transcript": transcript,
            "captions": captions.map { caption in
                [
                    "text": caption.text,
                    "start": caption.start,
                    "end": caption.end,
                    "words": caption.words?.map { word in
                        [
                            "word": word.word,
                            "start": word.start,
                            "end": word.end,
                            "probability": word.probability
                        ]
                    } ?? []
                ]
            },
            "keywords": keywords,
            "likes": 0,
            "comments": 0,
            "plays": 0,
            "shares": 0,
            "saves": 0,
            "watchTime": 0.0,
            "language": language,
            "videoUrl": videoUrl,
            "thumbnailUrl": thumbnailUrl ?? ""
        ]
    }
}

// MARK: - Uploading Video Model

/// Represents a video currently being uploaded, with progress tracking
struct UploadingVideo: Identifiable, Equatable {
    let id: String // local identifier or uploadId
    let thumbnail: UIImage
    let uploadId: String // Used to poll backend progress
    var progress: Double // 0.0 to 1.0 (or 0 to 100 if you prefer)
    var isUploading: Bool
    var filename: String
    // Optionally, add more fields as needed (e.g., local file URL)
    
    static func == (lhs: UploadingVideo, rhs: UploadingVideo) -> Bool {
        lhs.id == rhs.id
    }
}