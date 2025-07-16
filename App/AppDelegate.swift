//
//  AppDelegate.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/27/25.
//


import UIKit
import Foundation
import FirebaseCore
import FirebaseAppCheck
import FirebaseMessaging
import UserNotifications


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        // 🔑 Log out user if app is freshly installed
        LaunchManager.shared.checkFirstLaunchAndLogoutIfNeeded()
        
        return true
    }
    
    func application(_ application: UIApplication,
                         didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Messaging.messaging().apnsToken = deviceToken
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            let userInfo = response.notification.request.content.userInfo

            if let videoId = userInfo["videoId"] as? String {
                NotificationCenter.default.post(name: .openFromNotification, object: nil, userInfo: [
                    "videoId": videoId
                ])
            }

            completionHandler()
        }
}

extension Notification.Name {
    static let openFromNotification = Notification.Name("openFromNotification")
}


