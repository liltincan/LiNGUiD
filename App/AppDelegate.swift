//
//  AppDelegate.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/27/25.
//


import UIKit
import FirebaseCore
import FirebaseAppCheck


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        
        FirebaseApp.configure()
        return true
    }
}

