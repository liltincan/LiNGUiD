import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation
import SwiftUICore

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var dataReady: Bool = false
    @Published var errorMessage: String?
    @Published var videoThumbnails: [String] = []
    @Published var videoURLs: [String] = []
    @Published var likedVideoThumbnails: [String] = []
    @Published var likedVideoURLs: [String] = []
    @Published var savedVideoThumbnails: [String] = []
    @Published var savedVideoURLs: [String] = []
    @Published var nativeLanguage: String? = nil
    @Published var country: String? = nil
    
    // New: Store complete Video objects
    @Published var uploadedVideoArray: [Video] = []
    @Published var likedVideoArray: [Video] = []
    @Published var savedVideoArray: [Video] = []
    
    private let db = Firestore.firestore()
    private let userSession: UserSessionViewModel
    private let videosCollection = "videos"
    
    init(userSession: UserSessionViewModel) {
        self.userSession = userSession
    }
    
    // MARK: - Computed Properties
    var userName: String {
        return user?.userName ?? ""
    }
    
    var primaryLanguage: String {
        guard let languagesData = user?.languagesData,
              let firstLanguageName = languagesData.keys.first else {
            return ""
        }
        return String(firstLanguageName.prefix(2))
    }
    
    var comprehensionLevel: String {
        guard let languagesData = user?.languagesData,
              let firstLanguageName = languagesData.keys.first,
              let langData = languagesData[firstLanguageName],
              let level = langData.comprehensionLevel else {
            return ""
        }
        return String(level)
    }
    
    var videoCount: String {
        return String(user?.uploadedVideos?.count ?? 0)
    }
    
    var inputAmount: String {
        let totalSeconds = user?.globalWatchTime ?? 0
        let totalMinutes = Int(totalSeconds / 60)  // Convert seconds to minutes
        return String(totalMinutes)
    }
    
    var followerCount: String {
        return String(user?.followers?.count ?? 0)
    }
    
    var profilePictureURL: String {
        return user?.profilePhotoUrl ?? ""
    }
    
    var nativeLanguageDisplay: String {
        print(user?.nativeLanguage?.capitalized ?? "")
        return user?.nativeLanguage?.capitalized ?? ""
    }
    
    var countryDisplay: String {
        // Get country directly from user model
        return user?.country?.capitalized ?? ""
    }
    
    var formattedLanguagesDisplay: String {
        if let languagesData = user?.languagesData {
            let nativeLanugage: String = user?.nativeLanguage?.capitalized ?? ""
            let targetLanugage: String = user?.targetLanguage.capitalized ?? languagesData.keys.first?.capitalized ?? ""
            let comprehensionLevel: Int = languagesData[targetLanugage.lowercased()]?.comprehensionLevel ?? 0
            
            // If we didn't find the level for target language, try the first available language
            if comprehensionLevel == 0, let firstLanguageKey = languagesData.keys.first {
                let fallbackLevel = languagesData[firstLanguageKey]?.comprehensionLevel ?? 0
                
                return "\(nativeLanugage) → " + " \(targetLanugage) (Lvl.\(fallbackLevel))"
            }
            
            return "\(nativeLanugage) → " + " \(targetLanugage) (Lvl.\(comprehensionLevel))"
        }
        
        return ""
    }
    
    var allLanguageNames: Set<String> {
        guard let languagesData = user?.languagesData else {
            return Set<String>()
        }
        return Set(languagesData.keys)
    }
    
    // MARK: - Data Fetching
    func fetchUserData() async {
        await userSession.refreshUser()
        
        guard let currentUser = userSession.currentUser else {
            await MainActor.run {
                self.errorMessage = "No user session found"
                self.dataReady = true
            }
            return
        }
        
        await MainActor.run {
            self.user = currentUser
            self.nativeLanguage = currentUser.nativeLanguage?.capitalized
            self.country = currentUser.country?.capitalized // Get country from user model
            self.errorMessage = nil
        }
        
        // Fetch both thumbnail data and complete video objects
        await fetchVideoThumbnails()
        await fetchLikedVideoThumbnails()
        await fetchSavedVideoThumbnails()
        
        await fetchUploadedVideoObjects()
        await fetchLikedVideoObjects()
        await fetchSavedVideoObjects()
        
        await MainActor.run {
            self.dataReady = true
        }
    }
    
    func fetchUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            guard document.exists else {
                await MainActor.run {
                    self.errorMessage = "User document not found"
                    self.dataReady = true
                }
                return
            }
            
            let fetchedUser = try document.data(as: User.self)
            
            await MainActor.run {
                self.user = fetchedUser
                self.nativeLanguage = fetchedUser.nativeLanguage?.capitalized
                self.country = fetchedUser.country?.capitalized // Get country from user model
                self.errorMessage = nil
            }
            
            // Fetch both thumbnail data and complete video objects
            await fetchVideoThumbnails()
            await fetchLikedVideoThumbnails()
            await fetchSavedVideoThumbnails()
            
            await fetchUploadedVideoObjects()
            await fetchLikedVideoObjects()
            await fetchSavedVideoObjects()
            
            await MainActor.run {
                self.dataReady = true
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
                self.dataReady = true
            }
        }
    }
    
    // MARK: - Update User Data
    func updateUser(_ updatedUser: User) async {
        guard let userId = updatedUser.id else {
            await MainActor.run {
                self.errorMessage = "User ID not found"
            }
            return
        }
        
        do {
            try db.collection("users").document(userId).setData(from: updatedUser, merge: true)
            
            await MainActor.run {
                self.user = updatedUser
                self.nativeLanguage = updatedUser.nativeLanguage?.capitalized
                self.country = updatedUser.country?.capitalized // Update country from user model
                self.errorMessage = nil
            }
            
            await userSession.refreshUser()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update user: \(error.localizedDescription)"
            }
        }
    }
    
    func updateLanguageData(_ languageKey: String, _ languageData: LanguagesData) async {
        guard var currentUser = user, let userId = currentUser.id else {
            await MainActor.run {
                self.errorMessage = "No user data available"
            }
            return
        }
        
        if currentUser.languagesData == nil {
            currentUser.languagesData = [:]
        }
        currentUser.languagesData?[languageKey] = languageData
        
        let patch = FirestoreUserPatch(languagesData: [languageKey: languageData])
        
        do {
            try db.collection("users").document(userId).setData(from: patch, merge: true)
            
            await MainActor.run {
                self.user = currentUser
                self.errorMessage = nil
            }
            
            await userSession.refreshUser()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update language data: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Video Operations
    func addUploadedVideo(_ videoPath: String) async {
        guard var currentUser = user, let userId = currentUser.id else { return }
        
        if currentUser.uploadedVideos == nil {
            currentUser.uploadedVideos = []
        }
        
        currentUser.uploadedVideos?.append(videoPath)
        await updateUser(currentUser)
        
        // Refresh video objects after adding
        await fetchUploadedVideoObjects()
    }
    
    func addLikedVideo(_ videoPath: String) async {
        guard var currentUser = user, let userId = currentUser.id else { return }
        
        if currentUser.likedVideos == nil {
            currentUser.likedVideos = []
        }
        
        if !currentUser.likedVideos!.contains(videoPath) {
            currentUser.likedVideos?.append(videoPath)
            await updateUser(currentUser)
            
            // Refresh video objects after adding
            await fetchLikedVideoObjects()
        }
    }
    
    func removeLikedVideo(_ videoPath: String) async {
        guard var currentUser = user else { return }
        
        currentUser.likedVideos?.removeAll { $0 == videoPath }
        await updateUser(currentUser)
        
        // Refresh video objects after removing
        await fetchLikedVideoObjects()
    }
    
    func addSavedVideo(_ videoPath: String) async {
        guard var currentUser = user, let userId = currentUser.id else { return }
        
        if currentUser.savedVideos == nil {
            currentUser.savedVideos = []
        }
        
        if !currentUser.savedVideos!.contains(videoPath) {
            currentUser.savedVideos?.append(videoPath)
            await updateUser(currentUser)
            
            // Refresh video objects after adding
            await fetchSavedVideoObjects()
        }
    }
    
    func removeSavedVideo(_ videoPath: String) async {
        guard var currentUser = user else { return }
        
        currentUser.savedVideos?.removeAll { $0 == videoPath }
        await updateUser(currentUser)
        
        // Refresh video objects after removing
        await fetchSavedVideoObjects()
    }
    
    // MARK: - Video Object Fetching Methods
    private func fetchUploadedVideoObjects() async {
        guard let uploadedVideoPaths = user?.uploadedVideos, !uploadedVideoPaths.isEmpty else {
            await MainActor.run {
                self.uploadedVideoArray = []
            }
            return
        }
        
        let videos = await fetchVideoObjectsFromPaths(uploadedVideoPaths)
        
        await MainActor.run {
            self.uploadedVideoArray = videos
        }
    }
    
    private func fetchLikedVideoObjects() async {
        guard let likedVideoPaths = user?.likedVideos, !likedVideoPaths.isEmpty else {
            await MainActor.run {
                self.likedVideoArray = []
            }
            return
        }
        
        let videos = await fetchVideoObjectsFromPaths(likedVideoPaths)
        
        await MainActor.run {
            self.likedVideoArray = videos
        }
    }
    
    private func fetchSavedVideoObjects() async {
        guard let savedVideoPaths = user?.savedVideos, !savedVideoPaths.isEmpty else {
            await MainActor.run {
                self.savedVideoArray = []
            }
            return
        }
        
        let videos = await fetchVideoObjectsFromPaths(savedVideoPaths)
        
        await MainActor.run {
            self.savedVideoArray = videos
        }
    }
    
    private func fetchVideoObjectsFromPaths(_ paths: [String]) async -> [Video] {
        var videos: [Video] = []
        
        await withTaskGroup(of: Video?.self) { group in
            for path in paths {
                group.addTask { [weak self] in
                    await self?.fetchVideoObjectFromPath(path)
                }
            }
            
            for await video in group {
                if let video = video {
                    videos.append(video)
                }
            }
        }
        
        return videos
    }
    
    private func fetchVideoObjectFromPath(_ path: String) async -> Video? {
        let components = path.split(separator: "/")
        guard components.count == 3 else {
            print("Invalid path format: \(path) - Skipping video fetch.")
            return nil
        }
        
        let lang = String(components[0])
        let docId = String(components[2])
        
        do {
            let document = try await db.collection(videosCollection)
                .document(lang)
                .collection("items")
                .document(docId)
                .getDocument()
            
            guard document.exists, let data = document.data() else {
                print("Video document missing or no data for \(path)")
                return nil
            }
            
            guard let urlString = data["video_url"] as? String,
                  let url = URL(string: urlString),
                  let likes = data["likes"] as? Int,
                  let saves = data["saves"] as? Int,
                  let language = data["language_detected"] as? String,
                  let uploaderId = data["uploaderId"] as? String,
                  let captionDicts = data["captions"] as? [[String: Any]] else {
                print("Malformed video data for path: \(path)")
                return nil
            }
            let title = (data["title"] as? String) ?? "N/A"
            let commentCount = data["commentCount"] as? Int ?? 0
            
            let captions: [Captions] = captionDicts.compactMap { dict in
                guard let start = dict["start"] as? Double,
                      let end = dict["end"] as? Double,
                      let text = dict["text"] as? String else {
                    return nil
                }
                let words = dict["words"] as? [String]
                return Captions(end: end, start: start, text: text, words: words)
            }
            
            let detectedLevel = data["detected_level"] as? Int ?? 2
            
            return Video(
                id: docId,
                url: url,
                captions: captions,
                title: title,
                detectedLevel: detectedLevel,
                uploaderId: uploaderId,
                likes: likes,
                saves: saves,
                commentCount: commentCount,
                language: language
            )
            
        } catch {
            print("Error fetching video object for \(path):", error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Private Helper Methods (Existing thumbnail methods)
    private func fetchVideoThumbnails() async {
        guard let uploadedVideos = user?.uploadedVideos, !uploadedVideos.isEmpty else {
            await MainActor.run {
                self.videoThumbnails = []
                self.videoURLs = []
            }
            return
        }
        
        var thumbnails = Array(repeating: "", count: uploadedVideos.count)
        var videoURLs = Array(repeating: "", count: uploadedVideos.count)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, path) in uploadedVideos.enumerated() {
                group.addTask { [weak self] in
                    await self?.fetchSingleVideoThumbnail(path: path, index: index, thumbnails: &thumbnails, videoURLs: &videoURLs)
                }
            }
        }
        
        await MainActor.run {
            self.videoThumbnails = thumbnails
            self.videoURLs = videoURLs
        }
    }
    
    private func fetchLikedVideoThumbnails() async {
        guard let likedVideos = user?.likedVideos, !likedVideos.isEmpty else {
            await MainActor.run {
                self.likedVideoThumbnails = []
                self.likedVideoURLs = []
            }
            return
        }
        
        var thumbnails = Array(repeating: "", count: likedVideos.count)
        var videoURLs = Array(repeating: "", count: likedVideos.count)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, path) in likedVideos.enumerated() {
                group.addTask { [weak self] in
                    await self?.fetchSingleVideoThumbnail(path: path, index: index, thumbnails: &thumbnails, videoURLs: &videoURLs)
                }
            }
        }
        
        await MainActor.run {
            self.likedVideoThumbnails = thumbnails
            self.likedVideoURLs = videoURLs
        }
    }
    
    private func fetchSavedVideoThumbnails() async {
        guard let savedVideos = user?.savedVideos, !savedVideos.isEmpty else {
            await MainActor.run {
                self.savedVideoThumbnails = []
                self.savedVideoURLs = []
            }
            return
        }
        
        var thumbnails = Array(repeating: "", count: savedVideos.count)
        var videoURLs = Array(repeating: "", count: savedVideos.count)
        
        await withTaskGroup(of: Void.self) { group in
            for (index, path) in savedVideos.enumerated() {
                group.addTask { [weak self] in
                    await self?.fetchSingleVideoThumbnail(path: path, index: index, thumbnails: &thumbnails, videoURLs: &videoURLs)
                }
            }
        }
        
        await MainActor.run {
            self.savedVideoThumbnails = thumbnails
            self.savedVideoURLs = videoURLs
//            print("Saved video thumbnails: \(thumbnails)")
//            print("Saved video URLs: \(videoURLs)")
        }
    }
    
    private func fetchSingleVideoThumbnail(path: String, index: Int, thumbnails: inout [String], videoURLs: inout [String]) async {
        let components = path.split(separator: "/")
        guard components.count == 3 else {
            print("Invalid path format: \(path) - Skipping thumbnail fetch.")
            return
        }
        
        let lang = String(components[0])
        let docId = String(components[2])
        
        do {
            let document = try await db.collection("videos")
                .document(lang)
                .collection("items")
                .document(docId)
                .getDocument()
            
            guard document.exists, let data = document.data() else {
                print("Thumbnail document missing or no data for \(path)")
                return
            }
            
            if let thumbnailURL = data["thumbnail_url"] as? String {
                thumbnails[index] = thumbnailURL
            }
            
            if let videoURL = data["video_url"] as? String {
                videoURLs[index] = videoURL
            }
            
        } catch {
            print("Error fetching thumbnail for \(path):", error.localizedDescription)
        }
    }
}

