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
    @Binding var selectedTab: Int
    
    init(userId: String, selectedTab: Binding<Int>) {
        self.userId = userId
        self._selectedTab = selectedTab
        _vm = StateObject(wrappedValue: OtherUserProfileViewModel(userId: userId))
    }
    
    var body: some View {
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
                        selectedTab: $selectedTab,
                        vm: vm
                    )
                    .padding(.bottom, 15)
                    
                    VideoGridSection(
                        videoThumbnails: vm.videoThumbnails,
                        videoURLs: vm.videoURLs,
                        uploadingVideos: [],
                        noVideosMessage: "The user hasn't uploaded any videos yet.",
                        videoArray: vm.uploadedVideoArray,
                        selectedTab: $selectedTab
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
    @Binding var selectedTab: Int
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
                    .background(isFollowing ? Color.secondary.opacity(0.2) : Color.appPrimaryColor)
                    .cornerRadius(10)
            }
            
            Button {
                // Navigate to chat tab and start/open chat with this user
                selectedTab = 1
                
                // You'll need to add a method to your ChatListViewModel to handle this
                // This could be done through a notification or by updating the ChatListView
                // to accept a parameter for which user to chat with
                
                // Option 1: Using NotificationCenter (recommended)
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartChatWithUser"),
                    object: nil,
                    userInfo: ["userId": userId, "username": username]
                )
                // Option 2: You could also use a shared state manager or dependency injection
                // to communicate between views
                
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
