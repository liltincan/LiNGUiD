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
    @Published var userLevel:Int = 0
    @Published var totalWatchTime:Double = 0
    @Published var isLoading:Bool = false
    
    
    private let userSession: UserSessionViewModel

        init(userSession: UserSessionViewModel) {
            self.userSession = userSession
        }
    
    
    
    
    func fetchUserData() async{
        isLoading = true
        await userSession.refreshUser()
        
        print("user Is Fetched")
        
        if let user = userSession.currentUser {
            self.user = user
            if let userLanguageData = user.languagesData?[user.targetLanguage] {
                self.userLevel = userLanguageData.comprehensionLevel ?? 0
                self.totalWatchTime = userLanguageData.watchTime?.total ?? 0
            }
            
            isLoading = false
        } else{
            errorMessage = "User not found"
            isLoading = false
        }

    }
}
