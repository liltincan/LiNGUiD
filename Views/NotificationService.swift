import Firebase
import FirebaseMessaging
import FirebaseAuth
import UserNotifications

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }

            print("Notification permission granted: \(granted)")
            guard granted else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }

            Messaging.messaging().token { token, error in
                if let error = error {
                    print("Error fetching FCM token: \(error)")
                } else if let token = token {
                    print("Fetched FCM token: \(token)")
                    self.saveTokenToFirestore(token: token)
                }
            }
        }

        Messaging.messaging().delegate = self
    }


    // Called when APNs successfully registers device
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // Called when FCM token is available/refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM Token:", token)
        
        saveTokenToFirestore(token: token)
    }

    private func saveTokenToFirestore(token: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userID).setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("Error saving FCM token: \(error)")
            } else {
                print("FCM token saved to Firestore")
            }
        }
    }
}

