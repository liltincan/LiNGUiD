//
//  Comment.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 7/14/25.
//


import Foundation

struct Comment: Identifiable, Codable {
    let id: String
    let videoId: String
    let userId: String
    let username: String
    let userProfilePicture: String?
    let text: String
    let timestamp: Date
    let likes: Int
    let dislikes: Int
    let replies: [Comment]?
    let isReply: Bool
    let parentCommentId: String?
    let likedBy: [String]?
    let dislikedBy: [String]?
    
    init(
        id: String = UUID().uuidString,
        videoId: String,
        userId: String,
        username: String,
        userProfilePicture: String? = nil,
        text: String,
        timestamp: Date = Date(),
        likes: Int = 0,
        dislikes: Int = 0,
        replies: [Comment]? = nil,
        isReply: Bool = false,
        parentCommentId: String? = nil,
        likedBy: [String]? = nil,
        dislikedBy: [String]? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.userId = userId
        self.username = username
        self.userProfilePicture = userProfilePicture
        self.text = text
        self.timestamp = timestamp
        self.likes = likes
        self.dislikes = dislikes
        self.replies = replies
        self.isReply = isReply
        self.parentCommentId = parentCommentId
        self.likedBy = likedBy
        self.dislikedBy = dislikedBy
    }
    
    // Computed property for relative time display
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