// Rest of your CountryFlagConverter and String extension remain the same
class CountryFlagConverter {
    private static let countryToCode: [String: String] = [
        // Major countries
        "united states": "US",
        "canada": "CA",
        "united kingdom": "GB",
        "germany": "DE",
        "france": "FR",
        "spain": "ES",
        "italy": "IT",
        "japan": "JP",
        "china": "CN",
        "south korea": "KR",
        "australia": "AU",
        "new zealand": "NZ",
        "brazil": "BR",
        "mexico": "MX",
        "argentina": "AR",
        "india": "IN",
        "russia": "RU",
        "netherlands": "NL",
        "belgium": "BE",
        "switzerland": "CH",
        "austria": "AT",
        "sweden": "SE",
        "norway": "NO",
        "denmark": "DK",
        "finland": "FI",
        "poland": "PL",
        "czech republic": "CZ",
        "hungary": "HU",
        "portugal": "PT",
        "greece": "GR",
        "turkey": "TR",
        "israel": "IL",
        "south africa": "ZA",
        "egypt": "EG",
        "thailand": "TH",
        "vietnam": "VN",
        "singapore": "SG",
        "malaysia": "MY",
        "indonesia": "ID",
        "philippines": "PH",
        "pakistan": "PK",
        "bangladesh": "BD",
        "ukraine": "UA",
        "romania": "RO",
        "bulgaria": "BG",
        "croatia": "HR",
        "serbia": "RS",
        "ireland": "IE",
        "iceland": "IS",
        "chile": "CL",
        "peru": "PE",
        "colombia": "CO",
        "venezuela": "VE",
        "ecuador": "EC",
        "bolivia": "BO",
        "uruguay": "UY",
        "paraguay": "PY",
        "kenya": "KE",
        "nigeria": "NG",
        "morocco": "MA",
        "ethiopia": "ET",
        "ghana": "GH",
        "saudi arabia": "SA",
        "united arab emirates": "AE",
        "qatar": "QA",
        "kuwait": "KW",
        "bahrain": "BH",
        "oman": "OM",
        "jordan": "JO",
        "lebanon": "LB",
        "iran": "IR",
        "iraq": "IQ",
        "afghanistan": "AF",
        "nepal": "NP",
        "sri lanka": "LK",
        "myanmar": "MM",
        "cambodia": "KH",
        "laos": "LA",
        "mongolia": "MN",
        "kazakhstan": "KZ",
        "uzbekistan": "UZ",
        "kyrgyzstan": "KG",
        "tajikistan": "TJ",
        "turkmenistan": "TM",
        "azerbaijan": "AZ",
        "armenia": "AM",
        "georgia": "GE",
        "belarus": "BY",
        "moldova": "MD",
        "estonia": "EE",
        "latvia": "LV",
        "lithuania": "LT",
        "slovenia": "SI",
        "slovakia": "SK",
        "bosnia and herzegovina": "BA",
        "montenegro": "ME",
        "macedonia": "MK",
        "albania": "AL",
        "kosovo": "XK",
        "malta": "MT",
        "cyprus": "CY",
        "luxembourg": "LU",
        "monaco": "MC",
        "andorra": "AD",
        "san marino": "SM",
        "vatican city": "VA",
        "liechtenstein": "LI"
    ]
    
    static func getFlag(for countryName: String) -> String {
        let normalizedName = countryName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let countryCode = countryToCode[normalizedName] else {
            return "🏳️" // Default flag if country not found
        }
        
        return countryCode.countryCodeToFlag()
    }
}

extension String {
    func countryCodeToFlag() -> String {
        let base: UInt32 = 127397
        var flag = ""
        
        for v in self.unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                flag.append(String(scalar))
            }
        }
        
        return flag
    }
}
