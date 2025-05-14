import Foundation
import AVFoundation


enum TrackState {
    case empty
    case recording
    case hasContent
    case playing
}


class Track: ObservableObject {
    var id: Int
    @Published var state: TrackState = .empty
    @Published var isMuted: Bool = false
    var audioFileUrl: URL // URL to the audio file
    var volume: Float = 1.0
    @Published var convertedModelId: Int?
    
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    
    // MARK: - Initialization
    init(id: Int) {
        self.id = id
        self.convertedModelId = nil
        // Initialize any track-specific properties
        self.playerNode = AVAudioPlayerNode()
        self.audioFileUrl = Track.getAudioFileURL(id)
        
        if FileManager.default.fileExists(atPath: self.audioFileUrl.path) {
            self.state = .hasContent
        }
    }
    
    class func getAudioFileURL(_ id: Int) -> URL {
        return getDocumentsDirectory().appendingPathComponent("recording_\(id).wav")
    }
    
    func updateState(_ newState: TrackState) {
        state = newState
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
            if FileManager.default.fileExists(atPath: audioFileUrl.path) {
                audioFile = try AVAudioFile(forReading: audioFileUrl)
            } else {
                print("file not exists in url yet: \(audioFileUrl)")
                return false
            }
        } catch {
            print("Track \(id): Error loading audio file: \(error)")
            audioFile = nil
            return false
        }
        
        print("Track \(id): Prepared for playback")
        return true
    }
    
    func scheduleToPlay(at time: AVAudioTime) {
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
        
        playerNode.volume = volume
        playerNode.scheduleFile(audioFile, at: time) {
            print("Track \(self.id): Finished playing")
        }
        playerNode.play()
        
        state = .playing
        print("Track \(id): Playing at \(time)")
    }
    
    func stop() {
        if state != .playing {
            print("Track \(id) is not playing")
            return
        }
        if let playerNode = playerNode {
            playerNode.stop()
            playerNode.reset()
            state = .hasContent
        }
        print("Track \(id): Stopped playback")
    }
    
    func mute() {
        isMuted = true
        print("Track \(id): Muted")
    }
    
    func unmute() {
        isMuted = false;
        print("Track \(id): Unmuted")
    }
    
    func reset() {
        if FileManager.default.fileExists(atPath: audioFileUrl.path) {
            do {
                try FileManager.default.removeItem(at: audioFileUrl)
                print("Deleted file at \(audioFileUrl.lastPathComponent)")
                state = .empty
                isMuted = false
                playerNode?.reset()
                audioFile = nil
                volume = 1.0
            } catch {
                print("Couldn’t delete file: \(error)")
            }
        } else {
            print("No file to delete at \(audioFileUrl.path)")
        }
    }
    
    func checkConversion(modelId: Int) -> Bool {
        var conversionURL = getDocumentsDirectory().appendingPathComponent("ConvertedWavs").appendingPathComponent("recording_\(id)_converted_\(modelId).wav")
        
        if FileManager.default.fileExists(atPath: conversionURL.path) {
            return true
        } else {
            print("file not exists in url: \(audioFileUrl)")
            return false
        }
    }
    
    func useConversion(modelId: Int) {
        convertedModelId = modelId
        audioFileUrl = getConvertedURL(modelId: modelId)
    }
    
    func useOriginal() {
        convertedModelId = nil
        audioFileUrl = getURL()
    }
    
    // MARK: - Playback Progress (Managed by SoundManager)
    var currentPlayheadTime: TimeInterval = 0.0 // SoundManager will update this
    
    // MARK: - Utility
    // Add any utility functions specific to a track
    
    // Expose the playerNode
    func getPlayerNode() -> AVAudioPlayerNode? {
        return playerNode
    }
    
    func getAudioFormat() -> AVAudioFormat? {
        return audioFile?.processingFormat
    }
    
    func getURL() -> URL {
        return audioFileUrl
    }
    
    func getConvertedURL(modelId: Int) -> URL {
        getDocumentsDirectory().appendingPathComponent("ConvertedWavs").appendingPathComponent("recording_\(id)_converted_\(modelId).wav")
    }
}
