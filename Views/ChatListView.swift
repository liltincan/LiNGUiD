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
    //controls what chat it is at -> currently empty
    @State private var selectedChat: ChatConversation? = nil
    @State private var discoveryPage = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            if let conversation = selectedChat {
                ChatMessagesConvoView(chatID:conversation.friend.id, viewModel: viewModel) {
                    //then set it back to nil once they go back
                    selectedChat = nil
                }
            }
            else {
                //this shows when all the information is loaded then go in here
                if (viewModel.isInitialLoadDone) {
                    //keep this together and not with the headlines
                    VStack {
                        HStack {
                            Text("Chats")
                                .foregroundColor(.white)
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            //once click the button then it goes to
                            Button(action: {
                                discoveryPage = true
                            }) {
                                Text("Find friends +")
                                    .padding(8)
                                    .padding(.horizontal)
                                    .background(Color.linguidPurple)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                        }
                        .padding()
                        lineDivider()
                        //checking if user has any conversations
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
                                        ChatRowView(chat: conversation.friend, hasUnreadMessages: conversation.hasUnreadMessages)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .listRowBackground(Color.black)
                                    .listRowSeparatorTint(.gray)
                                    //need this so i can add image aka just a delete trash butto
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
                        }
                    }
                    .padding(.top,10)
                }
                //simple black background like imessages
                else {
                    Color.black.ignoresSafeArea()
                }
            }
        }
        .fullScreenCover(isPresented: $discoveryPage){
            DiscoveryView(viewModel: viewModel) {
                discoveryPage = false
            }
        }
    }
    //function will delete the chat based on the index
    private func deleteChat(at offsets: IndexSet) {
        for index in offsets {
            let conversation = viewModel.conversations[index]
            //going to delete the id of the user
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
                    Circle()
                        .fill(hasUnreadMessages ? Color.blue : Color.clear)
                        .frame(width: 10, height: 10)
                        .offset(x: 1)
                    Text(chat.lastMessage)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                //this converts
                if let timestamp = chat.lastMessageTimestamp {
                    Text(relativeTimeString(timestamp))
                       // .font(.caption)
                        .foregroundColor(.gray)
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
                Spacer()
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
                                if (user.isActive) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width:10, height:10)
                                }
                            }
                            .padding(.bottom, -8)
                        }
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .foregroundColor(.white)
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
//MARK: Search Language to filter
struct NativeLanguageFilterView: View {
    @ObservedObject var viewModel: ChatListViewModel
    @State private var selectedLanguages: [String] = []
    @State private var allLanguages = ["en", "fr", "es", "de", "ja", "zh", "ko"]

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
    private func languageFullName( _ code: String) -> String {
        let languageMap: [String: String] = [
            "en": "English",
            "fr": "French",
            "es": "Spanish",
            "de": "German",
            "ja": "Japanese",
            "zh": "Chinese",
            "ko": "Korean"
        ]
        return languageMap[code] ?? code.capitalized
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

//MARK: - Previewing
struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView()
    }
}

