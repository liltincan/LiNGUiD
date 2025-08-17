//
//  AudioPlayerView.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 8/12/25.
//
import SwiftUI
import AVFoundation

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

