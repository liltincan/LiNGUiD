//
//  VideoUploadService.swift
//  LiNGUiD
//
//  Created by Gerardo De La Torre on 6/24/25.
//

import Foundation

// MARK: - Main Upload Response Model
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

// MARK: - Caption Segment Model
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

// MARK: - Word Timing Model
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

// MARK: - Simplified Video Model for Storage
struct UploadedVideo: Codable, Identifiable {
    let id: String
    let level: Int
    let uploader: String
    let timestamp: Date
    let transcript: String
    let captions: [CaptionSegment]
    let keywords: [String]
    let likes: Int
    let comments: Int
    let plays: Int
    let shares: Int
    let saves: Int
    let watchTime: Double
    let language: String
    let videoUrl: String
    let thumbnailUrl: String?
    
    // Firebase field mappings
    enum CodingKeys: String, CodingKey {
        case id, level, uploader, timestamp, transcript, captions, keywords
        case likes, comments, plays, shares, saves, language
        case watchTime = "watch_time"
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
    }
    
    // Initialize from upload response
    init(from response: VideoUploadResponse, uploader: String) {
        self.id = response.documentId
        self.level = response.level
        self.uploader = uploader
        self.timestamp = Date()
        self.transcript = response.transcript
        self.captions = response.captions
        self.keywords = response.keywords
        self.likes = 0
        self.comments = 0
        self.plays = 0
        self.shares = 0
        self.saves = 0
        self.watchTime = 0.0
        self.language = response.language
        self.videoUrl = response.videoUrl
        self.thumbnailUrl = response.thumbnailUrl
    }
}

// MARK: - Upload Request Model
struct VideoUploadRequest {
    let videoData: Data
    let thumbnailData: Data?
    let language: String
    let category: String
    let topics: [String]
    let level: String
    let uploaderId: String?
    let filename: String
    
    // Convert topics array to JSON string for form data
    var topicsJSON: String {
        guard let data = try? JSONEncoder().encode(topics),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

// MARK: - Upload Progress Model
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

// MARK: - Upload Error Model
struct VideoUploadError: Codable, Error {
    let message: String
    let code: String?
    let details: String?
    
    var localizedDescription: String {
        return message
    }
}

// MARK: - Language Support Models
struct SupportedLanguage: Codable, Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let calibration: String
    
    enum CodingKeys: String, CodingKey {
        case code, name, calibration
    }
}

struct CEFRLevel: Codable, Identifiable {
    let id = UUID()
    let numeric: Int
    let cefr: String
    let name: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case numeric, cefr, name, description
    }
}

// MARK: - Video Upload Service
class VideoUploadService {
    
    // MARK: - Properties
    private let baseURL = "https://makechicken.onrender.com"
    
    // MARK: - Core Upload Function
    func uploadVideo(
        videoData: Data,
        filename: String,
        category: String,
        language: String = "auto",
        uploaderId: String? = nil
    ) async throws -> VideoUploadResponse {
        
        print("Starting upload to: \(baseURL)/api/upload_video")
        print("File: \(filename), Category: \(category)")
        
        // Step 1: Create the URL
        guard let url = URL(string: "\(baseURL)/api/upload_video") else {
            throw VideoUploadError(message: "Invalid URL", code: "invalid_url", details: nil)
        }
        
        // Step 2: Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Step 3: Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Step 4: Build the body
        let httpBody = createMultipartBody(
            boundary: boundary,
            videoData: videoData,
            filename: filename,
            category: category,
            language: language,
            uploaderId: uploaderId
        )
        
        request.httpBody = httpBody
        
        print("Request size: \(httpBody.count) bytes")
        
        // Step 5: Send the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Step 6: Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                    print("❌ Error response: \(responseString)")
                    throw VideoUploadError(
                        message: "HTTP \(httpResponse.statusCode)",
                        code: "http_error",
                        details: responseString
                    )
                }
            }
            
            // Step 7: Parse the response
            print("Received response, parsing...")
            let responseString = String(data: data, encoding: .utf8) ?? "No data"
            print("Response: \(responseString)")
            
            let uploadResponse = try JSONDecoder().decode(VideoUploadResponse.self, from: data)
            print("Upload successful! Level: \(uploadResponse.level)")
            
            return uploadResponse
            
        } catch {
            print("Upload failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Function to Create Multipart Body
    private func createMultipartBody(
        boundary: String,
        videoData: Data,
        filename: String,
        category: String,
        language: String,
        uploaderId: String?
    ) -> Data {
        
        var body = Data()
        
        // Helper to add text field
        func addTextField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Helper to add file field
        func addFileField(name: String, filename: String, mimeType: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add required file field
        addFileField(name: "file", filename: filename, mimeType: "video/mp4", data: videoData)
        
        // Add required category field
        addTextField(name: "category", value: category)
        
        // Add optional fields
        if language != "auto" && !language.isEmpty {
            addTextField(name: "language", value: language)
        }
        
        if let uploaderId = uploaderId, !uploaderId.isEmpty {
            addTextField(name: "uploader_id", value: uploaderId)
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        print("📝 Created multipart body with \(body.count) bytes")
        return body
    }
    
    // MARK: - Test Function
    func testConnection() async {
        print("Testing connection to API...")
        
        guard let url = URL(string: baseURL) else {
            print("Invalid base URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Base URL accessible, status: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
        } catch {
            print("Connection test failed: \(error)")
        }
    }
}
