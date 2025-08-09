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
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var window: UIWindow?
    // Keep the completion handler the system gives us until the session says "I'm done".
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void) {
        // Recreate the session so delegates will be called
        BackgroundUploader.shared.recreateSessionIfNeeded(identifier: identifier)
        BackgroundUploader.shared.setSystemCompletionHandler(completionHandler)
        print("[BG] handleEventsForBackgroundURLSession \(identifier)")
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        //intialize the Firebase & AppCheck
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        FirebaseApp.configure()
        
        //this sets the delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        //request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Permission granted: \(granted)")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        //log out user on first install
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
        if let token = fcmToken,
           let userID = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users").document(userID).setData(["fcmToken": token], merge: true)
            print("Saved FCM token for user \(userID): \(token)")
        }
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
        //show the banner even when the app is in the foreground
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let openFromNotification = Notification.Name("openFromNotification")
}
