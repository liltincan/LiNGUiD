//
// ChatListView.swift
// LiNGUiD
//
// Created by Christian Hernandez 5/15/2025
//

import SwiftUI

//MARK: - View (Main View)
struct ChatListView: View {
    //hardcode data for testing
    let sampleChats = [
        Chat(username: "starryskies23", message: "Coucou", status: "active now", flag: "🇫🇷", profileimage: "GoogleLogo", isActive: true),
        Chat(username: "nebulaNomad", message: "t es là où?", status: "active now", flag: "🇲🇽", profileimage: "profile2", isActive: true),
        Chat(username: "Eloïse", message: "tu fais quoi là", status: "active now", flag: "🇨🇦", profileimage: "profile3", isActive: true),
        Chat(username: "lunaVoyager", message: "Bonsoir", status: "1 minute ago", flag: "🇫🇷", profileimage: "profile4", isActive: false)
    ]
    //controls what chat it is at -> currently empty
    @State private var selectedChat: ChatConversation? = nil
    //computed property-> when this access it runs this code inside the {...}
    private var sampleConversations: [ChatConversation] {
        //now you map the user chat with their messages (key->value)
        sampleChats.map { chat in
            ChatConversation(
                friend: chat,
                messages: generateMessages(for: chat.username)
            )
        }
    }
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            if let conversation = selectedChat {
                ChatMessagesConvo(conversation:conversation) {
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
                            
                        }) {
                            Text("Make friends +")
                                .padding(8)
                                .padding(.horizontal)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                    lineDivider()
                    //create the chats to be in a lists
                    List(sampleConversations) { conversation in
                        Button(action: {
                            selectedChat = conversation
                        }) {
                            ChatRowView(chat: conversation.friend)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(Color.black)
                    }
                    .background(Color.black)
                    .listStyle(PlainListStyle())
                }
                .padding(.top,30)
                .background(Color.black)
            }
        }
    }
    //MARK: - Function to get messages (testing data)
    //precondition: call the ChatMessages since we need it in array
    //postcondition: going to return the conversation for that specific user
    private func generateMessages(for username: String) -> [ChatMessages] {
        switch username {
        case "starryskies23":
            return [
                ChatMessages(text: "Coucou!", isFromCurrentUser: false),
                ChatMessages(text: "Salut toi", isFromCurrentUser: true),
                ChatMessages(text: "Tu fais quoi?", isFromCurrentUser: false)
            ]
        case "nebulaNomad":
            return [
                ChatMessages(text: "t es là où?", isFromCurrentUser: false),
                ChatMessages(text: "J'arrive !", isFromCurrentUser: true),
                ChatMessages(text: "Ramène du café stp", isFromCurrentUser: false)
            ]
        case "Eloïse":
            return [
                ChatMessages(text: "tu fais quoi là", isFromCurrentUser: false),
                ChatMessages(text: "je code 🧠, do you speak enlgish? can you help", isFromCurrentUser: true),
                ChatMessages(text: "cool tu me montres?", isFromCurrentUser: false)
            ]
        case "lunaVoyager":
            return [
                ChatMessages(text: "Bonsoir", isFromCurrentUser: false),
                ChatMessages(text: "Hey hey !", isFromCurrentUser: true),
                ChatMessages(text: "Tu veux sortir ce soir?", isFromCurrentUser: false)
            ]
        default:
            return [
                ChatMessages(text: "Message par défaut", isFromCurrentUser: false)
            ]
        }
    }
}
//MARK: - Model for Users Friends Information
struct Chat: Identifiable {
    let id = UUID()
    var username: String
    var message: String
    var status: String
    var flag: String
    var profileimage: String
    var isActive: Bool
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
                Image(chat.profileimage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
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
                Text(chat.message)
                    .foregroundColor(.gray)
                    .font(.subheadline)
                Text(chat.status)
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

//MARK: - Model for Chat Messages
struct ChatMessages: Identifiable {
    let id = UUID()
    var text: String
    //who is replying
    var isFromCurrentUser: Bool
    //TODO: add a 'read' status option to determine if it was read by the friend
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
//MARK: - Conversation View
//precondition: pass in the model
//postcondition: will show the full conversation with friend
struct ChatMessagesConvo: View {
    let conversation: ChatConversation
    //closure function that allows user to go back to the main
    var onBack: () -> Void
    @State private var sendMessage = ""
    @State private var isMessageEmtpy = false
    //controls the input
    @FocusState private var focusfield: FocusField?
    
    var body: some View {
        //everything has to be vertical
        VStack {
            //this is for the profile,name, active, and phone and facetime
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName:"chevron.left")
                        .foregroundColor(.white)
                }
                Image(conversation.friend.profileimage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                //this has to be together
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.friend.username)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(conversation.friend.status)
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
            .padding()
            lineDivider()
            
            //make the messages scrollable
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(conversation.messages) { msg in
                        HStack {
                            //this is the users message
                            if (msg.isFromCurrentUser) {
                                Spacer()
                                Text(msg.text)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .frame(maxWidth:260, alignment: .trailing)
                            }
                            else {
                                Text(msg.text)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(20)
                                    .frame(maxWidth: 260, alignment: .leading)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .frame(height: 45)
                HStack {
                    if(sendMessage.isEmpty) {
                        Text("Message...")
                            .foregroundColor(.black)
                        
                    }
                    TextField("", text: $sendMessage)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .foregroundColor(.black)
                    Image(systemName: "mic.fill")
                        .foregroundColor(.black)
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)
            .focused($focusfield, equals: .sendMessage)
            .submitLabel(.done)
            .onSubmit {
                focusfield = nil
            }
        }
        .padding(.bottom, 10)
        .background(Color.black)
        .onTapGesture {
            //dismiss the keyboard when user touches the chat
            focusfield = nil
        }
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

//MARK: - Previewing
struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView()
    }
}
