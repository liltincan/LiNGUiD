//
// ChatListView.swift
// LiNGUiD
//
// Created by Christian Hernandez 5/15/2025
//

import SwiftUI
import Combine
import Kingfisher

enum ChatRoute: Hashable {
    case chatDetail(String)
    case discovery
    case profile(String)
}

//MARK: - View (Main View)
struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    //@State private var selectedChat: ChatConversation? = nil
    @State private var discoveryPage = false
    @State private var pendingChatUserId: String? = nil
    @State private var path: [ChatRoute] = []
    @State private var selectedTab: Int = 0
    @Binding var unreadChatCount: Int
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack {
                    HStack {
                        Text("Chats")
                            .foregroundColor(.white)
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            path.append(.discovery)
                        }) {
                            Image(systemName: "plus")
                                .padding(8)
                                .padding(.horizontal)
                                .background(Color.linguidPurple)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                            
                        }
                    }
                    .padding()
                    Divider().background(Color.gray)
                    //checking if user has any conversations if no then show that they have no partners
                    if (viewModel.conversations.isEmpty) {
                        Spacer()
                        VStack(spacing: 16) {
                            Text("No Partners Yet...")
                                .foregroundColor(.gray)
                                .font(.headline)
                            
                            Button(action: {
                                path.append(.discovery)
                            }) {
                                Text("Find friends +")
                                    .padding(10)
                                    .padding(.horizontal)
                                    .background(Color.linguidPurple)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                        }
                        Spacer()
                    }
                    else {
                        List {
                            ForEach(viewModel.conversations) { conversation in
                                Button(action: {
                                    path.append(.chatDetail(conversation.friend.id))
                                }) {
                                    ChatRowView(chat: conversation.friend, hasUnreadMessages: conversation.hasUnreadMessages,statusText: conversation.lastMessageStatus)
                                }
                                .listRowBackground(Color.black)
                                .listRowSeparatorTint(.gray)
                            }
                            .onDelete(perform: deleteChat)
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.black)
                    }
                }
                .background(Color.black)
                //this will be the destination the user goes to so a basically a push and pop view
                .navigationDestination(for: ChatRoute.self) { route in
                    switch route {
                    case .chatDetail(let id):
                        ChatMessagesConvoView(chatID: id, viewModel: viewModel, onBack: {
                            path.removeLast()
                        }, path: $path)
                    case .discovery:
                        DiscoveryView(viewModel: viewModel) { selectedUserId in
                            path.append(.profile(selectedUserId))
                        } onBack: {
                            path.removeLast()
                        }
                    case .profile(let id):
                        OtherUserProfileView(userId: id, selectedTab: $selectedTab)
                            .padding(.top, -35)
                    }
                }
            }
        }
        //this needs to be changes when changes are being made since it keeps track of the count
        .onChange(of: viewModel.conversations) { conversations in
            unreadChatCount = conversations.filter { $0.hasUnreadMessages }.count
            
            //check if we need to open a specific chat after conversations are loaded
            if let userId = pendingChatUserId,
               let conversation = conversations.first(where: { $0.friend.id == userId }) {
                path.append(.chatDetail(userId))
                pendingChatUserId = nil
            }
        }
        //this will now let the app know that a conversationg is being checked
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartChatWithUser"))) { notification in
            if let userInfo = notification.userInfo,
               let userId = userInfo["userId"] as? String,
               let username = userInfo["username"] as? String {
                handleStartChat(userId: userId, username: username)
            }
        }
    }
    //function will check if the chat exists if it does then no need to create chat just call the chat to view it
    private func handleStartChat(userId: String, username: String) {
        // Check if a conversation with the user already exists
        if let existingConversation = viewModel.conversations.first(where: { $0.friend.participantIDs.contains(userId) }) {
            path.append(.chatDetail(existingConversation.friend.id))
        } else {
            //this will start a new chat and set a pending flag to navigate once data updates
            print("No existing chat with \(userId), starting new one.")
            viewModel.startChat(with: userId)
            pendingChatUserId = userId
        }
    }
    //function will delete the chat based on the index
    private func deleteChat(at offsets: IndexSet) {
        for index in offsets {
            let conversation = viewModel.conversations[index]
            viewModel.softDeleteChatForCurrentUser(chatID: conversation.friend.id)
        }
    }
}
//MARK: - Chat Row View
//precondition: pass in the model
//postcondition: will show the chats of the users so contains the username , message, status, flag, profileimage, and isactive
struct ChatRowView: View {
    let chat: Chat
    var hasUnreadMessages: Bool
    let statusText: String
    
