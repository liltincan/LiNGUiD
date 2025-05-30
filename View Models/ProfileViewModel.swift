import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation

class ProfileViewModel: ObservableObject {
    @Published var user: String = ""
    @Published var language: String = ""
    @Published var lvl: String = ""
    @Published var videoCount: String = ""
    @Published var inputAmt: String = ""
    @Published var followerCount: String = ""
    @Published var videos: [String] = []
    @Published var videoThumbnails: [String] = []
    @Published var profilePicture: String = ""
    @Published var dataReady: Bool = false
    @Published var likedVideoThumbnails: [String] = []
    @Published var savedVideoThumbnails: [String] = []
    var likedVideos: [String] = []
    var savedVideos: [String] = []


    func fetchData(uid: String) {
        
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            guard let self = self else { return } // Safely handle self in closure

            guard let data = document?.data(), document?.exists == true else {
                print("User document not found or error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.dataReady = true
                }
                return
            }

            DispatchQueue.main.async {
                self.user = data["username"] as? String ?? ""
                self.user = data["userName"] as? String ?? ""

                if let languagesData = data["languagesData"] as? [String: Any],
                   let languageName = languagesData.keys.first {
                    self.language = String(languageName.prefix(2))
                    if let langData = languagesData[languageName] as? [String: Any],
                       let comprehensionLevel = langData["comprehensionLevel"] as? Int {
                        self.lvl = String(comprehensionLevel)
                    } else {
                        self.lvl = ""
                    }
                } else {
                    self.language = ""
                    self.lvl = ""
                }

                if let watchedVideos = data["watchedVideos"] as? [String] {
                    self.videoCount = String(watchedVideos.count)
                } else {
                    self.videoCount = "0"
                }

                self.inputAmt = String(Int(data["globalWatchTime"] as? Double ?? 0))

                if let followerCount = data["followers"] as? [String] {
                    self.followerCount = String(followerCount.count)
                } else {
                    self.followerCount = "0"
                }

                if var uploadedVideos = data["uploadedVideos"] as? [String] {
                    uploadedVideos = uploadedVideos.map {
                        $0.replacingOccurrences(of: "en/", with: "english/")
                            .replacingOccurrences(of: "fr/", with: "french/")
                            .replacingOccurrences(of: "ru/", with: "russian/")
                            .replacingOccurrences(of: "es/", with: "spanish/")
                    }
                    self.videos = uploadedVideos
                    self.fetchUploadThumbnails(for: uploadedVideos)
                } else {
                    self.videos = []
                    self.videoThumbnails = []
                    self.dataReady = true
                }

                self.profilePicture = data["profilePhotoUrl"] as? String ?? ""
                
                if let likedVideos = data["likedVideos"] as? [String] {
                    self.likedVideos = likedVideos
                } else{
                    self.likedVideos = []
                }
                let likedVideoArray = self.likedVideos
                self.fetchLikedThumbnails(uid: uid, videoArray: likedVideoArray)
                
                if let likedVideos = data["likedVideos"] as? [String] {
                    self.savedVideos = likedVideos
                } else{
                    self.savedVideos = []
                }
                let savedVideoArray = self.likedVideos
                self.fetchLikedThumbnails(uid: uid, videoArray: savedVideoArray)
            }
        }
    }

    private func fetchUploadThumbnails(for videoPaths: [String]) {
        var thumbnails = Array(repeating: "", count: videoPaths.count)
        let group = DispatchGroup()

        // Handle case with no videos
        guard !videoPaths.isEmpty else {
            DispatchQueue.main.async {
                self.videoThumbnails = []
                self.dataReady = true
            }
            return
        }

        for (index, path) in videoPaths.enumerated() {
            let components = path.split(separator: "/")

            guard components.count == 3 else {
                print("Invalid path format: \(path) - Skipping thumbnail fetch.")
                continue
            }

            let lang = String(components[0])
            let docId = String(components[2])
            group.enter()

            Firestore.firestore()
                .collection("videos")
                .document(lang)
                .collection("items")
                .document(docId)
                .getDocument { document, error in
                    defer { group.leave() }

                    if let error = error {
                        print("Error fetching thumbnail for \(path):", error.localizedDescription)
                        return
                    }

                    guard let document = document, document.exists, let data = document.data() else {
                        print("Thumbnail document missing or no data for \(path)")
                        return
                    }

                    if let url = data["thumbnail_url"] as? String {
                        thumbnails[index] = url
                    } else {
                        print("Missing or invalid thumbnail_url for \(path)")
                    }
                }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.videoThumbnails = thumbnails
            self.dataReady = true
        }
    }
    
    private func fetchLikedThumbnails(uid: String, videoArray: [String]) {
//        let storage = Storage.storage()
//        let rootRef = storage.reference().child("thumbnails").child(uid)
//        var results: [String] = []
//
//        let group = DispatchGroup()
//
//        for videoID in videoArray {
//            let videoFolderRef = rootRef.child(videoID)
//            group.enter()
//            
//            videoFolderRef.listAll { res, err in
//                defer { group.leave() }
//
//                guard err == nil else {
//                    print("Error listing items for \(videoID): \(err!.localizedDescription)")
//                    return
//                }
//
//                if let jpgRef = res!.items.first {
//                    jpgRef.downloadURL { url, err in
//                        if let url = url {
//                            results.append(url.absoluteString)
//                        } else {
//                            print("Error getting download URL for \(jpgRef.fullPath): \(err?.localizedDescription ?? "Unknown error")")
//                        }
//                    }
//                } else {
//                    print("No .jpg found in folder \(videoID)")
//                }
//            }
//        }
//
//        group.notify(queue: .main) {
//            self.likedVideoThumbnails = results
//        }
    }
}
