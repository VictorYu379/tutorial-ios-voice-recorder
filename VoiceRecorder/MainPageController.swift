//
//  MainViewController.swift
//  VoiceRecorder
//
//  Created by Victor Yu on 5/11/25.
//  Copyright © 2025 Vasiliy Lada. All rights reserved.
//

import Foundation

class MainPageController: ObservableObject {
    @Published var focusedTrack: Int = 1
    @Published var isRecording = false
    @Published var isPlaying = false
    private var tracks: [Int: Track]
    private var soundManager: SoundManager
    
    init() {
        self.tracks = [
            1: Track(id: 1),
            2: Track(id: 2),
            3: Track(id: 3),
        ]
        self.soundManager = SoundManager(tracks: tracks)
    }
    
    func toggleOverdub() {
        if isRecording {
            soundManager.stopRecording()
            soundManager.stopPlayback()
        } else {
            if !soundManager.prepareForPlayback()
                    || !soundManager.prepareToRecord(trackNumber: focusedTrack) {
                print("Overdub preparation failed")
                return
            }
            let startTime = SoundManager.getStartTime()
            soundManager.startRecording(trackNumber: focusedTrack, at: startTime)
            soundManager.startPlayback(at: startTime)
        }
        isRecording.toggle()
    }
    
    func togglePlayback() {
        if isPlaying {
            soundManager.stopPlayback()
        } else {
            let startTime = SoundManager.getStartTime()
            
            if !soundManager.prepareForPlayback() {
                print("Playback preparation failed")
                return
            }
            soundManager.startPlayback(at: startTime)
        }
        isPlaying.toggle()
    }
    
    func getTrack(id: Int) -> Track {
        return tracks[id]!
    }
}
