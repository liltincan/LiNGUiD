//
//  OtherUserProfileView.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 7/6/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OtherUserProfileView: View {
    @StateObject private var vm: OtherUserProfileViewModel
    @EnvironmentObject var state: AppState
    @EnvironmentObject var userSession: UserSessionViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFullScreenProfilePicture: Bool = false
    @State private var fullScreenProfilePictureURL: String?
    @State private var hasTaskExecuted = false
    
    let userId: String

    init(userId: String) {
        self.userId = userId
        _vm = StateObject(wrappedValue: OtherUserProfileViewModel(userId: userId))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack {
                        OtherUserProfileHeaderView(
                            userName: vm.userName,
                            profilePictureURL: vm.profilePictureURL,
                            languageDisplay: vm.formattedLanguagesDisplay,
                            vm: vm,
                            showingFullScreenProfilePicture: $showingFullScreenProfilePicture,
                            fullScreenProfilePictureURL: $fullScreenProfilePictureURL,
                            onBackTapped: {
                                dismiss()
                            }
                        )
                        .padding(.bottom, 10)
                        
                        ProfileStatsView(
                            videoCount: vm.videoCount,
                            inputAmount: vm.inputAmount,
                            followerCount: vm.followerCount
                        )
                        .padding(.bottom, 10)
                        
                        OtherUserProfileActionButtons(
                            userId: userId,
                            username: vm.userName,
                            isFollowing: vm.isFollowing,
                            vm: vm
                        )
                        .padding(.bottom, 15)
                        
                        VideoGridSection(
                            videoThumbnails: vm.videoThumbnails,
                            videoURLs: vm.videoURLs
                        )
                            
                    }
                    
                }
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 60) // Allows pull-to-refresh spinner to show
            }
            .refreshable {
                await refreshData()
            }
            .task {
                Task {
                    await loadData()
                }
            }
            .overlay(
                Group {
                    if showingFullScreenProfilePicture, let urlString = fullScreenProfilePictureURL, let url = URL(string: urlString) {
                        Rectangle()
                            .fill(Material.ultraThinMaterial)
                            .ignoresSafeArea()
                        
                        ZStack {
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    } else if phase.error != nil {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.red)
                                            .frame(width: 100, height: 100)
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                Button {
                                    showingFullScreenProfilePicture = false
                                    fullScreenProfilePictureURL = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                        .padding(15)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
            )
            .animation(.easeInOut, value: showingFullScreenProfilePicture)
            .navigationBarBackButtonHidden(true)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Enable swipe-to-go-back from left edge
                        if value.translation.width > 100 {
                            dismiss()
                        }
                    }
            )
        }
    }
    
    @MainActor
    private func loadData() async {
        guard !hasTaskExecuted else { return }
        hasTaskExecuted = true
        print("Loading data for user: \(userId)")
        await vm.fetchUserData(userSession: userSession)
    }
    
    @MainActor
    private func refreshData() async {
        print("Refreshing data for user: \(userId)")
        await vm.fetchUserData(userSession: userSession)
    }
}

struct OtherUserProfileHeaderView: View {
    let userName: String
    let profilePictureURL: String
    let languageDisplay: String
    @StateObject var vm: OtherUserProfileViewModel
    @Binding var showingFullScreenProfilePicture: Bool
    @Binding var fullScreenProfilePictureURL: String?
    let onBackTapped: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    onBackTapped()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(userName)
                    .font(.system(size: 27))
                    .bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    // More options menu
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            Button {
                showingFullScreenProfilePicture = true
                fullScreenProfilePictureURL = profilePictureURL
            } label: {
                if profilePictureURL != "" {
                    AsyncImage(url: URL(string: profilePictureURL)) { result in
                        result.image?
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .frame(width: 100, height: 100)
                    .padding(.bottom, 15)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 15)
                }
            }
            
            Text(languageDisplay)
                .lineLimit(1)
                .padding(.bottom, 10)
                .foregroundColor(.primary)
        }
    }
}

struct OtherUserProfileActionButtons: View {
    let userId: String
    let username: String
    let isFollowing: Bool
    @StateObject var vm: OtherUserProfileViewModel
    
