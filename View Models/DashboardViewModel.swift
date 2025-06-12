//
//  DashboardViewModel.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 6/7/25.
//
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject{
    @Published var user: User?
    @Published var errorMessage: String = ""
    @Published var userLevel: Int = 0
    @Published var totalWatchTime: Double = 0
    @Published var totalHours: Int = 32
    @Published var monthlyHoursIncrease: Int = 14
    @Published var userRank: Int = 4
    @Published var savedWords: [WordPair] = []
    @Published var studyDates: Set<Int> = []
    @Published var currentMonth: String = ""
    @Published var leaderboardUsers: [LeaderboardUser] = []
    @Published var isLoading: Bool = false
    
    var userSession: UserSessionViewModel

    init(userSession: UserSessionViewModel) {
        self.userSession = userSession
        setupCurrentMonth()
        setupMockLeaderboard()
    }
    
    func fetchUserData() async {
        isLoading = true
        await userSession.refreshUser()
        
        print("user Is Fetched")
        
        if let user = userSession.currentUser {
            self.user = user
            if let userLanguageData = user.languagesData?[user.targetLanguage] {
                self.userLevel = userLanguageData.comprehensionLevel ?? 0
                self.totalWatchTime = userLanguageData.watchTime?.total ?? 0
            }
            
            // 计算用户数据
            calculateUserStats(from: user)
            loadSavedWords(from: user)
            generateStudyDates()
            
            isLoading = false
        } else {
            errorMessage = "User not found"
            isLoading = false
        }
    }
    
    func loadDashboardData() async {
        await fetchUserData()
    }
    
    private func calculateUserStats(from user: User) {
        let totalWatchTime = user.globalWatchTime ?? 0
        userLevel = Int(totalWatchTime / 3600) + 1
        
        totalHours = Int((totalWatchTime) / 3600)
        
        monthlyHoursIncrease = 14
        
        userRank = 4
    }
    
    private func loadSavedWords(from user: User) {
        if let targetLanguage = user.languagesData?[user.targetLanguage]?.savedWords {
            savedWords = Array(targetLanguage.unknownWords)
        } else {
            savedWords = [
                WordPair(target: "fraiche", native: "fresh"),
                WordPair(target: "aimer", native: "to love"),
                WordPair(target: "fille", native: "girl"),
                WordPair(target: "voir", native: "to see"),
                WordPair(target: "jaune", native: "yellow")
            ]
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
        leaderboardUsers = [
            LeaderboardUser(id: "1", name: "starryskies23", minutes: 59, rank: 2, avatarURL: "https://images.unsplash.com/photo-1494790108755-2616b612b1c?w=150&h=150&fit=crop&crop=face"),
            LeaderboardUser(id: "2", name: "Eloise", minutes: 60, rank: 1, avatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face"),
            LeaderboardUser(id: "3", name: "nebulanomad", minutes: 55, rank: 3, avatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face"),
            LeaderboardUser(id: "4", name: "Me", minutes: 4, rank: 15, avatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face")
        ]
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
