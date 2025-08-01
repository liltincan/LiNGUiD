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

                    //this is the start of the snapshot listener
                    if self.userListeners[otherUserID] == nil {
                        let userListener = self.db.collection("users").document(otherUserID).addSnapshotListener { snapshot, _ in
                            guard let userData = snapshot?.data() else { return }
                            if let index = self.chats.firstIndex(where: { $0.participantIDs.contains(otherUserID) }) {
                                var updatedChat = self.chats[index]
                                updatedChat.username = userData["userName"] as? String ?? "Unknown"
                                updatedChat.status = userData["status"] as? String ?? ""
                                updatedChat.country = userData["country"] as? String ?? ""
                                updatedChat.profileimage = userData["profilePhotoUrl"] as? String ?? "defaultProfile"
                                updatedChat.isActive = userData["isActive"] as? Bool ?? false
                                updatedChat.lastSeen = (userData["lastSeen"] as? Timestamp)?.dateValue()
                                self.chats[index] = updatedChat
                                if let convoIndex = self.conversations.firstIndex(where: { $0.friend.id == updatedChat.id }) {
                                    self.conversations[convoIndex].friend = updatedChat
                                }
                            }
                        }
                        self.userListeners[otherUserID] = userListener
                    }
                    self.db.collection("users").document(otherUserID).getDocument { userSnapshot, _ in
                        let userData = userSnapshot?.data()
                        //this will extract users language info
                        let nativeLang = userData?["nativeLanguage"] as? String ?? ""
                        let learningLangCode = userData?["targetLanguage"] as? String ?? ""
                        let languagesData = userData?["languagesData"] as? [String: [String: Any]] ?? [:]
                        let comprehensionLevel = (languagesData[learningLangCode]?["comprehensionLevel"] as? Int) ?? 0
                        
                        //will create chat instance with new fields
                        let chat = Chat(
                            id: doc.documentID,
                            participantIDs: participants,
                            lastMessage: data["lastMessage"] as? String ?? "",
                            username: userData?["userName"] as? String ?? "Unknown",
                            status: userData?["status"] as? String ?? "",
                            country: userData?["country"] as? String ?? "",
                            profileimage: userData?["profilePhotoUrl"] as? String ?? "defaultProfile",
                            isActive: userData?["isActive"] as? Bool ?? false,
                            lastSeen: (userData?["lastSeen"] as? Timestamp)?.dateValue(),
                            hiddenFor: data["hiddenFor"] as? [String] ?? [],
                            lastMessageTimestamp: (data["lastMessageTimestamp"] as? Timestamp)?.dateValue(),
                            nativeLanguage: nativeLang,
                            learningLanguage: learningLangCode,
                            comprehensionLevel: comprehensionLevel
                        )

                        self.fetchMessages(for: doc.documentID) { messages in
                            newChats.append(chat)
                            newConversations.append(ChatConversation(friend: chat, messages: messages))
                            dispatchGroup.leave()
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    let chatMap = Dictionary(uniqueKeysWithValues: newChats.map { ($0.id, $0) })
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
                //this will be if users 'deletes' the chat
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
                    //data that will go in 'messages'
                    chatRef.collection("messages").addDocument(data: [
                        "text": hiMessage,
                        "senderID": currentUserID,
                        "timestamp": FieldValue.serverTimestamp(),
                        "isRead": false
                    ])
                    //this will update the latest message so it can show the latest message with timestamp as well
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
                let serverTimestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                let localFallback = (data["localTimestamp"] as? Timestamp)?.dateValue()
                let timestamp = serverTimestamp ?? localFallback ?? Date()
                let repliedToText = data["repliedToText"] as? String
                let isLiked = data["isLiked"] as? Bool ?? false
                return ChatMessages(
                    text: text,
                    isFromCurrentUser: senderID == Auth.auth().currentUser?.uid,
                    isRead: isRead,
                    timestamp: timestamp,
                    repliedToText: repliedToText,
                    isLiked: isLiked,
                    documentID: doc.documentID
                )
            }
            completion(messages)
        }
    }
    //MARK: - Send Message
    //precondition: none
    //postcondition: this is the message when user sends a message to another user
    func sendMessage(_ text: String, to chatID: String, replyingTo: ChatMessages? = nil) {
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
            let now = Date()
            //data that the 'message' will have and the isRead is false only for the user to view it
            let message: [String: Any] = [
                "text": text,
                "senderID": currentUserID,
                "timestamp": FieldValue.serverTimestamp(),
                "localTimestamp": Timestamp(date: now),
                "isRead": false,
                "repliedToText": replyingTo?.text ?? NSNull()
            ]
            //creating a collection now called 'messages'
            chatRef.collection("messages").addDocument(data: message) { error in
                if let error = error {
                    print(" Failed to send message: \(error)")
                }
                //this data is the updated for chats
                else {
                    chatRef.updateData([
                        "lastMessage": text,
                        "lastMessageTimestamp": FieldValue.serverTimestamp(),
                        "hiddenFor": FieldValue.arrayRemove([recipientID]),
                        //"messageResetTimestamps.\(recipientID)": FieldValue.delete()
                    ]) { _ in
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
            "hiddenFor": FieldValue.arrayUnion([currentUserID]),
            "messageResetTimestamps.\(currentUserID)": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            if let error = error {
                print("Failed to hide chat: \(error)")
                print("The user that tried to hide the chat is: \(currentUserID)")
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
        //will read from the 'users' collection
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let users = documents.filter { $0.documentID != currentUserID }

            let result = users.compactMap { doc -> Chat? in
                //going to now go in the field 'nativeLanguage' and 'languagesData' to retreive the users level
                let data = doc.data()
                let nativeLang = data["nativeLanguage"] as? String ?? ""
                let learningLangCode = data["targetLanguage"] as? String ?? ""
                let languagesData = data["languagesData"] as? [String: [String: Any]] ?? [:]
                let comprehensionLevel = (languagesData[learningLangCode]?["comprehensionLevel"] as? Int) ?? 0

                //returning the information of the Users so Chat will now carry what 'users' (collection) has
                return Chat(
                    id: doc.documentID,
                    participantIDs: [],
                    lastMessage: "",
                    username: data["userName"] as? String ?? "Unknown",
                    status: data["status"] as? String ?? "",
                    country: data["country"] as? String ?? "",
                    profileimage: data["profilePhotoUrl"] as? String ?? "defaultProfile",
                    isActive: data["isActive"] as? Bool ?? false,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                    hiddenFor: [],
                    lastMessageTimestamp: nil,
                    nativeLanguage: nativeLang,
                    learningLanguage: learningLangCode,
                    comprehensionLevel: comprehensionLevel
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
        //this checks if languages are empty if empty just return
        if languages.isEmpty {
            discoverableUsers = []
            return
        }
        //go in the 'users' collection but now we are going to filter by the field 'nativeLanguage'
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
                    //in the nativeLangauge we still want to get access to the users level and what they are learning
                    let nativeLang = data["nativeLanguage"] as? String ?? ""
                    let learningLangCode = data["targetLanguage"] as? String ?? ""
                    let languagesData = data["languagesData"] as? [String: [String: Any]] ?? [:]
                    let comprehensionLevel = (languagesData[learningLangCode]?["comprehensionLevel"] as? Int) ?? 0
                    
                    //data we want to return with the users information
                    return Chat(
                        id: doc.documentID,
                        participantIDs: [],
                        lastMessage: "",
                        username: data["userName"] as? String ?? "Unknown",
                        status: data["status"] as? String ?? "",
                        country: data["country"] as? String ?? "",
                        profileimage: data["profilePhotoUrl"] as? String ?? "defaultProfile",
                        isActive: data["isActive"] as? Bool ?? false,
                        lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                        hiddenFor: [],
                        lastMessageTimestamp: nil,
                        nativeLanguage: nativeLang,
                        learningLanguage: learningLangCode,
                        comprehensionLevel: comprehensionLevel
                    )
                }

                DispatchQueue.main.async {
                    self.discoverableUsers = result
                }
            }
    }
    //MARK: Fetch users who speak my target langauge that are native speakers
    //precondition: call the fetchUsersByNativeLanguages
    //postcondition: going to compare the users and check if the users targetLanguage matches the nativeLanguages and if yes then call it in the function we are calling
    func fetchNativeSpeakersOfMyTargetLanguage() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(currentUserID).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let targetLang = data["targetLanguage"] as? String else {
                print("Failed to get current user's targetLanguage")
                return
            }
            //call the function that checks by native language
            self.fetchUsersByNativeLanguages([targetLang])
        }
    }
    //MARK: Fetching users by their username
    //precondition: none
    //postcondition: this will allow user to search by 'username'
    func searchUsers(by username: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        //going to load all the users
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            let filtered = documents.filter {
                //have to search by username so go in the field 'userName' and allow lowercase
                let name = ($0.data()["userName"] as? String ?? "").lowercased()
                return $0.documentID != currentUserID && name.contains(username.lowercased())
            }
            let result = filtered.map { doc -> Chat in
                let data = doc.data()
                let nativeLang = data["nativeLanguage"] as? String ?? ""
                let learningLangCode = data["targetLanguage"] as? String ?? ""
                let languagesData = data["languagesData"] as? [String: [String: Any]] ?? [:]
                let comprehensionLevel = (languagesData[learningLangCode]?["comprehensionLevel"] as? Int) ?? 0

                return Chat(
                    id: doc.documentID,
                    participantIDs: [],
                    lastMessage: "",
                    username: data["userName"] as? String ?? "Unknown",
                    status: data["status"] as? String ?? "",
                    country: data["country"] as? String ?? "",
                    profileimage: data["profilePhotoUrl"] as? String ?? "defaultProfile",
                    isActive: data["isActive"] as? Bool ?? false,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue(),
                    hiddenFor: [],
                    lastMessageTimestamp: nil,
                    nativeLanguage: nativeLang,
                    learningLanguage: learningLangCode,
                    comprehensionLevel: comprehensionLevel
                )
            }
            DispatchQueue.main.async {
                self.discoverableUsers = result
            }
        }
    }
    //MARK: Decide which users to show in Discovery based on premium
    func fetchUsersBasedOnIsPro() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(currentUserID).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data() else {
                print("Failed to fetch current user's data.")
                return
            }
            let isPro = data["isPro"] as? Bool ?? false
            let targetLang = data["targetLanguage"] as? String ?? ""

            if (isPro) {
                self.fetchDiscoverableUsersFromUsers()
            }
            else {
                print("User is NOT Pro. Filtering by native language: \(targetLang)")
                self.fetchUsersByNativeLanguages([targetLang])
            }
        }
    }
    
    // MARK: - Toggle Like on Message
    //precondition: none
    //postcondition: will going to add the liking in the database
    func toggleLike(for message: ChatMessages, in chatID: String) {
        let chatRef = db.collection("chat").document(chatID)
        let messagesRef = chatRef.collection("messages")
        let docID = message.documentID
        guard !docID.isEmpty else {
            print("Missing document ID; cannot toggle like.")
            return
        }
        let messageDoc = messagesRef.document(docID)
        let newLike = !message.isLiked
        //this will now add the 'isLiked' field to the message collection with the updated
        self.updateLocalMessage(chatID: chatID, matching: docID, newLike: newLike)
        messageDoc.updateData(["isLiked": newLike]) { error in
            if let error = error {
                print("Error updating like: \(error.localizedDescription)")
            }
            else {
                print("Message like toggled in Firestore.")
            }
        }
    }
    private func updateLocalMessage(chatID: String, matching documentID: String, newLike: Bool) {
        if let convoIndex = self.conversations.firstIndex(where: { $0.friend.id == chatID }) {
            var convo = self.conversations[convoIndex]
            if let msgIndex = convo.messages.firstIndex(where: { $0.documentID == documentID }) {
                convo.messages[msgIndex].isLiked = newLike
                self.conversations[convoIndex] = convo
            }
        }
    }

    //MARK: - Real time updates (will update right when the database changes)
    //precondition: none
    //postcodition: will allowed for messages to update right when you are sending and need to use @State since it is valid for Listener
    func listenToMessages(for chatID: String, completion: @escaping ([ChatMessages]) -> Void) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        //this will go in the 'chat' collection and then go in the 'messages' collection
        let messagesRef = db.collection("chat").document(chatID).collection("messages")
            .order(by: "timestamp")
        
        messagesRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self,
                  let documents = snapshot?.documents else {
                completion([])
                return
            }
            //getting the current and partner language
            self.db.collection("chat").document(chatID).getDocument { chatSnapshot, _ in
                guard let chatData = chatSnapshot?.data(),
                      let participants = chatData["participantIDs"] as? [String],
                      let otherUserID = participants.first(where: { $0 != currentUserID }) else {
                    completion([])
                    return
                }
                //here we have to look into the users and then get their nativeLanguage
                self.db.collection("users").document(currentUserID).getDocument { userSnapshot, _ in
                    let currentLang = userSnapshot?.data()?["nativeLanguage"] as? String ?? "en"
                    self.db.collection("users").document(otherUserID).getDocument { partnerSnapshot, _ in
                        let partnerLang = partnerSnapshot?.data()?["nativeLanguage"] as? String ?? "en"
                        
                        let group = DispatchGroup()
                        var messages: [ChatMessages] = []
                        //now get the information that is in the messages (the fields)
                        for doc in documents {
                            let data = doc.data()
                            let text = data["text"] as? String ?? ""
                            let senderID = data["senderID"] as? String ?? ""
                            let isFromCurrentUser = senderID == currentUserID

                            let isRead = data["isRead"] as? Bool ?? false
                            let serverTimestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                            let localFallback = (data["localTimestamp"] as? Timestamp)?.dateValue()
                            let timestamp = serverTimestamp ?? localFallback ?? Date()
                            let repliedToText = data["repliedToText"] as? String
                            let isLiked = data["isLiked"] as? Bool ?? false
                            let documentID = doc.documentID
                            //this will then check if the user does not match the nativeLanguage of the other user
                            if (!isFromCurrentUser && partnerLang != currentLang) {
                                group.enter()
                                translateTextV2(text: text, sourceLang: partnerLang, targetLang: currentLang) { translated in
                                    let msg = ChatMessages(
                                        text: text,
                                        isFromCurrentUser: isFromCurrentUser,
                                        isRead: isRead,
                                        timestamp: timestamp,
                                        repliedToText: repliedToText,
                                        isLiked: isLiked,
                                        documentID: documentID,
                                        translatedText: translated
                                    )
                                    print("Translation: \(String(describing: translated))")
                                    messages.append(msg)
                                    group.leave()
                                }
                            }
                            //if the same nativeLanguage then no need to translate messages
                            else {
                                let msg = ChatMessages(
                                    text: text,
                                    isFromCurrentUser: isFromCurrentUser,
                                    isRead: isRead,
                                    timestamp: timestamp,
                                    repliedToText: repliedToText,
                                    isLiked: isLiked,
                                    documentID: documentID,
                                    translatedText: nil
                                )
                                messages.append(msg)
                            }
                        }
                        group.notify(queue: .main) {
                            let sorted = messages.sorted(by: { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) })
                            completion(sorted)
                            self.updateConversation(chatID: chatID, with: sorted)
                        }
                    }
                }
            }
        }
    }
    //precondition: none
    //postcondition: this is going to be used for the isRead and determine who send it
    func markMessagesAsRead(for chatID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let messagesRef = db.collection("chat").document(chatID).collection("messages")
        //looking at the 'isRead' field to see if its true or false
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




