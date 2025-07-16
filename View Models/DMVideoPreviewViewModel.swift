//
//  DMVideoPreviewViewModel.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 7/10/25.
//
//import Foundation
//import FirebaseFirestore
//
//
//class DMVideoPreviewViewModel: ObservableObject {
//    @Published var thumbnailURL: String?
//    @Published var videoURL: String?
//    @Published var language: String?
//    @Published var videoId: String?
//    
//    private let db = Firestore.firestore()
//    
//    func fetchVideoObjectFromPath(_ path: String) async -> Video? {
//        let components = path.split(separator: "/")
//        guard components.count == 3 else {
//            print("Invalid path format: \(path) - Skipping video fetch.")
//            return nil
//        }
//        
//        let lang = String(components[0])
//        let docId = String(components[2])
//        
//        do {
//            let document = try await db.collection("videos")
//                .document(lang)
//                .collection("items")
//                .document(docId)
//                .getDocument()
//            
//            guard document.exists, let data = document.data() else {
//                print("Video document missing or no data for \(path)")
//                return nil
//            }
//            
//            guard let urlString = data["video_url"] as? String,
//                  let url = URL(string: urlString),
//                  let title = data["title"] as? String,
//                  let likes = data["likes"] as? Int,
//                  let saves = data["saves"] as? Int,
//                  let language = data["language_detected"] as? String,
//                  let uploaderId = data["uploaderId"] as? String,
//                  let captionDicts = data["captions"] as? [[String: Any]] else {
//                print("Malformed video data for path: \(path)")
//                return nil
//            }
//            
//            let captions: [Captions] = captionDicts.compactMap { dict in
//                guard let start = dict["start"] as? Double,
//                      let end = dict["end"] as? Double,
//                      let text = dict["text"] as? String else {
//                    return nil
//                }
//                let words = dict["words"] as? [String]
//                return Captions(end: end, start: start, text: text, words: words)
//            }
//            
//            let detectedLevel = data["detected_level"] as? Int ?? 2
//            
//            return Video(
//                id: docId,
//                url: url,
//                captions: captions,
//                title: title,
//                detectedLevel: detectedLevel,
//                uploaderId: uploaderId,
//                likes: likes,
//                saves: saves,
//                language: language
//            )
//            
//        } catch {
//            print("Error fetching video object for \(path):", error.localizedDescription)
//            return nil
//        }
//    }
//    
//    private func fetchSingleVideoThumbnail(path: String, index: Int, thumbnails: inout [String], videoURLs: inout [String]) async {
//        let components = path.split(separator: "/")
//        guard components.count == 3 else {
//            print("Invalid path format: \(path)")
//            return
//        }
//        
//        let lang = String(components[0])
//        let docId = String(components[2])
//        
//        do {
//            let document = try await db.collection("videos")
//                .document(lang)
//                .collection("items")
//                .document(docId)
//                .getDocument()
//            
//            guard document.exists, let data = document.data() else {
//                print("No data for path \(path)")
//                return
//            }
//            
//            if let thumb = data["thumbnail_url"] as? String {
//                thumbnails[index] = thumb
//            }
//            if let url = data["video_url"] as? String {
//                videoURLs[index] = url
//            }
//        } catch {
//            print("Error fetching video: \(error.localizedDescription)")
//        }
//    }
//}
