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
    var email: String
    var username: String
    var uploadedVideos: [String]?
    var savedVideos: [String]?
    var watchedVideos: [String]?
    var likedVideos: [String]?
    var chats: [String]?
    var savedWords: [String]?
    var followers: [String] = []
    var following: [String] = []
    var country: String
    var nativeLanguages: [String] = []
    var targetLanguages: [TargetLanguage] = []
}

struct TargetLanguage: Codable {
    var language: String
    var level: Int
}
