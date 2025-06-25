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
    
    //look at the database now
    private var db = Firestore.firestore()
    //will keep track of each updates that are being made at the moment
    private var listener: ListenerRegistration?
    
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

                for doc in documents {
                    let data = doc.data()
                    let participants = data["participantIDs"] as? [String] ?? []
                    
                    //going to check if the chat is hidden for the current user (deleted by one user not the other)
                    if let hiddenFor = data["hiddenFor"] as? [String], hiddenFor.contains(currentUserID) {
                        continue
                    }
                    
                    guard let otherUserID = participants.first(where: { $0 != currentUserID }) else {
                        continue
                    }

                    userIDs.insert(otherUserID)
                    dispatchGroup.enter()
                    //going to get every update of the user profile when they update their information
                    self.db.collection("users").document(otherUserID).getDocument { snapshot, error in
                        defer { dispatchGroup.leave() }
                        let userData = snapshot?.data()
                        let chat = Chat(
                            id: doc.documentID,
                            participantIDs: participants,
                            lastMessage: data["lastMessage"] as? String ?? "",
                            username: userData?["username"] as? String ?? "Unknown",
                            status: userData?["status"] as? String ?? "",
                            flag: userData?["flag"] as? String ?? "",
                            profileimage: userData?["profilePhotoUrl"] as? String ?? "defaultProfile",
                            isActive: userData?["isActive"] as? Bool ?? false,
                            lastSeen: (userData?["lastSeen"] as? Timestamp)?.dateValue(),
                            hiddenFor: data["hiddenFor"] as? [String] ?? []
                        )
                        newChats.append(chat)
                    }
                }
                dispatchGroup.notify(queue: .main) {
                    self.chats = newChats
                    self.conversations = newChats.map {
                        ChatConversation(friend: $0, messages: [ChatMessages(text: $0.lastMessage, isFromCurrentUser: false)])
                    }
                    self.chattedUserIDs = userIDs
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
                let data = doc.data()
                return Chat(
                    id: doc.documentID,
                    participantIDs: [],
                    lastMessage: "",
                    username: data["username"] as? String ?? "Unknown",
                    status: data["status"] as? String ?? "",
                    flag: data["flag"] as? String ?? "",
                    profileimage: data["profilePhotoUrl"] as? String ?? "defaultProfile",
                    isActive: data["isActive"] as? Bool ?? false,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue()
                )
            }
            
            DispatchQueue.main.async {
                self?.discoverableUsers = result
            }
        }
    }
    //MARK: - Fetch Messages
    //precondition: none
    //postcondition: going to retrieve the messages from the main chat
    func fetchMessages(for chatID: String, completion: @escaping ([ChatMessages]) -> Void) {
        //going in collection of 'chats' then subcollection to just retrieve the messages
        db.collection("chat")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                    completion([])
                    return
                }
                let messages = documents.compactMap { doc -> ChatMessages? in
                    let data = doc.data()
                    guard let text = data["text"] as? String,
                          let senderID = data["senderID"] as? String else { return nil }
                    
                    return ChatMessages(
                        text: text,
                        isFromCurrentUser: senderID == Auth.auth().currentUser?.uid
                    )
                }
                completion(messages)
            }
    }
    //MARK: - Start Chat
    //precondiition: none
    //postcondition: going to start a chat with the current user and another user and have subcollection called 'messages'
    func startChat(with otherUserID: String, otherUserInfo: [String: Any], completion: ((String) -> Void)? = nil) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        //this will fetch the user information
        db.collection("users").document(currentUserID).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let currentUserData = snapshot?.data() else {
                print("Failed to get current user info")
                return
            }
            //the data that is going to go in the database but only for the 'userInfo' field
            let currentUserInfo: [String: Any] = [
                "username": currentUserData["username"] as? String ?? "Unknown",
                "status": currentUserData["status"] as? String ?? "",
                "flag": currentUserData["flag"] as? String ?? "",
                "profilePhotoUrl": currentUserData["profilePhotoUrl"] as? String ?? "defaultProfile",
                "isActive": currentUserData["isActive"] as? Bool ?? false
            ]

            //checking if the chat already exits and looking for their UID
            self.db.collection("chat")
                .whereField("participantIDs", arrayContains: currentUserID)
                .getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents else { return }
                    //now check if the chat exits if not then create chat
                    if let existing = documents.first(where: {
                        let participants = $0.data()["participantIDs"] as? [String] ?? []
                        return participants.contains(otherUserID)
                    }) {
                        //chat exists then you unhide it and reset the conversation with a new "Hi!"
                        print("Chat already exists with ID: \(existing.documentID)")
                        let chatRef = self.db.collection("chat").document(existing.documentID)
                        let hiMessage = "Hi!"

                        chatRef.updateData([
                            "hiddenFor": FieldValue.arrayRemove([currentUserID]),
                            "lastMessage": hiMessage
                        ]) { err in
                            if let err = err {
                                print("Error unhiding chat: \(err)")
                            } else {
                                print("Chat unhidden and last message reset")
                                // Add the "Hi!" message to messages subcollection
                                let messageData: [String: Any] = [
                                    "text": hiMessage,
                                    "senderID": currentUserID,
                                    "timestamp": FieldValue.serverTimestamp()
                                ]
                                chatRef.collection("messages").addDocument(data: messageData) { err in
                                    if let err = err {
                                        print("Error sending hi message: \(err)")
                                    }
                                }
                                self.fetchChats()
                                completion?(existing.documentID)
                            }
                        }
                        return
                    }
                    let chatRef = self.db.collection("chat").document()
                    //creates a new chat document and has the user information for both of them
                    let userInfo: [String: Any] = [
                        currentUserID: currentUserInfo,
                        otherUserID: otherUserInfo
                    ]
                    let hiMessage = "Hi!"
                    //this is now the data for the subcollection 'messages'
                    let chatData: [String: Any] = [
                        "participantIDs": [currentUserID, otherUserID],
                        "lastMessage": hiMessage,
                        "userInfo": userInfo
                    ]

                    chatRef.setData(chatData) { err in
                        if let err = err {
                            print("Error creating chat: \(err)")
                        } else {
                            let messageData: [String: Any] = [
                                "text": hiMessage,
                                "senderID": currentUserID,
                                "timestamp": FieldValue.serverTimestamp()
                            ]
                            //create the subcollection for messages and add the data
                            chatRef.collection("messages").addDocument(data: messageData)
                            self.fetchChats()
                            completion?(chatRef.documentID)
                        }
                    }
                }
        }
    }


    //MARK: - Send Message
    //precondition: none
    //postcondition: this is the message when user sends a message to another user
    func sendMessage(_ text: String, to chatID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        //data that the 'message' is supposed to have in the database
        let message: [String: Any] = [
            "text": text,
            "senderID": currentUserID,
            "timestamp": FieldValue.serverTimestamp()
        ]
        //goes in the 'chat' collection
        let chatRef = db.collection("chat").document(chatID)
        
        //goes to the message (creating a new subcollection) specifically for the messages that are being send
        chatRef.collection("messages").addDocument(data: message) { error in
            if let error = error {
                print("Failed to send message: \(error)")
            } else {
                //going to update the last message in the text
                chatRef.updateData(["lastMessage": text])
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

        let chatRef = db.collection("chat").document(chatID)
        chatRef.updateData([
            "hiddenFor": FieldValue.arrayUnion([currentUserID])
        ]) { [weak self] error in
            if let error = error {
                print("Failed to hide chat: \(error)")
            } else {
                self?.conversations.removeAll(where: { $0.friend.id == chatID })
                self?.chats.removeAll(where: { $0.id == chatID })
            }
        }
    }


    //MARK: - Real time updates (will update right when the database changes)
    //precondition: none
    //postcodition: will allowed for messages to update right when you are sending and need to use @State since it is valid for Listener
    func listenToMessages(for chatID: String, onUpdate: @escaping ([ChatMessages]) -> Void) {
        //go to the collection 'chat' then the subcollection 'messages'
        db.collection("chat")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                    onUpdate([])
                    return
                }
                
                let messages = documents.compactMap { doc -> ChatMessages? in
                    let data = doc.data()
                    guard let text = data["text"] as? String,
                          let senderID = data["senderID"] as? String else { return nil }
                    
                    return ChatMessages(
                        text: text,
                        isFromCurrentUser: senderID == Auth.auth().currentUser?.uid
                    )
                }
                onUpdate(messages)
            }
    }
    
    
    //need this so it can clean up the listener (no memory leaks
    deinit {
        listener?.remove()
    }
}

