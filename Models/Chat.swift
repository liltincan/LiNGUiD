//
//  Chat.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 6/23/25.
//

import Firebase
import FirebaseFirestore

//MARK: - Model for Users Friends Information
struct Chat: Identifiable {
    var id: String
    var participantIDs: [String]
    var lastMessage: String
    var username: String
    var status: String
    var flag: String
    var profileimage: String
    var isActive: Bool
    var lastSeen: Date?
    var hiddenFor: [String]? = []
}
//MARK: - Model for Chat Messages
struct ChatMessages: Identifiable, Equatable {
    let id = UUID()
    var text: String
    //who is replying
    var isFromCurrentUser: Bool
   // var isRead: Bool
}
//MARK: - Model for which Conversation it is with their messages
struct ChatConversation: Identifiable {
    let id = UUID()
    var friend: Chat
    var messages: [ChatMessages]
}
//MARK: - Focus Field to control the keyboard typing
enum FocusField {
    case sendMessage
}


