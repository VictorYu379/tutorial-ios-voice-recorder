//
//  ViewController.swift
//  VoiceRecorder
//
//  Created by  William on 2/6/19.
//  Updated for overdub and mix playback by [Your Name] on [Date].
//  Copyright © 2019 Vasiliy Lada. All rights reserved.
//

import UIKit
import AVFoundation

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

class ViewController: UIViewController {

    @IBOutlet var recordButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var overdubButton: UIButton!      // Button to record overdub track
    @IBOutlet var mixPlaybackButton: UIButton!   // Button to play both tracks in parallel
    
    var recordingSession: AVAudioSession!
    
    // Main track properties
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    
    // Overdub track property
    var audioRecorder2: AVAudioRecorder?
    
    // Engine for mixing playback
    var mixAudioEngine: AVAudioEngine?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.loadRecordingUI()
                    } else {
                        // Handle lack of permission as needed.
                    }
                }
            }
        } catch {
            // Handle session configuration errors.
        }
    }
    
    func loadRecordingUI() {
        // Show only the main record button initially.
        recordButton.isHidden = false
        recordButton.setTitle("Tap to Record", for: .normal)
        
        // Hide the other buttons until the main track is recorded.
        playButton.isHidden = true
        overdubButton.isHidden = true
        mixPlaybackButton.isHidden = true
    }
    
    // MARK: - IBActions
    
    @IBAction func recordButtonPressed(_ sender: UIButton) {
        if audioRecorder == nil {
            startRecording()
        } else {
            finishRecording(success: true)
        }
    }
    
    @IBAction func playButtonPressed(_ sender: UIButton) {
        if audioPlayer == nil {
            startPlayback()
        } else {
            finishPlayback()
        }
    }
    
    @IBAction func overdubButtonPressed(_ sender: UIButton) {
        // Toggle overdub recording.
        if audioRecorder2 == nil && audioPlayer == nil {
            do {
                let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
                audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
                audioPlayer.delegate = self
                audioPlayer.prepareToPlay()
                
                let track2URL = getDocumentsDirectory().appendingPathComponent("recording2.m4a")
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                audioRecorder2 = try AVAudioRecorder(url: track2URL, settings: settings)
                audioRecorder2?.delegate = self
                audioRecorder2?.prepareToRecord()
                
                let timeOffset = audioPlayer.deviceCurrentTime + 0.1
                audioPlayer.play(atTime: timeOffset)
                audioRecorder2?.record(atTime: timeOffset)
                
                overdubButton.setTitle("Stop Overdub", for: .normal)
            } catch {
                print("error!!!!!")
            }
        } else {
            finishOverdubRecording(success: true)
        }
    }
    
    @IBAction func mixPlaybackButtonPressed(_ sender: UIButton) {
        // Toggle mix playback using AVAudioEngine.
        if mixAudioEngine == nil {
            startMixPlayback()
        } else {
            stopMixPlayback()
        }
    }
    
    // MARK: - Main Track Recording
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
            recordButton.setTitle("Tap to Stop", for: .normal)
        } catch {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        audioRecorder.stop()
        audioRecorder = nil
        
        if success {
            recordButton.setTitle("Tap to Re-record", for: .normal)
            playButton.isHidden = false
            playButton.setTitle("Play Your Recording", for: .normal)
            overdubButton.isHidden = false
            overdubButton.setTitle("Start Overdub", for: .normal)
            // Unhide mix playback button if overdub file exists later.
            mixPlaybackButton.isHidden = false
            mixPlaybackButton.setTitle("Play Both Tracks", for: .normal)
        } else {
            recordButton.setTitle("Tap to Record", for: .normal)
            playButton.isHidden = true
            overdubButton.isHidden = true
            mixPlaybackButton.isHidden = true
        }
    }
    
    // MARK: - Playback of Main Track
    
    func startPlayback() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
            audioPlayer.delegate = self
            audioPlayer.play()
            playButton.setTitle("Stop Playback", for: .normal)
        } catch {
            playButton.isHidden = true
        }
    }
    
    func finishPlayback() {
        audioPlayer = nil
        playButton.setTitle("Play Your Recording", for: .normal)
    }
    
    // MARK: - Overdub (Second Track Recording)
    
    func recordSecondTrack() {
        let track2URL = getDocumentsDirectory().appendingPathComponent("recording2.m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder2 = try AVAudioRecorder(url: track2URL, settings: settings)
            audioRecorder2?.delegate = self
            audioRecorder2?.record()
            overdubButton.setTitle("Stop Overdub", for: .normal)
        } catch {
            print("Error starting overdub recording: \(error)")
        }
    }
    
    func finishOverdubRecording(success: Bool) {
        audioRecorder2?.stop()
        audioRecorder2 = nil
        
        if success {
            overdubButton.setTitle("Start Overdub", for: .normal)
        } else {
            overdubButton.setTitle("Start Overdub", for: .normal)
        }
    }
    
    // MARK: - Mix Playback using AVAudioEngine
    
    func startMixPlayback() {
        // Create a new AVAudioEngine instance.
        mixAudioEngine = AVAudioEngine()
        guard let engine = mixAudioEngine else { return }
        
        // Create two player nodes, one for each track.
        let playerNode1 = AVAudioPlayerNode()
        let playerNode2 = AVAudioPlayerNode()
        
        // Attach the player nodes to the engine.
        engine.attach(playerNode1)
        engine.attach(playerNode2)
        
        // Get file URLs for the main and overdub tracks.
        let fileURL1 = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        let fileURL2 = getDocumentsDirectory().appendingPathComponent("recording2.m4a")
        
        var audioFile1: AVAudioFile!
        var audioFile2: AVAudioFile!
        
        do {
            audioFile1 = try AVAudioFile(forReading: fileURL1)
            audioFile2 = try AVAudioFile(forReading: fileURL2)
        } catch {
            print("Error loading audio files: \(error)")
            return
        }
        
        // Connect the player nodes to the engine's main mixer node.
        engine.connect(playerNode1, to: engine.mainMixerNode, format: audioFile1.processingFormat)
        engine.connect(playerNode2, to: engine.mainMixerNode, format: audioFile2.processingFormat)
        
        // Schedule playback of both audio files.
        playerNode1.scheduleFile(audioFile1, at: nil, completionHandler: nil)
        playerNode2.scheduleFile(audioFile2, at: nil, completionHandler: nil)
        
        do {
            try engine.start()
        } catch {
            print("Error starting audio engine: \(error)")
            return
        }
        
        // Start playing both nodes.
        playerNode1.play()
        playerNode2.play()
        
        mixPlaybackButton.setTitle("Stop Mix Playback", for: .normal)
    }
    
    func stopMixPlayback() {
        mixAudioEngine?.stop()
        mixAudioEngine = nil
        mixPlaybackButton.setTitle("Play Both Tracks", for: .normal)
    }
    
}

extension ViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if recorder == audioRecorder {
            if !flag {
                finishRecording(success: false)
            }
        } else if recorder == audioRecorder2 {
            if !flag {
                finishOverdubRecording(success: false)
            }
        }
    }
    
}

extension ViewController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finishPlayback()
    }
    
}
