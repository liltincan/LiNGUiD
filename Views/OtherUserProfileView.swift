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
            VStack {
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
                        },
                        country: vm.country ?? "ERROR"
                    )
                    .padding(.top, 2.5)
                    
                    ProfileStatsView(
                        videoCount: vm.videoCount,
                        inputAmount: vm.inputAmount,
                        followerCount: vm.followerCount,
                        onFollowersTapped: {
                            print("Followers tapped")
                        }
                    )
                    .padding(.top, -10)
                    
                    OtherUserProfileActionButtons(
                        userId: userId,
                        username: vm.userName,
                        isFollowing: vm.isFollowing,
                        selectedTab: $selectedTab,
                        vm: vm
                    )
                    .padding(.bottom, 10)
                    ScrollView{
                        VideoGridSection(
                            videoThumbnails: vm.videoThumbnails.reversed(),
                            videoURLs: vm.videoURLs.reversed(),
                            uploadingVideos: [],
                            noVideosMessage: "The user hasn't uploaded any videos yet.",
                            videoArray: vm.uploadedVideoArray.reversed(),
                            selectedTab: $selectedTab
                        )
                    }
                    .scrollIndicators(.hidden)
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
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                showingFullScreenProfilePicture = false
                                fullScreenProfilePictureURL = nil
                            }
                        }
                    
                    ZStack {
                        ZStack() {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 350, height: 700)
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
    let country: String
    
    @ViewBuilder
    private var targetLanguageLevelsView: some View {
        HStack(spacing: -20) {
            ForEach(vm.targetLanguageList.sorted(), id: \.self) { language in
                VStack(spacing: -10) {
                    Text(language.uppercased())
                        .font(.system(size: 14, weight: .medium))

                    LevelDotsView(level: vm.user?.languagesData?[language]?.comprehensionLevel ?? 0)
                        .padding(.top, -7.5)
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    onBackTapped()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.leading, 20)
                
                Spacer()
                
                HStack(spacing: 0) {
                    Text(userName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    if vm.isProUser {
                        Image(systemName: "checkmark.seal.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.appPrimaryColor)
                            .font(.system(size: 16))
                    }
                }
                .padding(.trailing, -5)
                
                Spacer()
                
                Button {
                    // More options menu
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.trailing, 20)
            }
            .padding(.bottom, 10)
            
            Button {
                showingFullScreenProfilePicture = true
                fullScreenProfilePictureURL = profilePictureURL
            } label: {
                ZStack {
                    if profilePictureURL != "" {
                        AsyncImage(url: URL(string: profilePictureURL)) { result in
                            result.image?
                                .resizable()
                                .scaledToFill()
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .padding(.top, -12.5)
            
            Text(CountryFlagConverter.getFlag(for: country.lowercased()))
                .font(.system(size: 20))
                .padding(.top, -25)
                .padding(.leading, -35)
            
            VStack(spacing: 0){
                HStack(spacing: -10) {
                    VStack(spacing: -10) {
                        Text(vm.nativeLanguage?.uppercased() ?? "")
                            .font(.system(size: 14, weight: .medium))
                        MiniProgressBarView()
                            .padding(.top, -7.5)
                    }

                    Image(systemName: "chevron.right.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .padding(.top, -15)
                        .fontWeight(.semibold)

                    targetLanguageLevelsView //cleaner and faster for compiler
                }
            }
            .padding(.top, -5)
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
        HStack(spacing: 12.5) {
            Button {
                Task {
                    if isFollowing {
                        await vm.unfollowUser()
                    } else {
                        await vm.followUser()
                    }
                }
            } label: {
                Text(isFollowing ? "Followed" : "Follow")
                    .foregroundColor(isFollowing ? .white : .white)
                    .font(.system(size: 16, weight: .medium))
                    //.padding(15)
                    .frame(width: 74, height: 32, alignment: .center)
                    .background(isFollowing ? Color.appSecondaryColor : Color.appPrimaryColor)
                    .cornerRadius(8)
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
                    .font(.system(size: 16, weight: .medium))
                    //.padding(15)
                    .frame(width: 74, height: 32, alignment: .center)
                    .background(Color.appPrimaryColor)
                    .cornerRadius(8)
            }
            
            Button {
                // Share profile functionality
            } label: {
                Text("Share")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    //.padding(15)
                    .frame(width: 74, height: 32, alignment: .center)
                    .background(Color.appPrimaryColor)
                    .cornerRadius(8)
            }
        }
    }
}
