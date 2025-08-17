//
//  ChatMessagesConvoView.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 7/18/25.
//

import SwiftUI
import FirebaseAuth
import AVFoundation
import FirebaseStorage

//MARK: - Conversation View (use in ChatListView)
struct ChatMessagesConvoView: View {
    let chatID: String
    @ObservedObject var viewModel: ChatListViewModel
    @StateObject private var audioMeter = AudioMeterObserver(recorder: nil)
    @StateObject private var tap = TapTracker(maxPerDay: 20)
    @Environment(\.scenePhase) private var scenePhase
    
    //MARK: Closure function that allows user to go back to the main
    var onBack: () -> Void
    //MARK: Converation messages
    @State private var messages: [ChatMessages] = []
    @State private var sendMessage = ""
    @State private var replyingTo: ChatMessages? = nil
    @GestureState private var dragOffset: CGFloat = 0
    @State private var draggingMessageID: String? = nil
    //MARK: Scrolling
    @State private var hasInitiallyScrolled = false
    @State private var shouldScrollToBottom = false
    //MARK: Audio voice messages
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioURL: URL?
    @State private var isRecording = false
    @State private var recordDragOffset: CGFloat = 0
    @State private var showSlideToCancel = false
    @State private var isInDeleteZone = false
    @State private var didFireHaptic = false
    private let cancelDistance: CGFloat = 120 // how far left to cancel

    
    //MARK: Translating the message based on tapping
    @State private var showTranslateMessage: Set<String> = []
    @State private var showLimitAlert = false
    
    @Binding var path: [ChatRoute]
    @FocusState private var focusfield: FocusField?
    