    var body: some View {
        HStack(spacing: 12) {
            //the profile image should be overlayed with the flag and the active
            ZStack(alignment: .bottomLeading){
                ProfileImageView(imageUrl: chat.profileimage)
                //now the flag and the active need to be side to side
                HStack(spacing: 4) {
                    Text(chat.flag)
                    if (chat.isActive) {
                        Circle()
                            .fill(Color.green)
                            .frame(width:10, height:10)
                    }
                }
                .padding(.bottom, -8)
            }
            //this is now the convo information
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.username)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                HStack(spacing: 2) {
                    if(hasUnreadMessages) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                            .offset(x: 1)
                    }
                    //checking if its an audio or a text message
                    Text(chat.lastMessage.contains(".m4a") ? "Sent a voice message" : chat.lastMessage)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                if (!statusText.isEmpty) {
                    Text(statusText)
                        .foregroundColor(.white)
                        .italic(true)
                        .font(.caption)
                }
                //if it is empty then just show the timestamp
                else if let timestamp = chat.lastMessageTimestamp {
                    Text(relativeTimeString(timestamp))
                        .foregroundColor(.white)
                        .italic(true)
                        .font(.caption)
                }
                
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
    //function will convert the time into minutes or how logn ago it was sent
    private func relativeTimeString(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if (timeInterval < 60) {
            return "just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

//MARK: - Discovery Page View
//precondition: none
//postcondition: going to make the discover page where user can send a simple 'Hi!' to another user
struct DiscoveryView: View {
    @ObservedObject var viewModel: ChatListViewModel
    var onUserSelected: (String) -> Void
    var onBack: () -> Void
    @State private var searchText: String = ""
    @State private var selectedLanguages: [String] = []

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                //horizontal where the it shows back , discover , then the searching option
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                    Text("Discover")
                        .foregroundColor(.white)
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    SearchByUsernameView(searchUsername: $searchText, onSearchChanged: applyFilters)
                }
                .padding()
                //call the filter option so user can now filter what they want
                NativeLanguageFilterView(selectedLanguages: $selectedLanguages, onFilterChanged: applyFilters)
                Divider().background(Color.gray)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.discoverableUsers, id: \.id) { user in
                            //check if the user already messaged them
                            let hasMessaged = viewModel.chattedUserIDs.contains(user.id)
                            //make the information of the profile all aligned by adding the vstack and padding (horizontal)
                            VStack(spacing: 0) {
                                HStack {
                                    //the profile image should be overlayed with the flag and the active
                                    ZStack(alignment: .bottomLeading) {
                                        Button(action: {
                                            print("Profile tapped for user id:", user.id)
                                            onUserSelected(user.id)
                                        }) {
                                            ProfileImageView(imageUrl: user.profileimage)
                                        }
                                        HStack(spacing: 4) {
                                            Text(user.flag)
                                        }
                                        .padding(.bottom, -8)
                                    }
                                    //have the username and what they are learning aligned
                                    VStack(alignment: .leading) {
                                        Text(user.username)
                                            .foregroundColor(.white)
                                            .font(.headline.weight(.bold))
                                        Text("\(user.nativeLanguage.capitalized) → \(user.learningLanguage.capitalized) (Lvl. \(user.comprehensionLevel))")
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                    }
                                    
                                    Spacer()
                                    Button(action: {
                                        //checking if they already messaged user if yes open the chat
                                        if(hasMessaged) {
                                            //will have to directly open the chat screen
                                            NotificationCenter.default.post(name: NSNotification.Name("StartChatWithUser"), object: nil, userInfo: [
                                                "userId": user.id,
                                                "username": user.username
                                            ])
                                        }
                                        else {
                                            //star new chat with thier id and put the info with their id
                                            viewModel.startChat(with: user.id)
                                        }
                                    }) {
                                        Text(hasMessaged ? "Messaged" : "Say Hi!")
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(hasMessaged ? Color.gray : Color.linguidPurple)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                                .padding(.vertical, 20)
                                Divider().background(Color.gray)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                //will load the users when this view appears right away
                .onAppear {
                    applyFilters()
                }
                //hide the scrollable on the side
                .scrollIndicators(.hidden)
            }
            .padding(.top, 7)
        }
        .navigationBarBackButtonHidden(true)
    }
    //function will identify what the users see if its 'filter by username', 'filter by languages', or 'all users'
    private func applyFilters() {
        if (!searchText.isEmpty) {
            viewModel.searchUsers(by: searchText)
        }
        else if (!selectedLanguages.isEmpty) {
            viewModel.fetchUsersByNativeLanguages(selectedLanguages)
        }
        else {
            viewModel.fetchDiscoverableUsersFromUsers()
        }
    }
}
//MARK: - Search Language to filter
struct NativeLanguageFilterView: View {
    @Binding var selectedLanguages: [String]
    //this closure function will help with what filter it is at
    var onFilterChanged:()-> Void
    @State private var allLanguages = [
        "af", "am", "ar", "az", "be", "bg", "bn", "bs", "ca", "ceb", "cs", "cy",
        "da", "de", "el", "en", "eo", "es", "et", "eu", "fa", "fi", "fil", "fj",
        "fr", "fy", "ga", "gd", "gl", "gu", "ha", "haw", "he", "hi", "hmn", "hr",
        "ht", "hu", "hy", "id", "ig", "is", "it", "iw", "ja", "jw", "ka", "kk",
        "km", "kn", "ko", "ku", "ky", "la", "lb", "lo", "lt", "lv", "mg", "mi",
        "mk", "ml", "mn", "mr", "ms", "mt", "my", "ne", "nl", "no", "ny", "pa",
        "pl", "ps", "pt", "ro", "ru", "rw", "sd", "si", "sk", "sl", "sm", "sn",
        "so", "sq", "sr", "st", "su", "sv", "sw", "ta", "te", "tg", "th", "tk",
        "tl", "tr", "tt", "ug", "uk", "ur", "uz", "vi", "xh", "yi", "yo", "zh", "zu"
    ]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                //this will show the users selected countries
                ForEach(selectedLanguages, id: \.self) { country in
                    HStack(spacing: 5) {
                        Text(languageFullName(country))
                        Button(action: {
                            selectedLanguages.removeAll { $0 == country }
                            //call the function to get the users they filtered
                            onFilterChanged()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.linguidPurple)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                //menu picker for when users filters the options
                Menu{
                    ForEach(allLanguages.filter { !selectedLanguages.contains($0) }, id: \.self) { country in
                        Button(action: {
                            selectedLanguages.append(country)
                            onFilterChanged()
                        }) {
                            Text(languageFullName(country))
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .padding(8)
                        .padding(.horizontal)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 10)
        //going to load all the users at first
        .onAppear {
            onFilterChanged()
        }
    }
    //function will allow me to convert the 'en' to the fullname for all languages
    private func languageFullName(_ code: String) -> String {
        let languageMap: [String: String] = [
            "af": "Afrikaans",
            "am": "Amharic",
            "ar": "Arabic",
            "az": "Azerbaijani",
            "be": "Belarusian",
            "bg": "Bulgarian",
            "bn": "Bengali",
            "bs": "Bosnian",
            "ca": "Catalan",
            "ceb": "Cebuano",
            "cs": "Czech",
            "cy": "Welsh",
            "da": "Danish",
            "de": "German",
            "el": "Greek",
            "en": "English",
            "eo": "Esperanto",
            "es": "Spanish",
            "et": "Estonian",
            "eu": "Basque",
            "fa": "Persian",
            "fi": "Finnish",
            "fil": "Filipino",
            "fj": "Fijian",
            "fr": "French",
            "fy": "Frisian",
            "ga": "Irish",
            "gd": "Scots Gaelic",
            "gl": "Galician",
            "gu": "Gujarati",
            "ha": "Hausa",
            "haw": "Hawaiian",
            "he": "Hebrew",
            "hi": "Hindi",
            "hmn": "Hmong",
            "hr": "Croatian",
            "ht": "Haitian Creole",
            "hu": "Hungarian",
            "hy": "Armenian",
            "id": "Indonesian",
            "ig": "Igbo",
            "is": "Icelandic",
            "it": "Italian",
            "iw": "Hebrew", // older ISO code
            "ja": "Japanese",
            "jw": "Javanese",
            "ka": "Georgian",
            "kk": "Kazakh",
            "km": "Khmer",
            "kn": "Kannada",
            "ko": "Korean",
            "ku": "Kurdish",
            "ky": "Kyrgyz",
            "la": "Latin",
            "lb": "Luxembourgish",
            "lo": "Lao",
            "lt": "Lithuanian",
            "lv": "Latvian",
            "mg": "Malagasy",
            "mi": "Maori",
            "mk": "Macedonian",
            "ml": "Malayalam",
            "mn": "Mongolian",
            "mr": "Marathi",
            "ms": "Malay",
            "mt": "Maltese",
            "my": "Burmese",
            "ne": "Nepali",
            "nl": "Dutch",
            "no": "Norwegian",
            "ny": "Nyanja",
            "pa": "Punjabi",
            "pl": "Polish",
            "ps": "Pashto",
            "pt": "Portuguese",
            "ro": "Romanian",
            "ru": "Russian",
            "rw": "Kinyarwanda",
            "sd": "Sindhi",
            "si": "Sinhala",
            "sk": "Slovak",
            "sl": "Slovenian",
            "sm": "Samoan",
            "sn": "Shona",
            "so": "Somali",
            "sq": "Albanian",
            "sr": "Serbian",
            "st": "Sesotho",
            "su": "Sundanese",
            "sv": "Swedish",
            "sw": "Swahili",
            "ta": "Tamil",
            "te": "Telugu",
            "tg": "Tajik",
            "th": "Thai",
            "tk": "Turkmen",
            "tl": "Tagalog",
            "tr": "Turkish",
            "tt": "Tatar",
            "ug": "Uyghur",
            "uk": "Ukrainian",
            "ur": "Urdu",
            "uz": "Uzbek",
            "vi": "Vietnamese",
            "xh": "Xhosa",
            "yi": "Yiddish",
            "yo": "Yoruba",
            "zh": "Chinese",
            "zu": "Zulu"
        ]
        return languageMap[code.lowercased()] ?? code.capitalized
    }
}
//MARK: - Search button by username
//precondition: none
//postcondition: creating a search button with animation that searches by username
struct SearchByUsernameView: View {
    @Binding var searchUsername: String
    //this closure function will help with what filter it is at
    var onSearchChanged:() -> Void
    @State private var isSearching = false
    
    var body: some View {
        HStack {
            //message over the text field
            ZStack(alignment: .leading) {
                if(isSearching) {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white)
                        .frame(height: 30)
                    if(searchUsername.isEmpty) {
                        Text("Search")
                            .foregroundColor(.black)
                            .padding(.horizontal)
                    }
                    TextField("", text: $searchUsername)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                        //will change while user is typing the username so pops up by the start
                        .onChange(of: searchUsername) { _ in
                            onSearchChanged()
                        }
                }
            }
            Spacer()
            Button(action: {
                withAnimation {
                    isSearching.toggle()
                    if (!isSearching) {
                        //if users clicks the x button then reset everything
                        searchUsername = ""
                        onSearchChanged()
                    }
                }
            }) {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .bold))
            }
        }
        .padding(.horizontal)
        //need to call this to make sure search results show after returning from the profile they visit
        .onAppear {
            onSearchChanged()
        }
    }
}

//MARK: - Profile Image Reusable
//precondition: none
//postcondition: allowed this to reuse so it can determine if users has a profile or not
struct ProfileImageView: View {
    var imageUrl: String
    var body: some View {
        KFImage(URL(string: imageUrl))
        //this placeholder will only show up if the user does not have profile
            .placeholder {
                Image("defaultProfile")
                    .resizable()
            }
            .resizable()
            .scaledToFill()
            .frame(width: 55, height: 55)
            .clipShape(Circle())
    }
}



