//
// ChatListView.swift
// LiNGUiD
//
// Created by Christian Hernandez 5/15/2025
//

import SwiftUI

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
                                    ChatRowView(chat: conversation.friend)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Color.black)
                                .listRowSeparatorTint(.gray)
                            }
                            //will create the swipe option to delete
                            .onDelete(perform: deleteChat)
                        }
                        .background(Color.black)
                        .listStyle(PlainListStyle())
                    }
                }
                .padding(.top,30)
                .background(Color.black)
            }
        }
        .fullScreenCover(isPresented: $discoveryPage){
            DiscoveryView(viewModel: viewModel) {
                discoveryPage = false
            }
        }
    }
    //this function will delete the chat
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
    
    var body: some View {
        HStack(spacing: 12) {
            //the profile image should be overlayed with the flag and the active
            ZStack(alignment: .bottom){
                ProfileImageView(imageUrl: chat.profileimage)
                //now the flag and the active need to be side to side
                HStack(spacing: 4) {
                    Text(chat.flag)
                    //spacer to sperate the flag and the active sign ????
                    //Spacer()
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
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(chat.lastMessage)
                    .foregroundColor(.gray)
                    .font(.subheadline)
                Text(formattedLastSeenText(isActive: chat.isActive, lastSeen: chat.lastSeen))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic(true)
                
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.black)
        
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
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(formattedLastSeenText(isActive: chat.isActive, lastSeen: chat.lastSeen))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic(true)
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
                .onChange(of: messages) {_ in
                    if let last = messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            //message over the text field
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .frame(height: 50)
                HStack {
                    if(sendMessage.isEmpty) {
                        Text("Message...")
                            .foregroundColor(.black)
                        Spacer()
                    }
                    TextField("", text: $sendMessage)
                        .foregroundColor(.black)
                    Image(systemName: "mic.fill")
                        .foregroundColor(.black)
                }
                .padding(.horizontal)
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
        .background(Color.black)
        //when this view loads-> it will then load up the convos as they update
        .onAppear {
            viewModel.listenToMessages(for: chatID) {msg in
                self.messages = msg
            }
        }
        .onTapGesture {
            //dismiss the keyboard when user touches the chat
            focusfield = nil
        }
    }
    //precondition: call the sendMessage() from the viewmodel
    //postcondition: going to allow user to send a message
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
                lineDivider()
                
                List(viewModel.discoverableUsers) { user in
                    //check if the user already messaged them
                    let hasMessaged = viewModel.chattedUserIDs.contains(user.id)
                    HStack {
                        ProfileImageView(imageUrl: user.profileimage)
                        VStack(alignment: .leading) {
                            Text(user.username)
                                .foregroundColor(.white)
                            Text(formattedLastSeenText(isActive: user.isActive, lastSeen: user.lastSeen))
                                .font(.caption)
                                .italic()
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {
                            //this is the data that going to go in the database of the user
                            let userInfo: [String: Any] = [
                                "username": user.username,
                                "status": user.status,
                                "flag": user.flag,
                                "profilePhotoUrl": user.profileimage,
                                "isActive": user.isActive
                            ]
                            //now get thier id and put the info with their id
                            viewModel.startChat(with: user.id, otherUserInfo: userInfo) { _ in
                                onBack()
                            }
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
        }
    }
}
//MARK: - Profile image reusable
//precondition: none
//postcondition: allowed this to reuse so it can determine if users has a profile or not
struct ProfileImageView: View {
    var imageUrl: String
    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Image("defaultProfile")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 50, height: 50)
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
}
//precondition: none
//postcondition: going to check when the user was last active and return the prompt
func formattedLastSeenText(isActive: Bool, lastSeen: Date?) -> String {
    if (isActive) {
        return "Active now"
    }
    else if let lastSeen = lastSeen {
        let minutesAgo = Int(Date().timeIntervalSince(lastSeen) / 60)
        if minutesAgo < 1 {
            return "Just now"
        }
        else if minutesAgo < 60 {
            return "\(minutesAgo) minutes ago"
        }
        else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return "Last seen \(formatter.string(from: lastSeen))"
        }
    }
    else {
        return "Offline"
    }
}


//MARK: - Previewing
struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView()
    }
}
