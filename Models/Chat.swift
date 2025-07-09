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
    let id: String
    let participantIDs: [String]
    var lastMessage: String
    var username: String
    var status: String
    var country: String
    var profileimage: String
    var isActive: Bool
    var lastSeen: Date?
    var hiddenFor: [String]
    var lastMessageTimestamp: Date?
    
    //this will then be used in the view to get the flag emoji (computed property that will be used in view)
    var flag: String {
        flagEmoji(for: country)
    }
}
//precondition: none
//postcondition: going to convert the field 'country' to a flag emoji
func flagEmoji(for country: String) -> String {
    let base : UInt32 = 127397
    let countryCode = countryCodeFromCountryName(country)
    guard countryCode.count == 2 else { return "" }
    var scalarView = String.UnicodeScalarView()
    for scalar in countryCode.uppercased().unicodeScalars {
        if let scalarValue = UnicodeScalar(base + scalar.value) {
            scalarView.append(scalarValue)
        }
    }
    return String(scalarView)
}
//precondition: none
//postcondition: going to map the country  name with short term such as United States-> US
func countryCodeFromCountryName(_ name: String) -> String {
    let countryMapping: [String: String] = [
        "United States": "US",
        "France": "FR",
        "Germany": "DE",
        "Spain": "ES",
        "Canada": "CA",
        "Mexico": "MX",
        "United Kingdom": "GB",
        "Japan": "JP",
        "China": "CN",
        "South Korea": "KR"
    ]
    return countryMapping[name] ?? ""
}

//MARK: - Model for Chat Messages
struct ChatMessages: Identifiable, Equatable {
    let id = UUID()
    var text: String
    //who is replying
    var isFromCurrentUser: Bool
    var isRead: Bool
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


