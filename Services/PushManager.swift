//
//  PushManager.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 9/13/25.
//

import FirebaseMessaging
import UserNotifications
import UIKit

final class PushManager: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = PushManager()

    func configureAndSubscribeIfAdmin(isAdmin: Bool) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        Messaging.messaging().delegate = self

        if isAdmin {
            Messaging.messaging().subscribe(toTopic: "admins") { error in
                if let error = error {
                    print("Topic sub failed:", error)
                } else {
                    print("Subscribed to admins topic")
                }
            }
        } else {
            Messaging.messaging().unsubscribe(fromTopic: "admins") { _ in
                print("Unsubscribed from admins topic")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        completionHandler()
    }
}