    //computed property group messages by section title (Today, Yesterday, etc.)
    private var groupedMessages: [(String, [ChatMessages])] {
        let grouped = Dictionary(grouping: messages) { msg -> String in
            guard let date = msg.timestamp else { return "Unknown" }
            return sectionTitle(for: date)
        }
        return grouped.sorted { lhs, rhs in
            guard let lDate = lhs.value.first?.timestamp,
                  let rDate = rhs.value.first?.timestamp else { return false }
            return lDate < rDate
        }
    }
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            //everything is vertical
            VStack {
                if let chat = viewModel.chats.first(where: { $0.id == chatID }) {
                    //this is for the profile,name, maybe active, and phone call (HEADER)
                    HStack(spacing: 15) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                        Button(action: {
                            if let currentUserID = Auth.auth().currentUser?.uid,
                               let otherUID = chat.otherUserID(currentUserID: currentUserID) {
                                print("Profile tapped for user id in messages group: \(otherUID)")
                                //this will take you to the profile user which is their ID not Video
                                path.append(.profile(otherUID))
                            }
                        }) {
                            ProfileImageView(imageUrl: chat.profileimage)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 0) {
                                Text(chat.username)
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.white)
                                if (chat.isProUser) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.appPrimaryColor)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        Spacer()
                        Button(action: {
                            print("phone button clicked")
                        }) {
                            Image(systemName: "phone")
                                .foregroundColor(.white)
                                .font(.system(size: 22, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                }
                //divider line that will indicate the messages now
                Divider().background(Color.white)
                ScrollViewReader { proxy in
                    //making the messages scrollable
                    ScrollView {
                        VStack(spacing: 4) {
                            //will indicate what date the text was send
                            ForEach(groupedMessages, id: \.0) { section, messagesInSection in
                                if let firstTime = messagesInSection.first?.timestamp {
                                    Text("\(section) \(formattedTime(from: firstTime))")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                        .padding(.top, 8)
                                }
                                //loops through the messages
                                ForEach(Array(messagesInSection.enumerated()), id: \.1.id) { index, message in
                                    if shouldInsertTimestamp(at: index, in: messagesInSection),
                                       let time = message.timestamp {
                                        Text(formattedTime(from: time))
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                            .padding(.top, 8)
                                    }
                                    //call the message view that will show all messages
                                    messageView(message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    //this dismisses the keyboard when user scrolls down
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages) { newMessages in
                        guard let last = newMessages.last else { return }
                        DispatchQueue.main.async {
                            if (!hasInitiallyScrolled) {
                                hasInitiallyScrolled = true
                                withAnimation(nil) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                            else {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .background(Color.black)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    replyBanner()
                    messageInputField()
                        .padding(.top, 10)
                }
            }
            .padding(.bottom, 10)
            //when this view loads-> it will then load up the convos as they update using the listerner
            .onAppear {
                //this will grab the data right away and set it to messages
                if let cached = viewModel.conversations.first(where: { $0.friend.id == chatID })?.messages {
                    self.messages = cached
                }
                //right after just listen to what we send 
                viewModel.listenToMessages(for: chatID) { msg in
                    self.messages = msg
                }
                showTranslateMessage = loadTranslatedSet(for: chatID)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    viewModel.markMessagesAsRead(for: chatID)
                }
            }
            //this will show whenever user taps so it is changing at that exact moment
            .onChange(of: showTranslateMessage) { newVal in
                saveTranslatedSet(newVal, for: chatID)
            }
            .onTapGesture {
                //dismiss the keyboard hwen users touches the chat
                focusfield = nil
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    tap.resetForNewDayIfNeeded()
                }
            }
            .overlay(
                ZStack {
                    if (showLimitAlert) {
                        Color.black.opacity(0.9)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .onTapGesture {
                                withAnimation {
                                    showLimitAlert = false
                                }
                            }
                        VStack {
                            Spacer()
                            GetProView()
                                .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.height * 0.5)
                                .padding(.horizontal, 20)
                                .background(
                                    Color(red: 22/255, green: 0/255, blue: 46/255)
                                        .cornerRadius(24)
                                )
                            Spacer()
                        }
                        .transition(.slideUpFromBottom)
                    }
                }
                .animation(.easeInOut, value: showLimitAlert)
            )
        }
    }
    //MARK: - This is the main view where the messages will show up
    private func messageView(_ message: ChatMessages) -> some View {
        HStack {
            //MARK: Users input
            if (message.isFromCurrentUser) {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let reply = message.repliedToText {
                        replyHeader(text: "You replied", reply: reply)
                    }
                    
                    //if its an audio message then show that
                    if (message.text.contains(".m4a")) {
                        AudioPlayerView(audioURL: message.text)
                            .frame(maxWidth: 240)
                            .padding(10)
                            .background(Color.linguidPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            //this will show the liked button for the user that the other user liked
                            .overlay(
                                Group {
                                    if (message.isLiked) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.white)
                                            //the heart will be this size
                                            .font(.system(size: 12))
                                            .padding(5)
                                            .background(Circle().fill(Color.gray))
                                            .offset(x: -5, y: -8)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    //else just a text message then go in here
                    else {
                        Text(message.text)
                            .padding(10)
                            .background(Color.linguidPurple)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            //this will show the liked button for the user that the other user liked
                            .overlay(
                                Group {
                                    if (message.isLiked) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.white)
                                            //the heart will be this size
                                            .font(.system(size: 12))
                                            .padding(5)
                                            .background(Circle().fill(Color.gray))
                                            .offset(x: -5, y: -8)
                                    }
                                },
                                alignment: .topLeading
                            )
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 280, alignment: .trailing)
                    }
                }
            }
            //MARK: Friends so shift left
            else {
                //checking if draggingMessageID will equal the message and if not then false
                let isDraggingMessage = draggingMessageID == message.id
                //dragging gestures and now calling the draggingMessageId in here to then compare it
                let dragGesture = DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if (value.translation.width > 0) {
                            state = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if (value.translation.width > 100) {
                            replyingTo = message
                        }
                        draggingMessageID = nil
                    }
                    .onChanged { value in
                        if (value.translation.width > 0) {
                            draggingMessageID = message.id
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    if let reply = message.repliedToText {
                        replyHeader(text: "Replied to you", reply: reply)
                    }
                    //if its an audio message then show that
                    if (message.text.contains(".m4a")) {
                        AudioPlayerView(audioURL: message.text)
                            .frame(maxWidth: 240)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                Group {
                                    if (message.isLiked) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.white)
                                            //the heart will be this size
                                            .font(.system(size: 12))
                                            .padding(5)
                                            .background(Circle().fill(Color.linguidPurple))
                                            .offset(x: 5, y: -8)
                                    }
                                },
                                alignment: .topTrailing
                            )
                            .onTapGesture(count: 2) {
                                toggleLike(for: message)
                            }
                    }
                    else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.text)
                                .foregroundColor(.black)
                            //they both have to be true in order to go in the statement
                            if showTranslateMessage.contains(message.id), let translated = message.translatedText {
                                Divider().background(Color.gray.opacity(0.4)).padding(.vertical, 2)
                                Text(translated)
                                    .font(.caption)
                                    .foregroundColor(.linguidPurple)
                            }
                            
                        }
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            Group {
                                if (message.isLiked) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.white)
                                        //the heart will be this size
                                        .font(.system(size: 12))
                                        .padding(5)
                                        .background(Circle().fill(Color.linguidPurple))
                                        .offset(x: 5, y: -8)
                                }
                            },
                            alignment: .topTrailing
                        )
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                toggleLike(for: message)
                            }
                        )
                        .onTapGesture {
                            //will only add once and will not add removal so if not in the set then return
                            guard !showTranslateMessage.contains(message.id) else { return }
                            if(tap.tryConsume()) {
                                showTranslateMessage.insert(message.id)
                                saveTranslatedSet(showTranslateMessage, for: chatID)
                            }
                            else {
                                showLimitAlert = true
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .offset(x: isDraggingMessage ? dragOffset : 0)
                .background(
                    //this will be arrow showing that user is replying
                    HStack {
                        if (isDraggingMessage) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .foregroundColor(.linguidPurple)
                                .opacity(Double(dragOffset / 100))
                                .scaleEffect(1 + dragOffset / 200)
                                .padding(.leading, 16)
                        }
                        //shift it to the left
                        Spacer()
                    }
                )
                .gesture(dragGesture)
                .animation(.easeOut(duration: 0.2), value: dragOffset)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
    }
    //MARK: - This will show who replied and with what message
    private func replyHeader(text: String, reply: String) -> some View {
        VStack(alignment: text == "You replied" ? .trailing : .leading, spacing: 4) {
            //this will shift the text of what they are replying to (either left or right)
            HStack {
                if (text == "You replied") {
                    Spacer()
                }
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                if (text == "Replied to you") {
                    Spacer()
                }
            }
            //this will now create the rectangle of either it is left or right then the reply message they are replying to
            HStack(spacing: 4) {
                if (text == "Replied to you") {
                    Rectangle().fill(Color.gray.opacity(0.4))
                        .frame(width: 3).cornerRadius(1.5)
                }
                //check if its an audio or text
                if (reply.contains(".m4a")) {
                    AudioPlayerView(audioURL: reply)
                        .frame(maxWidth: 240)
                        .padding(10)
                        .background(Color.linguidPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                else {
                    Text(reply)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                if (text == "You replied") {
                    Rectangle().fill(Color.gray.opacity(0.4))
                        .frame(width: 3).cornerRadius(1.5)
                }
            }
            .frame(maxWidth: 280, alignment: text == "You replied" ? .trailing : .leading)
        }
    }
    //MARK: - This will show the replying where user is replying to a message
    private func replyBanner() -> some View {
        //divider then replying with the xmark to exit
        VStack(alignment: .leading, spacing: 4) {
            if let reply = replyingTo {
                Divider().background(Color.gray)
                //have the replying of the text first hten the 'x' button to exit out
                HStack {
                    //check if text is replying to audio or text
                    Text("Replying to: \n\(reply.text.contains(".m4a") ? "Voice message" : reply.text)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Spacer()
                    Button(action: {
                        replyingTo = nil
                    }) {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    //MARK: - This is the input where user sends message
    private func messageInputField() -> some View {
        //message preview over the text field
        ZStack(alignment: .leading) {
            if (sendMessage.isEmpty) {
                //if recording is going to be send then show this else show the message
                if(isRecording) {
                    HStack(spacing: 10) {
                        //trash icon appears only if showSlideToCancel is true
                        if (showSlideToCancel) {
                            Image(systemName: isInDeleteZone ? "trash.fill" : "trash")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .background(isInDeleteZone ? Color.red : Color.gray.opacity(0.6))
                                .clipShape(Circle())
                                .scaleEffect(isInDeleteZone ? 1.15 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isInDeleteZone)
                        }
                        RecordingWaveformView(audioMeter: audioMeter)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                }
                else {
                    Text("Message...")
                        .foregroundColor(.black)
                        .padding(.horizontal)
                }
            }
            TextField("", text: $sendMessage, axis: .vertical)
                .foregroundColor(.black)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .focused($focusfield, equals: .sendMessage)
                .submitLabel(.send)
                .onChange(of: sendMessage) { value in
                    //since using the return in the axis we nust remove that newline and let it send messages
                    if value.last == "\n" {
                        sendMessage = String(value.dropLast())
                        send()
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                //.disabled(isRecording)
            HStack {
                Spacer()
                //only show mic if text messsage is empty
                if(sendMessage.isEmpty) {
                    Image(systemName: "mic")
                        .font(.system(size: 20))
                        .foregroundColor(isRecording ? .red : .black)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.2)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    switch value {
                                    case .first(true):
                                        //long-press began: start recording & show HUD
                                        if (!isRecording) {
                                            startRecording()
                                        }
                                        showSlideToCancel = true
                                        recordDragOffset = 0
                                        isInDeleteZone = false

                                    case .second(true, let drag?):
                                        //tracking the drag to the LEFT
                                        let dx = drag.translation.width
                                        recordDragOffset = min(0, dx)
                                        let overTrash = dx < -cancelDistance
                                        if overTrash != isInDeleteZone {
                                            isInDeleteZone = overTrash
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    default:
                                        break
                                    }
                                }
                                .onEnded { value in
                                    showSlideToCancel = false
                                    let shouldCancel: Bool
                                    if case .second(true, let drag?) = value {
                                        shouldCancel = drag.translation.width < -cancelDistance
                                    }
                                    else {
                                        shouldCancel = false
                                    }
                                    //if this remainds true then call the cancel recording function
                                    if (shouldCancel) {
                                        cancelRecording()
                                    }
                                    else {
                                        //user released without crossing threshold → send
                                        stopRecordingAndSend()
                                    }

                                    //resets HUD state
                                    recordDragOffset = 0
                                    isInDeleteZone = false
                                }
                        )
                }
            }
            .padding(.horizontal)
        }
        .frame(minHeight: 36, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .padding(.horizontal)
    }
    //function will start the recording when user is holding aka long press
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let tempDir = FileManager.default.temporaryDirectory
            let filename = UUID().uuidString + ".m4a"
            let audioPath = tempDir.appendingPathComponent(filename)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: audioPath, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            audioURL = audioPath
            isRecording = true
            audioMeter.stop()
            audioMeter.recorder = audioRecorder
            audioMeter.start()
            
        } catch {
            print("Recording failed: \(error)")
        }
    }
    //function will stop the recording once the users lets go of the hold aka long press
    private func stopRecordingAndSend() {
        audioRecorder?.stop()
        audioMeter.stop()
        isRecording = false

        //have to make sure we switch to playback mode so the AVPlayer works properly
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            //debugging
            print("Failed to set AVAudioSession for playback: \(error)")
        }

        guard let audioFileURL = audioURL else { return }

        //this will get the amplitudes, upload audio, send message
        AudioWaveformExtractor.shared.extractAmplitudes(from: AVAsset(url: audioFileURL), barCount: 30) { extractedBars in
            uploadAudioFile(audioFileURL) { audioURLString in
                if let audioURLString = audioURLString {
                    viewModel.sendMessage(audioURLString, to: chatID, replyingTo: replyingTo)
                    //TODO: add the amplituded to the viewmodel or the DB
                }
            }
        }
        self.audioURL = nil
        self.replyingTo = nil
    }
    //function will cancel the recording and not let user send it
    private func cancelRecording() {
        audioRecorder?.stop()
        audioMeter.stop()
        isRecording = false

        //reset session to playback so AVPlayer keeps working
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set AVAudioSession for playback after cancel: \(error)")
        }

        //delete the temporary audio file if it exists
        if let fileURL = audioURL {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Clear state
        audioURL = nil
        replyingTo = nil
    }
    //function will now upload the audo to the file and now this is where i call the states to update
    private func uploadAudioFile(_ fileURL: URL, completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference().child("voiceMessages/\(UUID().uuidString).m4a")
        storageRef.putFile(from: fileURL, metadata: nil) { metadata, error in
            if let error = error {
                print("Upload failed: \(error)")
                completion(nil)
                return
            }
            storageRef.downloadURL { url, error in
                if let downloadURL = url {
                    completion(downloadURL.absoluteString)
                }
                else {
                    completion(nil)
                }
            }
        }
    }
    //function calls the sendMessage() from the viewmodel and allows user to send a message
    private func send() {
        let trimmed = sendMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.sendMessage(trimmed, to: chatID, replyingTo: replyingTo)
        sendMessage = ""
        replyingTo = nil
        shouldScrollToBottom = true
    }
    //function will let the user know when the conversation was last happening
    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    //function will format the time
    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    //function will now insert the timestamp in the chat
    private func shouldInsertTimestamp(at index: Int, in messages: [ChatMessages]) -> Bool {
        guard index > 0,
              let current = messages[index].timestamp,
              let previous = messages[index - 1].timestamp else { return false }
        return current.timeIntervalSince(previous) > 3600
    }
    //function will call the isLiked and determine if it is true or not
    private func toggleLike(for message: ChatMessages) {
        viewModel.toggleLike(for: message, in: chatID)
    }
    //function will put the translation of the tap anywhere in the file
    private func loadTranslatedSet(for chatID: String) -> Set<String> {
        let key = "translated_\(chatID)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(arr)
    }
    //function will save the translation
    private func saveTranslatedSet(_ set: Set<String>, for chatID: String) {
        let key = "translated_\(chatID)"
        let data = try? JSONEncoder().encode(Array(set))
        UserDefaults.standard.set(data, forKey: key)
    }
}
