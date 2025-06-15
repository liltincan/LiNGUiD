//
//  DashboardViewModel.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 6/7/25.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class DashboardViewModel: ObservableObject{
    @Published var user: User?
    @Published var errorMessage: String = ""
    @Published var userLevel: Int = 0
    @Published var totalWatchTime: Double = 0
    @Published var totalHours: Int = 0
    @Published var monthlyHoursIncrease: Int = 0
    @Published var userRank: Int = 0
    @Published var savedWords: [WordPair] = []
    @Published var studyDates: Set<Int> = []
    @Published var currentMonth: String = ""
    @Published var leaderboardUsers: [LeaderboardUser] = []
    @Published var isLoading: Bool = false
    @Published var targetLanguage: String?
    @Published var nativeLanguage: String?
    
    var userSession: UserSessionViewModel
    private let db = Firestore.firestore()

    init(userSession: UserSessionViewModel) {
        self.userSession = userSession
        setupCurrentMonth()
    }
    
    func fetchUserData() async {
        isLoading = true
        await userSession.refreshUser()
        
        if let user = userSession.currentUser {
            self.user = user
            
            // Use EXACTLY the same logic as Profile page formattedLanguagesDisplay
            if let languagesData = user.languagesData {
                let targetLanugage: String = user.targetLanguage // Keep original variable name like Profile
                
                let comprehensionLevel: Int = languagesData[targetLanugage.lowercased()]?.comprehensionLevel ?? 0
                
                
                if comprehensionLevel == 0, let firstLanguageKey = languagesData.keys.first {
                    let fallbackLevel = languagesData[firstLanguageKey]?.comprehensionLevel ?? 0
                    self.userLevel = fallbackLevel
                } else {
                    self.userLevel = comprehensionLevel
                }
                
                // Get watch time from target language data (using lowercased key)
                if let userLanguageData = languagesData[targetLanugage.lowercased()] {
                    self.totalWatchTime = userLanguageData.watchTime?.total ?? 0
                } else if let firstLanguageKey = languagesData.keys.first,
                          let firstLanguageData = languagesData[firstLanguageKey] {
                    self.totalWatchTime = firstLanguageData.watchTime?.total ?? 0
                } else {
                    self.totalWatchTime = 0
                }
                
                self.targetLanguage = user.targetLanguage
                self.nativeLanguage = user.nativeLanguage
            } else {
                // No language data available - default to 0 like Profile
                self.userLevel = 0
                self.totalWatchTime = 0
            }
            
            // Calculate user stats and fetch real leaderboard
            await calculateUserStats(from: user)
            loadSavedWords(from: user)
            generateStudyDates()
            await fetchRealLeaderboard()
            
            isLoading = false
        } else {
            errorMessage = "User not found"
            isLoading = false
        }
    }
    
    func loadDashboardData() async {
        await fetchUserData()
    }
    
    private func calculateUserStats(from user: User) async {
        let totalWatchTime = user.globalWatchTime ?? 0
        totalHours = Int(totalWatchTime / 3600)
        
        // Calculate monthly hours increase (simplified for now)
        monthlyHoursIncrease = Int(totalWatchTime / 3600 / 4) // Rough estimate
        
        // Calculate real user rank
        userRank = await calculateUserRank(currentUserWatchTime: totalWatchTime)
    }
    
    private func calculateUserRank(currentUserWatchTime: Double) async -> Int {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            var userWatchTimes: [Double] = []
            
            for document in snapshot.documents {
                if let watchTime = document.data()["globalWatchTime"] as? Double {
                    userWatchTimes.append(watchTime)
                }
            }
            
            userWatchTimes.sort(by: >)
            
            if let rank = userWatchTimes.firstIndex(where: { $0 <= currentUserWatchTime }) {
                return rank + 1
            } else {
                return userWatchTimes.count + 1
            }
        } catch {
            print("Error calculating user rank: \(error)")
            return 0
        }
    }
    
    private func fetchRealLeaderboard() async {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "globalWatchTime", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            var fetchedUsers: [LeaderboardUser] = []
            var currentUserFound = false
            
            // Use Auth.auth().currentUser?.uid for consistency with VideoPlayerView fixes
            let currentUserAuthUID = Auth.auth().currentUser?.uid
            print("🔍 Leaderboard Debug - Current User Auth UID: \(currentUserAuthUID ?? "nil")")
            print("🔍 Leaderboard Debug - Current User Name: \(userSession.currentUser?.userName ?? "nil")")
            
            for (index, document) in snapshot.documents.enumerated() {
                let data = document.data()
                // Try to get username from Firestore, fallback to "Unknown"
                let username = data["username"] as? String ?? data["userName"] as? String ?? "Unknown"
                let watchTime = data["globalWatchTime"] as? Double ?? 0
                let minutes = Int(watchTime / 60)
                let rank = index + 1
                
                print("🔍 Leaderboard Debug - User \(rank): ID=\(document.documentID), Name=\(username)")
                
                let avatarURL = data["profilePhotoUrl"] as? String ?? generatePlaceholderAvatar(for: username)
                
                let leaderboardUser = LeaderboardUser(
                    id: document.documentID,
                    name: username,
                    minutes: minutes,
                    rank: rank,
                    avatarURL: avatarURL
                )
                
                fetchedUsers.append(leaderboardUser)
                
                // Use Auth UID for comparison instead of userSession.currentUser?.id
                if document.documentID == currentUserAuthUID {
                    currentUserFound = true
                    print("🔍 Leaderboard Debug - Found current user in top 10 at rank \(rank)")
                }
            }
            
            // If current user is not in top 10, add them to display
            if !currentUserFound, let currentUser = userSession.currentUser, let currentUserAuthUID = currentUserAuthUID {
                print("🔍 Leaderboard Debug - Current user not in top 10, adding separately")
                let currentUserWatchTime = currentUser.globalWatchTime ?? 0
                let currentUserMinutes = Int(currentUserWatchTime / 60)
                
                // Use EXACTLY the same userName as Profile page
                let currentUserName = currentUser.userName ?? "Me"
                print("🔍 Leaderboard Debug - Adding current user: Name=\(currentUserName), Minutes=\(currentUserMinutes), Rank=\(userRank)")
                
                // Get profile photo URL from User model (same as Profile page)
                let currentUserAvatar: String
                if let profilePhotoUrl = currentUser.profilePhotoUrl, !profilePhotoUrl.isEmpty {
                    currentUserAvatar = profilePhotoUrl
                } else {
                    currentUserAvatar = generatePlaceholderAvatar(for: currentUserName)
                }
                
                let currentUserLeaderboard = LeaderboardUser(
                    id: currentUserAuthUID, // Use Auth UID instead of currentUser.id
                    name: currentUserName,
                    minutes: currentUserMinutes,
                    rank: userRank,
                    avatarURL: currentUserAvatar
                )
                
                // Keep top 3 + current user (avoid duplicates)
                if fetchedUsers.count >= 3 {
                    fetchedUsers = Array(fetchedUsers.prefix(3)) + [currentUserLeaderboard]
                } else {
                    fetchedUsers.append(currentUserLeaderboard)
                }
            }
            
            print("🔍 Leaderboard Debug - Final leaderboard users: \(fetchedUsers.map { "\($0.name) (rank \($0.rank))" })")
            leaderboardUsers = fetchedUsers
        } catch {
            print("Error fetching leaderboard: \(error)")
            // Fallback to mock data
            setupMockLeaderboard()
        }
    }
    
    private func generatePlaceholderAvatar(for username: String) -> String {
        let firstLetter = String(username.prefix(1)).uppercased()
        return "https://ui-avatars.com/api/?name=\(firstLetter)&background=8B5A2B&color=fff&size=150"
    }
    
    private func loadSavedWords(from user: User) {
        if let targetLanguage = user.languagesData?[user.targetLanguage]?.savedWords {
            savedWords = Array(targetLanguage.unknownWords.prefix(5))
        } else {
            savedWords = []
        }
    }
    
    private func generateStudyDates() {
        studyDates = Set([4, 5, 8, 12, 15, 18, 22, 25])
    }
    
    private func setupCurrentMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        currentMonth = formatter.string(from: Date())
    }
    
    private func setupMockLeaderboard() {
        // Fallback mock data with real current user data
        var mockUsers: [LeaderboardUser] = [
            LeaderboardUser(id: "1", name: "starryskies23", minutes: 59, rank: 2, avatarURL: "https://images.unsplash.com/photo-1494790108755-2616b612b1c?w=150&h=150&fit=crop&crop=face"),
            LeaderboardUser(id: "2", name: "Eloise", minutes: 60, rank: 1, avatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face"),
            LeaderboardUser(id: "3", name: "nebulanomad", minutes: 55, rank: 3, avatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face")
        ]
        
        // Add real current user data - use Profile's userName exactly
        if let currentUser = userSession.currentUser, let currentUserAuthUID = Auth.auth().currentUser?.uid {
            let currentUserWatchTime = currentUser.globalWatchTime ?? 0
            let currentUserMinutes = Int(currentUserWatchTime / 60)
            
            // Use EXACTLY the same userName as Profile page
            let currentUserName = currentUser.userName ?? "Me"
            
            // Use real profile photo or generate placeholder
            let currentUserAvatar: String
            if let profilePhotoUrl = currentUser.profilePhotoUrl, !profilePhotoUrl.isEmpty {
                currentUserAvatar = profilePhotoUrl
            } else {
                currentUserAvatar = generatePlaceholderAvatar(for: currentUserName)
            }
            
            let currentUserLeaderboard = LeaderboardUser(
                id: currentUserAuthUID, // Use Auth UID instead of currentUser.id
                name: currentUserName,
                minutes: currentUserMinutes,
                rank: userRank > 0 ? userRank : 15, // Use calculated rank or fallback to 15
                avatarURL: currentUserAvatar
            )
            
            mockUsers.append(currentUserLeaderboard)
        } else {
            // Fallback if no current user
            mockUsers.append(
                LeaderboardUser(id: "4", name: "Me", minutes: 4, rank: 15, avatarURL: generatePlaceholderAvatar(for: "Me"))
            )
        }
        
        leaderboardUsers = mockUsers
    }
}

// MARK: - Data Models
struct LeaderboardUser: Identifiable {
    let id: String
    let name: String
    let minutes: Int
    let rank: Int
    let avatarURL: String
}