    var body: some View {
        HStack {
            Button {
                Task {
                    if isFollowing {
                        await vm.unfollowUser()
                    } else {
                        await vm.followUser()
                    }
                }
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .foregroundColor(isFollowing ? .primary : .white)
                    .fontWeight(.medium)
                    .font(.system(size: 16))
                    .padding(15)
                    .frame(maxWidth: 100, maxHeight: 45)
                    .background(isFollowing ? Color.secondary.opacity(0.2) : Color.purple)
                    .cornerRadius(10)
            }
            
            Button {
                // Navigate to message view
                // This would need to be implemented based on your messaging system
            } label: {
                Text("Message")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                    .font(.system(size: 16))
                    .padding(15)
                    .frame(maxWidth: 100, maxHeight: 45)
                    .background(Color.purple)
                    .cornerRadius(10)
            }
            
            Button {
                // Share profile functionality
            } label: {
                Text("Share")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                    .font(.system(size: 16))
                    .padding(15)
                    .frame(maxWidth: 100, maxHeight: 45)
                    .background(Color.purple)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Other User Profile ViewModel
@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var dataReady: Bool = false
    @Published var errorMessage: String?
    @Published var videoThumbnails: [String] = []
    @Published var videoURLs: [String] = []
    @Published var isFollowing: Bool = false
    @Published var nativeLanguage: String? = nil
    
    private let db = Firestore.firestore()
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
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
        return String(Int(user?.globalWatchTime ?? 0))
    }
    
    var followerCount: String {
        return String(user?.followers?.count ?? 0)
    }
    
    var profilePictureURL: String {
        return user?.profilePhotoUrl ?? ""
    }
    
    var nativeLanguageDisplay: String {
        return user?.nativeLanguage?.capitalized ?? ""
    }
    
    var formattedLanguagesDisplay: String {
        if let languagesData = user?.languagesData {
            let nativeLanguage: String = user?.nativeLanguage?.capitalized ?? ""
            let targetLanguage: String = user?.targetLanguage.capitalized ?? languagesData.keys.first?.capitalized ?? ""
            let comprehensionLevel: Int = languagesData[targetLanguage.lowercased()]?.comprehensionLevel ?? 0
            
            // If we didn't find the level for target language, try the first available language
            if comprehensionLevel == 0, let firstLanguageKey = languagesData.keys.first {
                let fallbackLevel = languagesData[firstLanguageKey]?.comprehensionLevel ?? 0
                return "\(nativeLanguage) → \(targetLanguage) (Lvl.\(fallbackLevel))"
            }
            
            return "\(nativeLanguage) → \(targetLanguage) (Lvl.\(comprehensionLevel))"
        }
        
        return ""
    }
    
    // MARK: - Data Fetching
    func fetchUserData(userSession: UserSessionViewModel) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
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
                self.errorMessage = nil
            }
            
            await fetchVideoThumbnails()
            await checkIfFollowing(userSession: userSession)
            
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
    
    // MARK: - Follow/Unfollow Functionality
    func followUser() async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != userId else { return }
        
        do {
            // Add to current user's following list
            try await db.collection("users").document(currentUserId).updateData([
                "following": FieldValue.arrayUnion([userId])
            ])
            
            // Add to other user's followers list
            try await db.collection("users").document(userId).updateData([
                "followers": FieldValue.arrayUnion([currentUserId])
            ])
            
            await MainActor.run {
                self.isFollowing = true
                // Update follower count
                if var currentUser = self.user {
                    if currentUser.followers == nil {
                        currentUser.followers = []
                    }
                    if !currentUser.followers!.contains(currentUserId) {
                        currentUser.followers!.append(currentUserId)
                        self.user = currentUser
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to follow user: \(error.localizedDescription)"
            }
        }
    }
    
    func unfollowUser() async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != userId else { return }
        
        do {
            // Remove from current user's following list
            try await db.collection("users").document(currentUserId).updateData([
                "following": FieldValue.arrayRemove([userId])
            ])
            
            // Remove from other user's followers list
            try await db.collection("users").document(userId).updateData([
                "followers": FieldValue.arrayRemove([currentUserId])
            ])
            
            await MainActor.run {
                self.isFollowing = false
                // Update follower count
                if var currentUser = self.user {
                    currentUser.followers?.removeAll { $0 == currentUserId }
                    self.user = currentUser
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Helper Methods
    private func checkIfFollowing(userSession: UserSessionViewModel) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != userId else {
            await MainActor.run {
                self.isFollowing = false
            }
            return
        }
        
        do {
            let document = try await db.collection("users").document(currentUserId).getDocument()
            
            if let data = document.data(),
               let following = data["following"] as? [String] {
                await MainActor.run {
                    self.isFollowing = following.contains(self.userId)
                }
            } else {
                await MainActor.run {
                    self.isFollowing = false
                }
            }
        } catch {
            await MainActor.run {
                self.isFollowing = false
            }
        }
    }
    
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
