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
    private var authListener: AuthStateDidChangeListenerHandle?
    private var userSnapListener: ListenerRegistration?
    
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

        startAdminSubscriptionWatcher()
        
        //log out user on first install
        LaunchManager.shared.checkFirstLaunchAndLogoutIfNeeded()
        
        return true
    }

    private func startAdminSubscriptionWatcher() {
        // Tear down old listeners if any
        if let h = authListener { Auth.auth().removeStateDidChangeListener(h) }
        userSnapListener?.remove()
        userSnapListener = nil

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // Stop any previous user doc listener
            self?.userSnapListener?.remove()
            self?.userSnapListener = nil

            guard let self, let user = user else {
                // ensure we’re not on the admins topic
                Messaging.messaging().unsubscribe(fromTopic: "admins") { _ in
                    print("[Push] unsubscribed from admins (no user)")
                }
                return
            }

            // Ensure we have an FCM token
            Messaging.messaging().token { token, err in
                print("[Push] current FCM token =", token ?? "nil", "err:", String(describing: err))
            }

            // Listen to the user doc so we react if isAdmin flips later
            let docRef = Firestore.firestore().collection("users").document(user.uid)
            self.userSnapListener = docRef.addSnapshotListener { snap, err in
                if let err = err {
                    print("[Push] user snapshot error:", err)
                    return
                }
                let isAdmin = (snap?.data()?["isAdmin"] as? Bool) == true
                self.updateAdminTopic(isAdmin: isAdmin)
            }
        }
    }

    private func updateAdminTopic(isAdmin: Bool) {
        if isAdmin {
            Messaging.messaging().subscribe(toTopic: "admins") { err in
                if let err = err { print("[Push] subscribe failed:", err) }
                else { print("[Push] ✅ subscribed to admins") }
            }
        } else {
            Messaging.messaging().unsubscribe(fromTopic: "admins") { _ in
                print("[Push] unsubscribed from admins")
            }
        }
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
        guard let token = fcmToken else { return }

        if let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users").document(uid).setData(["fcmToken": token], merge: true)
            db.collection("users").document(uid).getDocument { snap, _ in
                let isAdmin = (snap?.data()?["isAdmin"] as? Bool) == true
                if isAdmin {
                    Messaging.messaging().subscribe(toTopic: "admins") { err in
                        if let err = err { print("[Push] subscribe failed:", err) }
                        else { print("[Push] ✅ subscribed to admins") }
                    }
                } else {
                    Messaging.messaging().unsubscribe(fromTopic: "admins") { _ in
                        print("[Push] unsubscribed from admins")
                    }
                }
            }
        }
    }


    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let kind = userInfo["kind"] as? String,
           kind == "report",
           let posterUid = userInfo["posterUid"] as? String,
           !posterUid.isEmpty {
            NotificationCenter.default.post(name: .pauseAllVideos, object: nil)
            
            NotificationCenter.default.post(
                name: .openProfileFromNotification,
                object: nil,
                userInfo: ["profileId": posterUid]
            )
            completionHandler()
            return
        }

        if let videoId = userInfo["videoId"] as? String {
            NotificationCenter.default.post(name: .openFromNotification, object: nil, userInfo: ["videoId": videoId])
            completionHandler()
            return
        }
        if let targetType = userInfo["targetType"] as? String,
           targetType == "video",
           let targetId = userInfo["targetId"] as? String {
            NotificationCenter.default.post(name: .openFromNotification, object: nil, userInfo: ["videoId": targetId])
            completionHandler()
            return
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
    static let openProfileFromNotification = Notification.Name("openProfileFromNotification")
    static let pauseAllVideos = Notification.Name("pauseAllVideos")
}
