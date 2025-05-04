import Foundation
import AVFoundation


class Track {
    let id = UUID() // Unique identifier for each track
    var isMuted: Bool = false
    var audioFileUrl: URL // URL to the audio file
    
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    
    // MARK: - Initialization
    init(audioFileURL: URL) { //  audioFileURL is now mandatory
        // Initialize any track-specific properties
        self.playerNode = AVAudioPlayerNode()
        self.audioFileUrl = audioFileURL
    }
    
    // MARK: - Audio Management
    func prepareForPlayback() -> Bool {
        /**
         * load the audio file
         *
         * Return False when
         *  - Track is muted
         *  - Track is playing
         *  - Cannot find audio file
         */
        guard !isMuted else {
            print("Track \(id): Track is muted, cannot prepare for playback")
            return false
        }
        guard let playerNode = playerNode, !playerNode.isPlaying else{
            print("Track \(id): Track is playing, cannot prepare for playback")
            return false
        }
        
        do {
            audioFile = try AVAudioFile(forReading: self.audioFileUrl)
        } catch {
            print("Track \(id): Error loading audio file: \(error)")
            audioFile = nil
            return false
        }
        
        print("Track \(id): Prepared for playback")
        return true
    }
    
    func scheduleToPlay(at time: TimeInterval) {
        /**
         *  Play the audio file at a specific time
         */
        guard !isMuted else {
            print("Track \(id): Track is muted, cannot prepare for playback")
            return
        }
        
        guard let playerNode = playerNode, let audioFile = audioFile else {
            print("Track \(id): Cannot play, audio file not loaded")
            return
        }
        
        if playerNode.isPlaying {
            playerNode.stop()
        }

        let startTime = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: time))
        
        playerNode.scheduleFile(audioFile, at: startTime) {
            print("Track \(self.id): Finished playing")
        }
        playerNode.play()
        
        print("Track \(id): Playing at \(time)")
    }
    
    func pause() {
        /**
         * Pause the playback
         */
        if let playerNode = playerNode {
            playerNode.pause()
        }
        print("Track \(id): Paused")
    }
    
    func mute() {
        isMuted = true
        print("Track \(id): Muted")
    }
    
    func unmute() {
        isMuted = false;
        print("Track \(id): Unmuted")
    }
    
    // MARK: - Playback Progress (Managed by SoundManager)
    var currentPlayheadTime: TimeInterval = 0.0 // SoundManager will update this
    
    // MARK: - Utility
    // Add any utility functions specific to a track
    
    // Expose the playerNode
    func getPlayerNode() -> AVAudioPlayerNode? {
        return playerNode
    }
}
