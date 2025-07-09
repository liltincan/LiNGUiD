//
//  ChatListViewModel.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 6/23/25.
//

import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseAuth
 
@MainActor
//NOTE: - Can use the OBSERVABLE MACRO
class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var discoverableUsers: [Chat] = []
    @Published var conversations : [ChatConversation] = []
    @Published var chattedUserIDs: Set<String> = []
    @Published var isInitialLoadDone = false

    //look at the database now
    private var db = Firestore.firestore()
    //will keep track of each updates that are being made at the moment
    private var listener: ListenerRegistration?
    //this will be updating when changes are made in the user profile
    private var userListeners: [String: ListenerRegistration] = [:]

    
    init(){
        fetchChats()
    }
    //MARK: - Fetch Chats
    //precondition: none
    //postcondition: going to fetch all the chats
    func fetchChats() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        listener = db.collection("chat")
            .whereField("participantIDs", arrayContains: currentUserID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching chats \(error?.localizedDescription ?? "Unknown Error")")
                    return
                }
                var newChats: [Chat] = []
                var userIDs: Set<String> = []
                let dispatchGroup = DispatchGroup()
                var newConversations: [ChatConversation] = []

                for doc in documents {
                    let data = doc.data()
                    let participants = data["participantIDs"] as? [String] ?? []

                    if let hiddenFor = data["hiddenFor"] as? [String], hiddenFor.contains(currentUserID) {
                        continue
                    }

                    guard let otherUserID = participants.first(where: { $0 != currentUserID }) else {
                        continue
                    }

                    userIDs.insert(otherUserID)
                    dispatchGroup.enter()

                    //start the user snapshot listener if it's needed
                    if self.userListeners[otherUserID] == nil {
                        let userListener = self.db.collection("users").document(otherUserID).addSnapshotListener { snapshot, _ in
                            guard let userData = snapshot?.data() else { return }

                            if let index = self.chats.firstIndex(where: { $0.participantIDs.contains(otherUserID) }) {
                                var updatedChat = self.chats[index]
                                updatedChat.username = userData["username"] as? String ?? "Unknown"
                                updatedChat.status = userData["status"] as? String ?? ""
                                updatedChat.country = userData["country"] as? String ?? ""
                                updatedChat.profileimage = userData["profilePhotoUrl"] as? String ?? "defaultProfile"
                                updatedChat.isActive = userData["isActive"] as? Bool ?? false
                                updatedChat.lastSeen = (userData["lastSeen"] as? Timestamp)?.dateValue()
                                self.chats[index] = updatedChat
                                //updating the conversation as well
                                if let convoIndex = self.conversations.firstIndex(where: { $0.friend.id == updatedChat.id }) {
                                    self.conversations[convoIndex].friend = updatedChat
                                }
                            }
                        }

                        self.userListeners[otherUserID] = userListener
                    }

                    self.db.collection("users").document(otherUserID).getDocument { userSnapshot, _ in
                        let userData = userSnapshot?.data()
                        //this is the data that goes in the database which is the chat information
                        let chat = Chat(
                            id: doc.documentID,
                            participantIDs: participants,
                            lastMessage: data["lastMessage"] as? String ?? "",
                            username: userData?["username"] as? String ?? "Unknown",
                            status: userData?["status"] as? String ?? "",
                            country: userData?["country"] as? String ?? "",
                            profileimage: userData?["profilePhotoUrl"] as? String ?? "defaultProfile",
                            isActive: userData?["isActive"] as? Bool ?? false,
                            lastSeen: (userData?["lastSeen"] as? Timestamp)?.dateValue(),
                            hiddenFor: data["hiddenFor"] as? [String] ?? [],
                            lastMessageTimestamp: (data["lastMessageTimestamp"] as? Timestamp)?.dateValue()
                        )

                        //now fetching for the messages in chat
                        self.fetchMessages(for: doc.documentID) { messages in
                            newChats.append(chat)
                            newConversations.append(ChatConversation(friend: chat, messages: messages))
                            dispatchGroup.leave()
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    let chatMap = Dictionary(uniqueKeysWithValues: newChats.map { ($0.id, $0) })
                    //this will sort the chats (updates by lastMessage that was send by them)
                    let sortedChats = newChats.sorted {
                        let date1 = $0.lastMessageTimestamp ?? .distantPast
                        let date2 = $1.lastMessageTimestamp ?? .distantPast
                        return date1 > date2
                    }
                    let sortedConversations = newConversations.sorted {
                        let date1 = chatMap[$0.friend.id]?.lastMessageTimestamp ?? .distantPast
                        let date2 = chatMap[$1.friend.id]?.lastMessageTimestamp ?? .distantPast
                        return date1 > date2
                    }
                    self.chats = sortedChats
                    self.conversations = sortedConversations
                    self.chattedUserIDs = userIDs
                    self.isInitialLoadDone = true
                }
            }
    }
    //MARK: - Start Chat
    //precondiition: none
    //postcondition: going to start a chat with the current user and another user and have subcollection called 'messages'
    func startChat(with otherUserID: String, completion: ((String) -> Void)? = nil) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let chatQuery = db.collection("chat")
            .whereField("participantIDs", arrayContains: currentUserID)

        chatQuery.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            let existing = snapshot?.documents.first(where: {
                let participants = $0.data()["participantIDs"] as? [String] ?? []
                return participants.contains(otherUserID)
            })
            //this will be a message that is being send when the users first interacts with other users
            let hiMessage = "Hi!"
            
            if let existingDoc = existing {
                let chatRef = self.db.collection("chat").document(existingDoc.documentID)
                let hiddenFor = existingDoc.data()["hiddenFor"] as? [String] ?? []

                if hiddenFor.contains(currentUserID) {
                    chatRef.updateData([
                        "hiddenFor": FieldValue.arrayRemove([currentUserID]),
                        "lastMessage": hiMessage,
                        "lastMessageTimestamp": FieldValue.serverTimestamp(),
                        "messageResetTimestamps.\(currentUserID)": FieldValue.serverTimestamp()
                    ]) { _ in
                        chatRef.collection("messages").addDocument(data: [
                            "text": hiMessage,
                            "senderID": currentUserID,
                            "timestamp": FieldValue.serverTimestamp(),
                            "isRead": false
                        ])
                        self.fetchChats()
                        completion?(existingDoc.documentID)
                    }
                }
                else {
                    chatRef.collection("messages").addDocument(data: [
                        "text": hiMessage,
                        "senderID": currentUserID,
                        "timestamp": FieldValue.serverTimestamp(),
                        "isRead": false
                    ])
                    chatRef.updateData([
                        "lastMessage": hiMessage,
                        "lastMessageTimestamp": FieldValue.serverTimestamp()
                    ])
                    self.fetchChats()
                    completion?(existingDoc.documentID)
                }

                return
            }

            //if no chat exists then create a new one
            let chatRef = self.db.collection("chat").document()
            //data that will go in the field for 'chats'
            let chatData: [String: Any] = [
                "participantIDs": [currentUserID, otherUserID],
                "lastMessage": hiMessage,
                "lastMessageTimestamp": FieldValue.serverTimestamp()
            ]
            chatRef.setData(chatData) { err in
                if let err = err {
                    print("Error creating chat: \(err)")
                    return
                }
                chatRef.collection("messages").addDocument(data: [
                    "text": hiMessage,
                    "senderID": currentUserID,
                    "timestamp": FieldValue.serverTimestamp(),
                    "isRead": false
                ])
                self.fetchChats()
                completion?(chatRef.documentID)
            }
        }
    }
    
    //MARK: - Fetch Messages
    //precondition: none
    //postcondition: going to retrieve the messages from the main chat
    func fetchMessages(for chatID: String, completion: @escaping ([ChatMessages]) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        //going in collection of 'chats' then subcollection to just retrieve the messages
        let chatRef = db.collection("chat").document(chatID)

        chatRef.getDocument { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else {
                completion([])
                return
            }
            //this will help keep track to clear the messges for the user that hides it
            let resetTimestamps = data["messageResetTimestamps"] as? [String: Timestamp]
            let resetTime = resetTimestamps?[currentUserID]?.dateValue()
            //then we fetch the messages (helper function)
            self.fetchAllMessages(for: chatID, after: resetTime, completion: completion)
        }
    }
    //private function that will help retrieve the messages based on reseting (who deleted the chat)
    private func fetchAllMessages(for chatID: String, after resetTime: Date?, completion: @escaping ([ChatMessages]) -> Void) {
        //get the messages and now going to order it by timestamp
        var query: Query = db.collection("chat")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp")
        if let resetTime = resetTime {
            query = query.whereField("timestamp", isGreaterThan: resetTime)
        }

        query.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                completion([])
                return
            }
            let messages = documents.compactMap { doc -> ChatMessages? in
                let data = doc.data()
                guard let text = data["text"] as? String,
                      let senderID = data["senderID"] as? String else { return nil }
                let isRead = data["isRead"] as? Bool ?? false
                return ChatMessages(
                    text: text,
                    isFromCurrentUser: senderID == Auth.auth().currentUser?.uid,
                    isRead: isRead
                )
            }
            completion(messages)
        }
    }
    // MARK: - Send Message
    // precondition: none
    // postcondition: this is the message when user sends a message to another user
    func sendMessage(_ text: String, to chatID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let chatRef = db.collection("chat").document(chatID)

        //getting the chat to determine who is the user
        chatRef.getDocument { [weak self] snapshot, _ in
            guard let self = self,
                  let data = snapshot?.data(),
                  let participantIDs = data["participantIDs"] as? [String],
                  let recipientID = participantIDs.first(where: { $0 != currentUserID }) else {
                return
            }

            //data that the 'message' will have and the isRead is false only for the user to view it
            let message: [String: Any] = [
                "text": text,
                "senderID": currentUserID,
                "timestamp": FieldValue.serverTimestamp(),
                "isRead": false
            ]
            //creating a collection now called 'messages'
            chatRef.collection("messages").addDocument(data: message) { error in
                if let error = error {
                    print(" Failed to send message: \(error)")
                } else {
                    chatRef.updateData([
                        "lastMessage": text,
                        "lastMessageTimestamp": FieldValue.serverTimestamp(),
                        "hiddenFor": FieldValue.arrayRemove([recipientID]),
                        "messageResetTimestamps.\(recipientID)": FieldValue.delete()
                    ]) { _ in
                        self.fetchChats()
                    }
                }
            }
        }
    }
    //MARK: - Delete the chat option
    //precondition: none
    //postcondition: will delete the chat and messages between the users
    /*func deleteEntireChat(chatID: String) {
        //keeps track of the chat that we need to find (find first then delete)
        let chatRef = db.collection("chat").document(chatID)
        //this will delete all the messages first
        chatRef.collection("messages").getDocuments { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching messages for deletion: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            let batch = self?.db.batch()
            for doc in documents {
                batch?.deleteDocument(doc.reference)
            }

            //now once the messages are deleted, you are now able to delete the chat
            batch?.commit { error in
                if let error = error {
                    print("Error deleting messages: \(error)")
                    return
                }
                chatRef.delete { error in
                    if let error = error {
                        print("Error deleting chat document: \(error)")
                    } else {
                        print("Chat and all messages successfully deleted.")
                        self?.conversations.removeAll(where: { $0.friend.id == chatID })
                        self?.chats.removeAll(where: { $0.id == chatID })
                    }
                }
            }
        }
    }*/
    //MARK: This deletes a chat for one user only
    //precondition: none
    //postcondition: this will hide (pretend it deletes) a chat from user until they both delete it
    func softDeleteChatForCurrentUser(chatID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        //this will hide the chat only
        let chatRef = db.collection("chat").document(chatID)
        chatRef.updateData([
            "hiddenFor": FieldValue.arrayUnion([currentUserID])
        ]) { [weak self] error in
            if let error = error {
                print("Failed to hide chat: \(error)")
            }
            else {
                self?.conversations.removeAll(where: { $0.friend.id == chatID })
                self?.chats.removeAll(where: { $0.id == chatID })
            }
        }
    }
    
    //MARK: - Fetch Discovery Page
    //precondition: none
    //postcondition: this will fetch discoverable users (all the users from the 'users' collections
    func fetchDiscoverableUsersFromUsers() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        //this is going to look in the 'users' collection and retrieve every single one of them
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let users = documents.filter { $0.documentID != currentUserID }
            let result = users.map { doc -> Chat in
                //data that will go in chat and we are going to add this information to the 'users' collection
                let data = doc.data()
                return Chat(
                    id: doc.documentID,
                    participantIDs: [],
                    lastMessage: "",
                    username: data["username"] as? String ?? "Unknown",
                    status: data["status"] as? String ?? "",
                    country: data["country"] as? String ?? "",
                    profileimage: data["profilePhotoUrl"] as? String ?? "defaultProfile",
                    isActive: data["isActive"] as? Bool ?? false,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                    hiddenFor: [],
                    lastMessageTimestamp: nil
                )
            }
            DispatchQueue.main.async {
                self?.discoverableUsers = result
            }
        }
    }
    //MARK: Will get users by country only
    //precondition: none
    //postcondition: gets the users by thier native language and you can add more than one native language to search
    func fetchUsersByNativeLanguages(_ languages: [String]) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        if (languages.isEmpty) {
            discoverableUsers = []
            return
        }
        //look at the 'users' collection and go in the field 'nativeLanguage'
        db.collection("users")
            .whereField("nativeLanguage", in: languages)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching users by languages: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                let users = documents.filter { $0.documentID != currentUserID }
                let result = users.map { doc -> Chat in
                    let data = doc.data()
                    return Chat(
                        id: doc.documentID,
                        participantIDs: [],
                        lastMessage: "",
                        username: data["username"] as? String ?? "Unknown",
                        status: data["status"] as? String ?? "",
                        country: data["country"] as? String ?? "",
                        profileimage: data["profilePhotoUrl"] as? String ?? "defaultProfile",
                        isActive: data["isActive"] as? Bool ?? false,
                        lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                        hiddenFor: [],
                        lastMessageTimestamp: nil
                    )
                }

                DispatchQueue.main.async {
                    self.discoverableUsers = result
                }
            }
    }


    
    //MARK: - Real time updates (will update right when the database changes)
    //precondition: none
    //postcodition: will allowed for messages to update right when you are sending and need to use @State since it is valid for Listener
    func listenToMessages(for chatID: String, onUpdate: @escaping ([ChatMessages]) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            onUpdate([])
            return
        }
        //go in the chat collection
        let chatRef = db.collection("chat").document(chatID)
        chatRef.getDocument { [weak self] snapshot, _ in
            guard let self = self, let data = snapshot?.data() else {
                onUpdate([])
                return
            }
            let resetTimestamps = data["messageResetTimestamps"] as? [String: Timestamp]
            let resetTime = resetTimestamps?[currentUserID]?.dateValue()
            var query: Query = chatRef.collection("messages").order(by: "timestamp")
            if let resetTime = resetTime {
                query = query.whereField("timestamp", isGreaterThan: resetTime)
            }
            query.addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                    onUpdate([])
                    return
                }

                let messages = documents.compactMap { doc -> ChatMessages? in
                    let data = doc.data()
                    guard let text = data["text"] as? String,
                          let senderID = data["senderID"] as? String else { return nil }

                    let isRead = data["isRead"] as? Bool ?? false
                    let isFromCurrentUser = senderID == currentUserID

                    return ChatMessages(
                        text: text,
                        isFromCurrentUser: isFromCurrentUser,
                        isRead: isRead
                    )
                }

                self.updateConversation(chatID: chatID, with: messages)
                onUpdate(messages)
            }
        }
    }
    //precondition: none
    //postcondition: this is going to be used for the isRead and determine who send it
    func markMessagesAsRead(for chatID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        let messagesRef = db.collection("chat").document(chatID).collection("messages")
        messagesRef.whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                //going to check which user did not read it
                let unreadMessages = docs.filter { doc in
                    let senderID = doc.data()["senderID"] as? String
                    return senderID != currentUserID
                }
                guard !unreadMessages.isEmpty else { return }
                let batch = self.db.batch()
                for doc in unreadMessages {
                    batch.updateData(["isRead": true], forDocument: doc.reference)
                }
                batch.commit { _ in
                    print("Marked \(unreadMessages.count) messages as read")
                }
            }
    }
    private func updateConversation(chatID: String, with messages: [ChatMessages]) {
        if let chatIndex = self.conversations.firstIndex(where: { $0.friend.id == chatID }) {
            var convo = self.conversations[chatIndex]
            convo.messages = messages
            self.conversations[chatIndex] = convo
        }
    }
    
    //need this so it can clean up the listener (no memory leaks
    deinit {
        listener?.remove()
        userListeners.values.forEach { $0.remove() }
    }
}

extension ChatConversation {
    var hasUnreadMessages: Bool {
        messages.contains { !$0.isFromCurrentUser && !$0.isRead }
    }
}

