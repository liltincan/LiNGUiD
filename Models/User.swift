import Firebase
import FirebaseFirestore
//
//  User.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/29/25.
//
import Foundation

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String?
    var userName: String?
    var createdAt: Date?
    var flameDate: Date?
    var flameStatus: String?
    var globalWatchTime: Double?
    var interests: [String]?
    var targetLanguage: String = ""
    var nativeLanguage: String?
    var nativeLanguageList: [String]?
    var languagesData: [String: LanguagesData]?
    var likedVideos: [String]?
    var savedVideos: [String]?
    var watchedVideos: [String]?
    var uploadedVideos: [String]?
    var followers: [String]?
    var following: [String]?
    var chats: [String]?
    var country: String?
    var streak: Int?
    var profilePhotoUrl: String?
    var didCompleteOnboarding: Bool?

    enum CodingKeys: CodingKey {
        case id, email, userName, createdAt, flameDate, flameStatus,
            globalWatchTime, interests, targetLanguage, languagesData,
            likedVideos, savedVideos, watchedVideos, uploadedVideos,
            nativeLanguage, nativeLanguageList,
            followers, following, chats, country, streak, profilePhotoUrl, didCompleteOnboarding
    }

    private enum AlternateKeys: String, CodingKey {
        case username
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        if let name = try? container.decodeIfPresent(
            String.self,
            forKey: .userName
        ) {
            userName = name
        } else {
            let altContainer = try decoder.container(
                keyedBy: AlternateKeys.self
            )
            userName = try altContainer.decodeIfPresent(
                String.self,
                forKey: .username
            )
        }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        flameDate = try container.decodeIfPresent(Date.self, forKey: .flameDate)
        flameStatus = try container.decodeIfPresent(
            String.self,
            forKey: .flameStatus
        )
        globalWatchTime = try container.decodeIfPresent(
            Double.self,
            forKey: .globalWatchTime
        )
        interests = try container.decodeIfPresent(
            [String].self,
            forKey: .interests
        )
        targetLanguage =
            try container.decodeIfPresent(String.self, forKey: .targetLanguage)
            ?? ""
        nativeLanguage = try container.decodeIfPresent(String.self, forKey: .nativeLanguage)
        languagesData = try container.decodeIfPresent(
            [String: LanguagesData].self,
            forKey: .languagesData
        )
        profilePhotoUrl = try container.decodeIfPresent(
            String.self,
            forKey: .profilePhotoUrl
        )

        likedVideos =
            try container.decodeIfPresent([String].self, forKey: .likedVideos)
            ?? []
        savedVideos =
            try container.decodeIfPresent([String].self, forKey: .savedVideos)
            ?? []
        watchedVideos =
            try container.decodeIfPresent([String].self, forKey: .watchedVideos)
            ?? []
        uploadedVideos =
            try container.decodeIfPresent(
                [String].self,
                forKey: .uploadedVideos
            ) ?? []
        followers =
            try container.decodeIfPresent([String].self, forKey: .followers)
            ?? []
        following =
            try container.decodeIfPresent([String].self, forKey: .following)
            ?? []
        chats =
            try container.decodeIfPresent([String].self, forKey: .chats) ?? []
        country = try container.decodeIfPresent(String.self, forKey: .country)
        streak = try container.decodeIfPresent(Int.self, forKey: .streak)
        profilePhotoUrl = try container.decodeIfPresent(
            String.self,
            forKey: .profilePhotoUrl
        )
    }

}

struct FirestoreUserPatch: Codable {
    let languagesData: [String: LanguagesData]
}

struct LanguagesData: Codable {
    var savedWords: WordLists?
    var comprehensionLevel: Int?
    var dailyGoal: String?
    var isBeginnerLevel: Bool?
    var motivation: String?
    var timestamp: Date?
    var watchTime: WatchTime?

    enum CodingKeys: String, CodingKey {
        case savedWords, comprehensionLevel, dailyGoal, isBeginnerLevel,
            motivation, timestamp, watchTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedWords = try container.decodeIfPresent(
            WordLists.self,
            forKey: .savedWords
        )
        comprehensionLevel = try container.decodeIfPresent(
            Int.self,
            forKey: .comprehensionLevel
        )
        dailyGoal = try container.decodeIfPresent(
            String.self,
            forKey: .dailyGoal
        )
        isBeginnerLevel = try container.decodeIfPresent(
            Bool.self,
            forKey: .isBeginnerLevel
        )
        motivation = try container.decodeIfPresent(
            String.self,
            forKey: .motivation
        )
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        watchTime = try container.decodeIfPresent(
            WatchTime.self,
            forKey: .watchTime
        )
    }

    init(savedWords: WordLists) {
        self.savedWords = savedWords
    }

    init(comprehensionLevel: Int, timestamp: Date) {
        self.comprehensionLevel = comprehensionLevel
        self.timestamp = timestamp
    }

}

struct WrappedSavedWords: Codable {
    var savedWords: WordLists
}

struct WordLists: Codable {
    var knownWords: [WordPair] = []
    var unknownWords: [WordPair] = []

    init(knownWords: [WordPair], unknownWords: [WordPair]) {
        self.knownWords = knownWords
        self.unknownWords = unknownWords
    }

    enum CodingKeys: String, CodingKey {
        case knownWords, unknownWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        knownWords =
            try container.decodeIfPresent([WordPair].self, forKey: .knownWords)
            ?? []
        unknownWords =
            try container.decodeIfPresent(
                [WordPair].self,
                forKey: .unknownWords
            ) ?? []
    }
}

struct WordPair: Codable {
    var target: String  // the foreign word
    var native: String  // the translation
}

struct WatchTime: Codable {
    var daily: [String: Double]?
    var total: Double?

    enum CodingKeys: String, CodingKey {
        case daily, total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeIfPresent(Double.self, forKey: .total)
        daily = try container.decodeIfPresent([String: Double].self, forKey: .daily)
    }
}
