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
    var likedVideos: [String]
    var savedVideos: [String]
    var watchedVideos: [String]
    var uploadedVideos: [String]
    var followers: [String]
    var following: [String]
    var chats: [String]
    var country: String?
    var streak: Int?

    enum CodingKeys: CodingKey {
        case id, email, username, createdAt, flameDate, flameStatus,
             globalWatchTime, interests, languagesData,
             likedVideos, savedVideos, watchedVideos, uploadedVideos,
             followers, following, chats, country, streak
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        flameDate = try container.decodeIfPresent(Date.self, forKey: .flameDate)
        flameStatus = try container.decodeIfPresent(String.self, forKey: .flameStatus)
        globalWatchTime = try container.decodeIfPresent(Double.self, forKey: .globalWatchTime)
        interests = try container.decodeIfPresent([String].self, forKey: .interests)
        languagesData = try container.decodeIfPresent([String: LanguageData].self, forKey: .languagesData)

        likedVideos = try container.decodeIfPresent([String].self, forKey: .likedVideos) ?? []
        savedVideos = try container.decodeIfPresent([String].self, forKey: .savedVideos) ?? []
        watchedVideos = try container.decodeIfPresent([String].self, forKey: .watchedVideos) ?? []
        uploadedVideos = try container.decodeIfPresent([String].self, forKey: .uploadedVideos) ?? []
        followers = try container.decodeIfPresent([String].self, forKey: .followers) ?? []
        following = try container.decodeIfPresent([String].self, forKey: .following) ?? []
        chats = try container.decodeIfPresent([String].self, forKey: .chats) ?? []
        country = try container.decodeIfPresent(String.self, forKey: .country)
        streak = try container.decodeIfPresent(Int.self, forKey: .streak)
    }
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
