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


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        // 🔑 Log out user if app is freshly installed
        LaunchManager.shared.checkFirstLaunchAndLogoutIfNeeded()
        
        return true
    }
    
    func application(_ application: UIApplication,
                         didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Messaging.messaging().apnsToken = deviceToken
            Messaging.messaging().token { token, error in
                    if let error = error {
                        print("Error fetching FCM token after setting APNs token: \(error)")
                        return
                    }
                    print("FCM token after APNs token set: \(token ?? "none")")
                }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
            print("Firebase registration token: \(fcmToken ?? "")")
            // Save token to backend here
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
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the banner even in foreground
        completionHandler([.banner, .sound])
    }

}

extension Notification.Name {
    static let openFromNotification = Notification.Name("openFromNotification")
}


