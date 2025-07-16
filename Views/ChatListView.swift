//
// ChatListView.swift
// LiNGUiD
//
// Created by Christian Hernandez 5/15/2025
//

import SwiftUI
import Combine
import Kingfisher

//MARK: - View (Main View)
struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var selectedChat: ChatConversation? = nil
    @State private var discoveryPage = false
    @State private var pendingChatUserId: String? = nil
    @Binding var unreadChatCount: Int
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            if let conversation = selectedChat {
                ChatMessagesConvoView(chatID: conversation.friend.id, viewModel: viewModel) {
                    selectedChat = nil
                }
            }
            else {
                if (viewModel.isInitialLoadDone) {
                    VStack {
                        HStack {
                            Text("Chats")
                                .foregroundColor(.white)
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            Button(action: {
                                discoveryPage = true
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
                        lineDivider()
                        
                        if (viewModel.conversations.isEmpty) {
                            Spacer()
                            VStack(spacing: 16) {
                                Text("No Partners Yet...")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                                
                                Button(action: {
                                    discoveryPage = true
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
                                        selectedChat = conversation
                                    }) {
                                        ChatRowView(chat: conversation.friend, hasUnreadMessages: conversation.hasUnreadMessages, statusText: conversation.lastMessageStatus)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .listRowBackground(Color.black)
                                    .listRowSeparatorTint(.gray)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            if let index = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) {
                                                deleteChat(at: IndexSet(integer: index))
                                            }
                                        } label: {
                                            Label("", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .background(Color.black)
                            .listStyle(PlainListStyle())
                            .refreshable {
                                viewModel.fetchChats()
                            }
                        }
                    }
                    .padding(.top,10)
                }
                else {
                    Color.black.ignoresSafeArea()
                }
            }
        }
        .onChange(of: viewModel.conversations) { conversations in
            unreadChatCount = conversations.filter { $0.hasUnreadMessages }.count
            
            // Check if we need to open a specific chat after conversations are loaded
            if let userId = pendingChatUserId,
               let conversation = conversations.first(where: { $0.friend.id == userId }) {
                selectedChat = conversation
                pendingChatUserId = nil
            }
        }
        .fullScreenCover(isPresented: $discoveryPage){
            DiscoveryView(viewModel: viewModel) {
                discoveryPage = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartChatWithUser"))) { notification in
            if let userInfo = notification.userInfo,
               let userId = userInfo["userId"] as? String,
               let username = userInfo["username"] as? String {
                let conversation = viewModel.conversations[0]
                if(conversation.friend.participantIDs.contains(userId)){
                    selectedChat = conversation
                } else{
                    print("\(conversation.friend.id) - \(userId) NOT SAME")
                    handleStartChat(userId: userId, username: username)
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700)) {
                        viewModel.fetchChats()
                        let conversation = viewModel.conversations[0]
                        selectedChat = conversation
                    }
                    
                }
                
            }
        }
    }
    
    private func handleStartChat(userId: String, username: String) {
        // First check if conversation already exists
        if let existingConversation = viewModel.conversations.first(where: { $0.friend.id == userId }) {
            selectedChat = existingConversation
        } else {
            // Start a new chat
            viewModel.startChat(with: userId)
            // Store the userId to open the chat once conversations are updated
            pendingChatUserId = userId
        }
    }
    
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
                //.fontWeight(.bold)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                HStack(spacing: 2) {
                    if(hasUnreadMessages) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                            .offset(x: 1)
                    }
                    Text(chat.lastMessage)
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

//MARK: - Conversation View
//precondition: pass in the model
//postcondition: will show the full conversation with friend
struct ChatMessagesConvoView: View {
    let chatID: String
    @ObservedObject var viewModel: ChatListViewModel
    //closure function that allows user to go back to the main
    var onBack: () -> Void
    
    @State private var messages: [ChatMessages] = []
    @State private var sendMessage = ""
    @State private var isMessageEmtpy = false
    @State private var dragOffset: CGFloat = 0
    
    //controls the input
    @FocusState private var focusfield: FocusField?
    
    var body: some View {
        //everything has to be vertical
        VStack {
            if let chat = viewModel.chats.first(where: {$0.id == chatID}){
                //this is for the profile,name, active, and phone and facetime
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName:"chevron.left")
                            .foregroundColor(.white)
                    }
                    ProfileImageView(imageUrl:chat.profileimage)
                    //this has to be together
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chat.username)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        /*Text(formattedLastSeenText(isActive: chat.isActive, lastSeen: chat.lastSeen))
                         .font(.caption)
                         .foregroundColor(.gray)
                         .italic(true)*/
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        Image(systemName: "phone.fill")
                        Image(systemName: "video.fill")
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 2)
            }
            lineDivider()
            ScrollViewReader { proxy in
                //make the messages scrollable
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(messages) { msg in
                            HStack {
                                //this is the users message
                                if (msg.isFromCurrentUser) {
                                    Spacer()
                                    Text(msg.text)
                                        .padding(10)
                                        .background(Color.linguidPurple)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .frame(maxWidth: 280, alignment: .trailing)
                                }
                                else {
                                    Text(msg.text)
                                        .padding(10)
                                        .background(Color.white)
                                        .foregroundColor(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .frame(maxWidth: 280, alignment: .leading)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal,10)
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                //get updates while the value is changing so it loads to the bottom
                .onChange(of: messages) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            //message over the text field
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .frame(height: 50)
                
                if(sendMessage.isEmpty) {
                    Text("Message...")
                        .foregroundColor(.black)
                        .padding(.horizontal)
                }
                TextField("", text: $sendMessage)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                //TODO: fix the mic
                //                Image(systemName: "mic.fill")
                //                    .foregroundColor(.black)
                
            }
            .padding(.horizontal)
            .focused($focusfield, equals: .sendMessage)
            .submitLabel(.send)
            .onSubmit {
                send()
                focusfield = nil
            }
        }
        .padding(.bottom, 10)
        //this will if user wants to swipe right and go back (only horizontal)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        onBack()
                    } else {
                        withAnimation {
                            dragOffset = 0
                        }
                    }
                }
        )
        //when this view loads-> it will then load up the convos as they update
        .onAppear {
            viewModel.listenToMessages(for: chatID) {msg in
                self.messages = msg
            }
            //will determine what message is being marked
            viewModel.markMessagesAsRead(for: chatID)
        }
        .onTapGesture {
            //dismiss the keyboard when user touches the chat
            focusfield = nil
        }
    }
    //function creates an option that automaticallys scrolls down to the new messages
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
    //function calls the sendMessage() from the viewmodel and allows user to send a message
    private func send() {
        let trimmed = sendMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        viewModel.sendMessage(trimmed, to: chatID)
        sendMessage = ""
    }
}
//MARK: - Discovery Page View
//precondition: none
//postcondition: going to make the discover page where user can send a simple 'Hi!' to another user
struct DiscoveryView : View {
    @ObservedObject var viewModel: ChatListViewModel
    //closure function that allows user to go back to the main
    var onBack: () -> Void
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName:"chevron.left")
                            .foregroundColor(.white)
                    }
                    Text("Discover")
                        .foregroundColor(.white)
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    //TODO: users is allowed to search by 'username'
                    SearchByUsernameView(viewModel: viewModel)
                }
                .padding()
                NativeLanguageFilterView(viewModel: viewModel)
                lineDivider()
                
                List(viewModel.discoverableUsers) { user in
                    //check if the user already messaged them
                    let hasMessaged = viewModel.chattedUserIDs.contains(user.id)
                    HStack {
                        //the profile image should be overlayed with the flag and the active
                        ZStack(alignment: .bottomLeading){
                            ProfileImageView(imageUrl: user.profileimage)
                            //now the flag and the active need to be side to side
                            HStack(spacing: 4) {
                                Text(user.flag)
                                /*if (user.isActive) {
                                 Circle()
                                 .fill(Color.green)
                                 .frame(width:10, height:10)
                                 }*/
                            }
                            .padding(.bottom, -8)
                        }
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .foregroundColor(.white)
                                .font(.headline.weight(.bold))
                            Text("\(user.nativeLanguage.capitalized) → \(user.learningLanguage.capitalized) (Lvl. \(user.comprehensionLevel))")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            /*Text(formattedLastSeenText(isActive: user.isActive, lastSeen: user.lastSeen))
                             .font(.caption)
                             .italic()
                             .foregroundColor(.gray)*/
                        }
                        Spacer()
                        Button(action: {
                            //now get thier id and put the info with their id
                            viewModel.startChat(with: user.id)
                        }) {
                            Text(hasMessaged ? "Messaged" : "Say Hi!")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(hasMessaged ? Color.gray : Color.linguidPurple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            
                        }
                        .disabled(hasMessaged)
                        
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.black)
                    .listRowSeparatorTint(.gray)
                }
                //will load the users when this view appears right away
                .onAppear {
                    viewModel.fetchDiscoverableUsersFromUsers()
                }
                .background(Color.black)
                .listStyle(PlainListStyle())
            }
            .padding(.top, 10)
        }
    }
}
//MARK: - Search Language to filter
struct NativeLanguageFilterView: View {
    @ObservedObject var viewModel: ChatListViewModel
    @State private var selectedLanguages: [String] = []
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
                            handleFilterChange()
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
                            handleFilterChange()
                        }) {
                            Text(languageFullName(country))
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.purple.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 10)
        //going to load all the users at first
        .onAppear {
            viewModel.fetchDiscoverableUsersFromUsers()
        }
    }
    //function will tell if the selected filter is empty if it is then print all the 'users'
    private func handleFilterChange() {
        if (selectedLanguages.isEmpty) {
            viewModel.fetchDiscoverableUsersFromUsers()
        }
        else {
            //this will then fetch by the users countries they filtered
            viewModel.fetchUsersByNativeLanguages(selectedLanguages)
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
    @ObservedObject var viewModel: ChatListViewModel
    @State private var searchUsername = ""
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
                        .onChange(of: searchUsername) { newText in
                            if (newText.isEmpty) {
                                viewModel.fetchDiscoverableUsersFromUsers()
                            }
                            else {
                                viewModel.searchUsers(by: newText)
                            }
                        }
                }
            }
            Spacer()
            Button(action: {
                withAnimation {
                    isSearching.toggle()
                    if (!isSearching) {
                        searchUsername = ""
                    }
                }
            }) {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .bold))
            }
        }
        .padding(.horizontal)
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
//precondition: none
//postcondition: going to return the divider line and reuse it
func lineDivider() -> some View{
    Divider()
        .frame(height: 0.5)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .background(Color.clear)
}


