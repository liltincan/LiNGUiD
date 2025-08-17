//
//  OtherUserProfileView.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 7/6/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct OtherUserProfileView: View {
    @StateObject private var vm: OtherUserProfileViewModel
    @EnvironmentObject var state: AppState
    @EnvironmentObject var userSession: UserSessionViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFullScreenProfilePicture: Bool = false
    @State private var fullScreenProfilePictureURL: String?
    @State private var hasTaskExecuted = false
    @State private var showingReportConfirmation = false // <-- Add this state
    
    let userId: String
    @Binding var selectedTab: Int
    
    let onLogout: () -> Void
    
    init(userId: String, selectedTab: Binding<Int>, onLogout: @escaping () -> Void) {
        self.userId = userId
        self._selectedTab = selectedTab
        _vm = StateObject(wrappedValue: OtherUserProfileViewModel(userId: userId))
        self.onLogout = onLogout
    }
    
    var body: some View {
        ZStack {
            // Background color to prevent black screen
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if !vm.dataReady {
                // Loading state
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading profile...")
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    hasTaskExecuted = false
                    Task {
                        await loadData()
                    }
                }
            } else {
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
                            country: vm.country ?? "ERROR",
                            onReportProfile: {
                                showingReportConfirmation = true
                            },
                            userSession: userSession // <-- Pass userSession here
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
                                selectedTab: $selectedTab,
                                fromOtherUserProfile: true,
                                onLogout: onLogout
                            )
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        // Remove the safeAreaInset that was causing extra top spacing
        // .safeAreaInset(edge: .top) {
        //     Color.clear.frame(height: 60) // Allows pull-to-refresh spinner to show
        // }
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
        .onAppear {
            // Reset task execution flag and load data when view appears
            hasTaskExecuted = false
            Task {
                await loadData()
            }
        }
        .alert("Report Submitted", isPresented: $showingReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you for your report. We'll review this profile.")
        }
    }
    
    @MainActor
    private func loadData() async {
        print("Loading data for user: \(userId)")
        // Reset dataReady to false to show loading state
        vm.dataReady = false
        hasTaskExecuted = true
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
    var onReportProfile: (() -> Void)? = nil
    let userSession: UserSessionViewModel // <-- Add this property

    @State private var showingReportSheet = false

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
                    showingReportSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.trailing, 20)
                .confirmationDialog("", isPresented: $showingReportSheet, titleVisibility: .hidden) {
                    Button("Report Profile", role: .destructive) {
                        onReportProfile?()
                        if let reporterUid = Auth.auth().currentUser?.uid,
                           let reporterUsername = userSession.currentUser?.userName {
                            reportProfile(
                                reportedUserId: vm.user?.id ?? "",
                                reporterUid: reporterUid,
                                reporterUsername: reporterUsername,
                                posterUsername: userName
                            )
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
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
    @State private var showingShareSheet = false
    
    private var shareURL: URL? {
        // Create the profile share URL using the user ID
        URL(string: "https://learnwithlinguid.com/profiles/\(userId)")
    }
    
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
                Text(isFollowing ? "Following" : "Follow")
                    .foregroundColor(isFollowing ? .white : .white)
                    .font(.system(size: 16, weight: .medium))
                    //.padding(15)
                    .frame(width: 80, height: 32, alignment: .center)
                    .background(isFollowing ? Color.appPrimaryColor.opacity(0.90) : Color.appPrimaryColor)
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
                    .frame(width: 80, height: 32, alignment: .center)
                    .background(Color.appPrimaryColor)
                    .cornerRadius(8)
            }
            
            Button {
                showingShareSheet = true
            } label: {
                Text("Share")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    //.padding(15)
                    .frame(width: 80, height: 32, alignment: .center)
                    .background(Color.appPrimaryColor)
                    .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }
}

func reportProfile(reportedUserId: String, reporterUid: String, reporterUsername: String, posterUsername: String) {
    guard let url = URL(string: "https://makechicken.onrender.com/api/reportProfile") else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "reportedUserId": reportedUserId,
        "reporterUid": reporterUid,
        "reporterUsername": reporterUsername,
        "posterUsername": posterUsername
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Profile report failed:", error)
            return
        }
        print("Profile report sent successfully")
    }.resume()
}

