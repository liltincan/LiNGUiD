//
//  User.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/29/25.
//
import Foundation
import Firebase
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String?
    var username: String?
    var createdAt: Date?
    var flameDate: Date?
    var flameStatus: String?
    var globalWatchTime: Double?
    var interests: [String]?
    var languagesData: [String: LanguageData]?
    var likedVideos: [String]?
    var streak: Int?
}

struct LanguageData: Codable {
    var comprehensionLevel: Int?
    var dailyGoal: String?
    var isBeginnerLevel: Bool?
    var motivation: String?
    var timestamp: Date?
    var watchTime: WatchTime?
}

struct WatchTime: Codable {
    var daily: [String: Double]?
    var total: Double?
}
