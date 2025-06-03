import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation

class ProfileViewModel: ObservableObject {
    @Published var user: String = ""
    @Published var language: String = "" // Primary language
    @Published var lvl: String = ""
    @Published var videoCount: String = ""
    @Published var inputAmt: String = ""
    @Published var followerCount: String = ""
    @Published var videos: [String] = []
    @Published var videoThumbnails: [String] = []
    @Published var videoURLs: [String] = []
    @Published var profilePicture: String = ""
    @Published var dataReady: Bool = false
    @Published var likedVideoThumbnails: [String] = []
    @Published var savedVideoThumbnails: [String] = []
    @Published var allLanguageNames: [String] = []
    @Published var allLanguagesData: [String: [String: Any]] = [:] // Full language data

    var likedVideos: [String] = []
    var savedVideos: [String] = []

    // Computed property for formatted language display
    var formattedLanguagesDisplay: String {
        guard !allLanguagesData.isEmpty else {
            return "No languages selected"
        }

        let displayStrings: [String] = allLanguageNames.compactMap { languageName in
            guard let langData = allLanguagesData[languageName],
                  let comprehensionLevel = langData["comprehensionLevel"] as? Int else {
                return nil
            }
            let languageCode = String(languageName.prefix(2))
            return "\(languageCode) (Lvl \(comprehensionLevel))"
        }

        return "En → " + displayStrings.joined(separator: ", ")
    }

    func fetchData(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            guard let self = self else { return }

            guard let data = document?.data(), document?.exists == true else {
                print("User document not found or error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.dataReady = true
                }
                return
            }

            DispatchQueue.main.async {
                self.user = data["username"] as? String ?? ""
                self.setupLanguageData(from: data)
                self.videoCount = String((data["watchedVideos"] as? [String])?.count ?? 0)
                self.inputAmt = String(Int(data["globalWatchTime"] as? Double ?? 0))
                self.followerCount = String((data["followers"] as? [String])?.count ?? 0)
                self.setupUploadedVideos(from: data)
                self.profilePicture = data["profilePhotoUrl"] as? String ?? ""
                self.setupLikedAndSavedVideos(from: data, uid: uid)
            }
        }
    }

    private func setupLanguageData(from data: [String: Any]) {
        if let languagesData = data["languagesData"] as? [String: [String: Any]] {
            allLanguagesData = languagesData
            allLanguageNames = Array(languagesData.keys).sorted()

            if let firstLanguageName = languagesData.keys.first,
               let langData = languagesData[firstLanguageName],
               let comprehensionLevel = langData["comprehensionLevel"] as? Int {
                language = String(firstLanguageName.prefix(2))
                lvl = String(comprehensionLevel)
            } else {
                language = ""
                lvl = ""
            }
        } else {
            language = ""
            lvl = ""
            allLanguageNames = []
            allLanguagesData = [:]
        }
    }

    private func setupUploadedVideos(from data: [String: Any]) {
        if var uploadedVideos = data["uploadedVideos"] as? [String] {
            uploadedVideos = uploadedVideos.map {
                $0.replacingOccurrences(of: "en/", with: "english/")
                    .replacingOccurrences(of: "fr/", with: "french/")
                    .replacingOccurrences(of: "ru/", with: "russian/")
                    .replacingOccurrences(of: "es/", with: "spanish/")
            }
            videos = uploadedVideos
            fetchUploadThumbnails(for: uploadedVideos)
        } else {
            videos = []
            videoThumbnails = []
            dataReady = true
        }
    }

    private func setupLikedAndSavedVideos(from data: [String: Any], uid: String) {
        likedVideos = data["likedVideos"] as? [String] ?? []
        fetchLikedThumbnails(uid: uid, videoArray: likedVideos)

        savedVideos = data["savedVideos"] as? [String] ?? []
        fetchLikedThumbnails(uid: uid, videoArray: savedVideos)
    }

    private func fetchUploadThumbnails(for videoPaths: [String]) {
        guard !videoPaths.isEmpty else {
            DispatchQueue.main.async {
                self.videoThumbnails = []
                self.dataReady = true
            }
            return
        }

        var thumbnails = Array(repeating: "", count: videoPaths.count)
        var videos = Array(repeating: "", count: videoPaths.count)
        let group = DispatchGroup()

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

                    if let url = data["video_url"] as? String {
                        videos[index] = url
                    } else {
                        print("Missing or invalid video_url for \(path)")
                    }
                }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.videoThumbnails = thumbnails
            self.videoURLs = videos
            self.dataReady = true
        }
    }

    private func fetchLikedThumbnails(uid: String, videoArray: [String]) {
        // Add your implementation here when ready
    }
}
