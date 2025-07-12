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
    @Published var totalHours: Double = 0
    @Published var monthlyHoursIncrease: Double = 0
    @Published var userRank: Int = 0
    @Published var savedWords: [WordPair] = []
    @Published var studyDates: Set<Int> = []
    @Published var dailyWatchTime: [Int: Double] = [:]
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
        errorMessage = ""  // Clear previous error messages
        
        do {
            await userSession.refreshUser()
            
            guard let user = userSession.currentUser else {
                throw NSError(domain: "DashboardError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User information not found, please log in again"])
            }
            
            self.user = user
            
            // TEMP DISABLED: Migration causes issues with poor network connection
            // await migrateWatchTimeIfNeeded(for: user)
            // 
            // // Refresh user data after potential migration
            // await userSession.refreshUser()
            // if let updatedUser = userSession.currentUser {
            //     self.user = updatedUser
            // }
            
            // Use EXACTLY the same logic as Profile page formattedLanguagesDisplay
            if let languagesData = self.user?.languagesData {
                let targetLanguage: String = self.user?.targetLanguage ?? "" // Keep original variable name like Profile
                
                let comprehensionLevel: Int = languagesData[targetLanguage.lowercased()]?.comprehensionLevel ?? 0
                
                if comprehensionLevel == 0, let firstLanguageKey = languagesData.keys.first {
                    let fallbackLevel = languagesData[firstLanguageKey]?.comprehensionLevel ?? 0
                    self.userLevel = fallbackLevel
                    print("🔍 Dashboard Debug - Using fallback level \(fallbackLevel) from language \(firstLanguageKey)")
                } else {
                    self.userLevel = comprehensionLevel
                    print("🔍 Dashboard Debug - Using target language level \(comprehensionLevel)")
                }
                
                // Get watch time from target language data (using lowercased key)
                print("🔍 Watch Time Debug - Target language: '\(targetLanguage)'")
                print("🔍 Watch Time Debug - Available languages: \(languagesData.keys.sorted())")
                print("🔍 Watch Time Debug - Global watch time: \(self.user?.globalWatchTime ?? 0)s")
                
                // Use language-specific watch time ONLY - don't fallback to global
                if let userLanguageData = languagesData[targetLanguage.lowercased()],
                   let languageWatchTime = userLanguageData.watchTime?.total {
                    self.totalWatchTime = languageWatchTime
                    print("🔍 Watch Time Debug - Using \(targetLanguage) specific time: \(self.totalWatchTime)s")
                } else if let firstLanguageKey = languagesData.keys.first,
                          let firstLanguageData = languagesData[firstLanguageKey],
                          let fallbackWatchTime = firstLanguageData.watchTime?.total {
                    self.totalWatchTime = fallbackWatchTime
                    print("🔍 Watch Time Debug - Using fallback language '\(firstLanguageKey)' time: \(self.totalWatchTime)s")
                } else {
                    // Start with 0 for language-specific time (user hasn't watched videos in this language yet)
                    self.totalWatchTime = 0
                    print("🔍 Watch Time Debug - No language-specific watch time data available, using 0 (user hasn't watched \(targetLanguage) videos yet)")
                }
                
                self.targetLanguage = self.user?.targetLanguage
                self.nativeLanguage = self.user?.nativeLanguage
            } else {
                // No language data available - start with 0 for new users
                self.userLevel = 0
                self.totalWatchTime = 0
                print("🔍 Dashboard Debug - No language data available, starting with 0 for new user")
            }
            
            // Calculate user stats and fetch real leaderboard
            await calculateUserStats(from: self.user!)
            loadSavedWords(from: self.user!)
            generateStudyDates()
            await fetchRealLeaderboard()
            
            print("🔍 Dashboard Debug - Successfully loaded user data: Level=\(userLevel), Hours=\(totalHours), Rank=\(userRank)")
            
        } catch {
            print("🔍 Dashboard Error - Failed to load user data: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadDashboardData() async {
        await fetchUserData()
    }
    
    private func calculateUserStats(from user: User) async {
        // Use ONLY language-specific watch time (no fallback to global time)
        let languageSpecificWatchTime = self.totalWatchTime // Already calculated in fetchUserData
        totalHours = languageSpecificWatchTime / 3600 // Convert seconds to hours with decimal
        
        // Calculate monthly hours increase based on language-specific time
        // Note: This is a simplified estimate until we have proper monthly tracking
        monthlyHoursIncrease = totalHours / 4 // Rough estimate: total hours divided by 4 weeks
        
        // Calculate real user rank using global watch time for fair comparison
        let globalWatchTime = user.globalWatchTime ?? 0
        userRank = await calculateUserRank(currentUserWatchTime: globalWatchTime)
        
        print("🔍 Hours Debug - Language-specific watch time: \(languageSpecificWatchTime)s = \(totalHours)h")
        print("🔍 Hours Debug - Global watch time: \(globalWatchTime)s = \(globalWatchTime/3600)h")
        print("🔍 Hours Debug - Dashboard showing language-specific hours: \(totalHours)h")
        print("🔍 Hours Debug - Monthly increase estimate: \(monthlyHoursIncrease)h")
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
            
            for (index, document) in snapshot.documents.enumerated() {
                let data = document.data()
                // Try to get username from Firestore, fallback to "Unknown"
                let username = data["userName"] as? String ?? data["userName"] as? String ?? "Unknown"
                let watchTime = data["globalWatchTime"] as? Double ?? 0
                let minutes = Int(watchTime / 60)
                let rank = index + 1
                
                
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
                     }
            }
            
            // If current user is not in top 10, add them to display
            if !currentUserFound, let currentUser = userSession.currentUser, let currentUserAuthUID = currentUserAuthUID {
                let currentUserWatchTime = currentUser.globalWatchTime ?? 0
                let currentUserMinutes = Int(currentUserWatchTime / 60)
                
                // Use EXACTLY the same userName as Profile page
                let currentUserName = currentUser.userName ?? "Me"
                
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
            savedWords = Array(targetLanguage.unknownWords)
        } else {
            savedWords = []
        }
    }
    
    private func generateStudyDates() {
        // Get study dates from real user data instead of mock data
        studyDates = extractStudyDatesFromUserData()
    }
    
    /// Extract study dates from user's daily watch time records for current month
    private func extractStudyDatesFromUserData() -> Set<Int> {
        guard let user = self.user else {
            print("🔍 Calendar Debug - No user data available")
            return Set<Int>()
        }
        
        // Try to get language-specific daily data first (prioritize target language)
        if let languagesData = user.languagesData,
           let targetLanguage = self.targetLanguage?.lowercased(),
           let languageData = languagesData[targetLanguage],
           let watchTime = languageData.watchTime,
           let dailyWatchTime = watchTime.daily {
            
            return extractStudyDatesFromDailyData(dailyWatchTime, source: "target language (\(targetLanguage))")
        }
        
        // Fallback to first available language with daily data
        if let languagesData = user.languagesData {
            for (languageKey, languageData) in languagesData {
                if let watchTime = languageData.watchTime,
                   let dailyWatchTime = watchTime.daily,
                   !dailyWatchTime.isEmpty {
                    
                     return extractStudyDatesFromDailyData(dailyWatchTime, source: "fallback language (\(languageKey))")
                }
            }
        }
        
        
        // TEMP FIX: Generate calendar dates based on global watch time when no daily data exists
        if let globalWatchTime = user.globalWatchTime, globalWatchTime > 0 {
           return generateFallbackCalendarDates(from: globalWatchTime)
        }
        
        return Set<Int>()
    }
    
    /// Helper method to extract study dates from daily watch time data
    private func extractStudyDatesFromDailyData(_ dailyWatchTime: [String: Double], source: String) -> Set<Int> {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        var studyDaysInCurrentMonth = Set<Int>()
        
        // Minimum watch time threshold (10 seconds = any meaningful video watching)
        let minimumWatchTime: Double = 10.0
        
        for (dateString, watchTimeSeconds) in dailyWatchTime {
            // Parse date string in format "yyyy-MM-dd"
            if let studyDate = parseDateString(dateString),
               watchTimeSeconds >= minimumWatchTime {
                
                let studyYear = calendar.component(.year, from: studyDate)
                let studyMonth = calendar.component(.month, from: studyDate)
                let studyDay = calendar.component(.day, from: studyDate)
                
                // Only include dates from current month and year
                if studyYear == currentYear && studyMonth == currentMonth {
                    studyDaysInCurrentMonth.insert(studyDay)
                    print("🔍 Calendar Debug - Added study day: \(studyDay) (\(String(format: "%.1f", watchTimeSeconds))s)")
                }
            }
        }
        
         return studyDaysInCurrentMonth
    }
    
    /// Parse date string in "yyyy-MM-dd" format to Date object
    private func parseDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
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
    
    /// Migrate existing global watch time to language-specific data if needed
    private func migrateWatchTimeIfNeeded(for user: User) async {
        guard let globalWatchTime = user.globalWatchTime,
              globalWatchTime > 0,
              !user.targetLanguage.isEmpty else {
            return
        }
        
        let languageKey = user.targetLanguage.lowercased()
        
        // Check if language-specific data already exists
        if let languagesData = user.languagesData,
           let languageData = languagesData[languageKey],
           let watchTime = languageData.watchTime,
           let total = watchTime.total,
           total > 0 {
            return
        }
        
        
        // Perform migration
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        do {
            let userRef = db.collection("users").document(userID)
            
            try await db.runTransaction { transaction, errorPointer in
                let userDocument: DocumentSnapshot
                do {
                    userDocument = try transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Get current languages data
                var languagesData = userDocument.data()?["languagesData"] as? [String: [String: Any]] ?? [:]
                
                // Initialize language data if it doesn't exist
                if languagesData[languageKey] == nil {
                    languagesData[languageKey] = [:]
                }
                
                // Create watch time data with migrated global time and estimated daily distribution
                let migratedWatchTime: [String: Any] = [
                    "total": globalWatchTime,
                    "daily": self.generateEstimatedDailyData(from: globalWatchTime)
                ]
                
                // Update the language data
                languagesData[languageKey]!["watchTime"] = migratedWatchTime
                
                // Update the user document
                transaction.updateData(["languagesData": languagesData], forDocument: userRef)
                
              
                return nil
            }
            
        } catch {
            print("🔍 Migration Debug - Failed to migrate watch time: \(error)")
        }
    }
    
    /// Generate estimated daily watch data based on total watch time for calendar display
    private func generateEstimatedDailyData(from totalWatchTime: Double) -> [String: Double] {
        guard totalWatchTime > 0 else { return [:] }
        
        let currentDate = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var dailyData: [String: Double] = [:]
        
        // Estimate how many days the user has been watching based on total time
        // Assume average watching session of 120 seconds (2 minutes)
        let averageSessionTime: Double = 120.0
        let estimatedSessions = max(1, Int(totalWatchTime / averageSessionTime))
        let estimatedDays = min(estimatedSessions, 15) // Max 15 days spread
        
        // Create daily distribution over recent days
        for i in 0..<estimatedDays {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: currentDate) {
                let dateString = formatter.string(from: pastDate)
                
                // Distribute watch time somewhat randomly but realistically
                let sessionTime = min(totalWatchTime / Double(estimatedDays), averageSessionTime * 2)
                if sessionTime >= 10.0 { // Only add if meaningful watch time
                    dailyData[dateString] = sessionTime
                }
            }
        }
        
        
        return dailyData
    }
    
    /// Generate fallback calendar dates when network migration fails
    private func generateFallbackCalendarDates(from totalWatchTime: Double) -> Set<Int> {
        guard totalWatchTime > 0 else { return Set<Int>() }
        
        let currentDate = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        var studyDays = Set<Int>()
        
        // Estimate study days based on total watch time
        // Assume average 2 minutes per day = 120 seconds
        let averageSessionTime: Double = 120.0
        let estimatedDays = min(Int(totalWatchTime / averageSessionTime), 15) // Max 15 days
        
        // Add recent days as study days
        for i in 0..<estimatedDays {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: currentDate) {
                let dayOfMonth = calendar.component(.day, from: pastDate)
                let monthOfDate = calendar.component(.month, from: pastDate)
                let yearOfDate = calendar.component(.year, from: pastDate)
                
                // Only include dates from current month and year
                if monthOfDate == currentMonth && yearOfDate == currentYear {
                    studyDays.insert(dayOfMonth)
                }
            }
        }
        
       
        return studyDays
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
