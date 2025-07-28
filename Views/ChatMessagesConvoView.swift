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
                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                        }
                        Button(action: {
                            if let currentUserID = Auth.auth().currentUser?.uid,
                               let otherUID = chat.otherUserID(currentUserID: currentUserID) {
                                print("Profile tapped for user id in messages group: \(otherUID)")
                                path.append(.profile(otherUID))
                            }
                        }) {
                            ProfileImageView(imageUrl: chat.profileimage)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.username)
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
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
                                        .padding(.bottom, 5)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
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
                //call the function where it shows the replying when users replies
                replyBanner()
                //call the function where users shows keyboard to send message
                messageInputField()
            }
            .background(Color.black)
            //.toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .padding(.bottom, 10)
            //when this view loads-> it will then load up the convos as they update using the listerner
            .onAppear {
                viewModel.listenToMessages(for: chatID) { msg in
                    self.messages = msg
                }
                viewModel.markMessagesAsRead(for: chatID)
            }
            .onTapGesture {
                //dismiss the keyboard hwen users touches the chat
                focusfield = nil
            }
        }
    }
    //MARK: - This is the main view where the messages will show up
    private func messageView(_ message: ChatMessages) -> some View {
        HStack {
            //shifts right since we are current users
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
            //shifts left since it's other users messages
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
                        Text(message.text)
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
                            .onTapGesture(count: 2) {
                                toggleLike(for: message)
                            }
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
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .frame(height: 50)
            if (sendMessage.isEmpty) {
                //if recording is going to be send then show this else show the message
                if(isRecording) {
                    RecordingWaveformView(audioMeter: audioMeter)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                else {
                    Text("Message...")
                        .foregroundColor(.black)
                        .padding(.horizontal)
                }
            }
            TextField("", text: $sendMessage)
                .foregroundColor(.black)
                .padding(.horizontal)
                .focused($focusfield, equals: .sendMessage)
                .submitLabel(.send)
                .onSubmit {
                    send()
                    focusfield = nil
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                //only show mic if text messsage is empty
                if(sendMessage.isEmpty) {
                    Image(systemName: "mic")
                        .font(.system(size: 20))
                        .foregroundColor(isRecording ? .red : .black)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.2)
                                .onEnded { _ in
                                    startRecording()
                                }
                                .simultaneously(with: DragGesture(minimumDistance: 0)
                                    .onEnded { _ in
                                        stopRecordingAndSend()
                                    }
                                )
                        )
                }
                
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
    //function will start the recording when user is holding aka long press
    func startRecording() {
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
                } else {
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
}
//MARK: - This will be the UI of how the audio should look
//precondition: call the WaveformView struct that will show the wave
//postcondition: this will now display the UI of how the voice message is going to look
struct AudioPlayerView: View {
    let audioURL: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playerObserver: Any?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isInitialized = false
    @State private var amplitudes: [CGFloat] = []
    
    var body: some View {
        //the option 'play' and 'pause' will be first then the waveform
        HStack(spacing: 12) {
            Button(action: {
                //run this and now call the setUpPlayer() and intialize it back to true to get out of the statement
                if (!isInitialized) {
                    setupPlayer()
                    isInitialized = true
                }
                //call the function to now show it
                togglePlayback()
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.purple)
            }
            //call the struct that shows the audio
            WaveformView(amplitudes: amplitudes.isEmpty ? Array(repeating: 10, count: 30) : amplitudes,
                         progress: currentTime / duration)
                .frame(height: 30)
                .animation(.easeInOut(duration: 0.2), value: currentTime)
            Spacer()
        }
        //once everything is done , call the function to clear the audios
        .onDisappear {
            cleanup()
        }
    }
    //function will set upt the ui for wehn the audio is sent
    private func setupPlayer() {
        //this will get the URL from the DB
        guard let url = URL(string: audioURL) else { return }
        let asset = AVAsset(url: url)
        self.duration = CMTimeGetSeconds(asset.duration)
        //this will now read the audios amplitudes from file
        AudioWaveformExtractor.shared.extractAmplitudes(from: asset, barCount: 30) { bars in
            self.amplitudes = bars
        }
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        playerObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.3, preferredTimescale: 600),
            queue: .main
        ) { time in
            self.currentTime = CMTimeGetSeconds(time)
        }
        //this now detects when audio finishes and if it does we have to reset it
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            self.isPlaying = false
            self.currentTime = 0
            self.player?.seek(to: .zero)
        }
    }
    //function will check if the video is playing if yes then play if pause then pause and show the pause
    private func togglePlayback() {
        guard let player = player else { return }
        //if its playing then show the pause button else show the play
        if (isPlaying) {
            player.pause()
        }
        else {
            player.play()
        }
        isPlaying.toggle()
    }
    //function will determine the time of the video
    private func cleanup() {
        player?.pause()
        if let observer = playerObserver {
            player?.removeTimeObserver(observer)
            playerObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
        player = nil
        isInitialized = false
    }
}
//MARK: - This will now show the waving
//precondition: none
//postcondition: takes in the WaveformBar() view then shows the progress
struct WaveformView: View {
    let amplitudes: [CGFloat]
    let progress: Double
    var body: some View {
        HStack(spacing: 2) {
            ForEach(amplitudes.indices, id: \.self) { i in
                let isActive = (Double(i) / Double(amplitudes.count)) < progress
                //call the bar which is just a rounded rectangle
                WaveformBar(height: amplitudes[i], isActive: isActive)
            }
        }
    }
}
//MARK: - This will be the start of the wave
//precondition: none
//postcondition: will take two variables that has the height and the active
struct WaveformBar: View {
    var height: CGFloat
    var isActive: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? Color.white : Color.gray.opacity(0.5))
            .frame(width: 3, height: height)
    }
}
//MARK: - This will be showing while user is recording the audio
//precondition: none
//postcondition: going to indicate when the audio is being recorded then show the wavelength
struct RecordingWaveformView: View {
    //just observed since we are calling it in the view
    @ObservedObject var audioMeter: AudioMeterObserver
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<audioMeter.levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3, height: audioMeter.levels[i])
            }
        }
        .frame(height: 30)
    }
}
//MARK: - This class will extract the real audio wave
class AudioWaveformExtractor {
    static let shared = AudioWaveformExtractor()
    //this function will attract the voice message by how loud it is
    func extractAmplitudes(from asset: AVAsset, barCount: Int, completion: @escaping ([CGFloat]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let reader = try? AVAssetReader(asset: asset),
                  let track = asset.tracks(withMediaType: .audio).first else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMBitDepthKey: 16
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            reader.add(output)
            reader.startReading()
            var samples: [Int16] = []
            while let buffer = output.copyNextSampleBuffer(),
                  let block = CMSampleBufferGetDataBuffer(buffer) {
                let length = CMBlockBufferGetDataLength(block)
                var data = [Int16](repeating: 0, count: length / 2)
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &data)
                samples.append(contentsOf: data)
            }

            let samplesPerBar = max(samples.count / barCount, 1)
            var amplitudes: [CGFloat] = []
            for i in 0..<barCount {
                let start = i * samplesPerBar
                let end = min((i + 1) * samplesPerBar, samples.count)
                if (start < end) {
                    let slice = samples[start..<end]
                    let maxAmp = slice.map { abs(Int($0)) }.max() ?? 0
                    let normalized = CGFloat(maxAmp) / CGFloat(Int16.max)
                    amplitudes.append(max(5, normalized * 30))
                }
            }

            DispatchQueue.main.async {
                completion(amplitudes)
            }
        }
    }
}
