//
//  AppDelegate.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/27/25.
//


import UIKit
import FirebaseCore
import FirebaseAppCheck
import FirebaseMessaging


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        
        FirebaseApp.configure()

        // 🔑 Log out user if app is freshly installed
        LaunchManager.shared.checkFirstLaunchAndLogoutIfNeeded()
        
        return true
    }
    
    func application(_ application: UIApplication,
                         didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Messaging.messaging().apnsToken = deviceToken
    }
}

