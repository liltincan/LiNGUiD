//
//  AudioObserverViewModel.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 7/25/25.
//
import SwiftUI
import Foundation
import AVFoundation

@MainActor
class AudioMeterObserver: ObservableObject {
    @Published var levels: [CGFloat] = Array(repeating: 0.0, count: 20)
    private var timer: Timer?
    var recorder: AVAudioRecorder?
    
    //intialize the constructor
    init(recorder: AVAudioRecorder?) {
        self.recorder = recorder
        recorder?.isMeteringEnabled = true
        start()
    }
    //MARK: - Start of audio
    //precondition: none
    //postcondition: going to get back the audio and check how high the voice is
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task {
                await MainActor.run {
                    guard let self = self,
                          let recorder = self.recorder else { return }

                    recorder.updateMeters()
                    let avgPower = recorder.averagePower(forChannel: 0)
                    let normalized = max(0, CGFloat(avgPower + 50) / 50)

                    self.levels = self.levels.map { _ in
                        CGFloat.random(in: 10...(10 + normalized * 20))
                    }
                }
            }
        }
    }
    //MARK: - Stop audio
    //precondition: none
    //postcondition: this will stop the audio
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
