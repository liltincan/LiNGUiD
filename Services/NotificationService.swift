import Firebase
import FirebaseMessaging
import FirebaseAuth
import UserNotifications
import SwiftUI

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    @Published var notificationVideoId: String?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
                return
            }
            
            print("✅ Notification permission granted: \(granted)")
            guard granted else { return }
            
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("❌ Error fetching FCM token: \(error)")
                } else if let token = token {
                    print("📲 Initial FCM token: \(token)")
                    self.saveTokenToFirestore(token: token)
                }
            }
        }
    }
    
    // MARK: - FCM Token Updates
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔄 Refreshed FCM Token: \(token)")
        saveTokenToFirestore(token: token)
    }
    
    private func saveTokenToFirestore(token: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userID).setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("❌ Error saving FCM token to Firestore: \(error)")
            } else {
                print("✅ FCM token saved to Firestore")
            }
        }
    }
    
    // MARK: - APNs Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("📬 Registered with APNs")
    }
    
    // MARK: - Foreground Push Display
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📥 Notification received in foreground")
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - Notification Tap Handling
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let videoId = userInfo["videoId"] as? String {
            print("📲 Notification tapped with videoId: \(videoId)")
            notificationVideoId = videoId
        }
        
    }
}
