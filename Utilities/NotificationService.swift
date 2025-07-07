//
//  NotificationService.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 7/6/25.
//

import Foundation
import SwiftUI
import UserNotifications
import Combine
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    @Published var showSettingsPage = false
    @Published var badgeNumber = 0
    var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        
        $badgeNumber
            .drop(while: {$0 < 1})
            .sink { badgeNumber in
            UIApplication.shared.applicationIconBadgeNumber = badgeNumber
        }.store(in: &cancellables)
    }
    
    func requestPushNotificationAuthorization() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert,
                .sound,
                .badge,
                .carPlay,
                .provisional,
                .criticalAlert,
                .providesAppNotificationSettings])
            
        } catch {
            print(error)
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        showSettingsPage = true
    }
}
