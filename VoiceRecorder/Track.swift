import Foundation
import AVFoundation


enum TrackState {
    case empty
    case recording
    case hasContent
    case playing
}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

class Track: ObservableObject {
    private static let userDefaults = UserDefaults.standard
    private static let MUTED_KEY = "muted"
    private static let VOLUME_KEY = "volume"
    private static let CONVERTED_MODEL_ID_KEY = "convertedModelId"

    var projectId: UUID
    var id: Int
    var audioFileUrl: URL // URL to the audio file
    @Published var state: TrackState = .empty
    @Published var isMuted: Bool = false
    @Published var volume: Float = 1.0
    @Published var convertedModelId: Int?
    
    private let volumeKey: String
    private let convertedKey: String
    private let mutedKey: String
    
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?

    // MARK: - Initialization
    init(projectId: UUID, id: Int) {
        self.projectId = projectId
        self.id = id
        self.mutedKey = "\(projectId)_\(id)_\(Track.MUTED_KEY)"
        self.volumeKey = "\(projectId)_\(id)_\(Track.VOLUME_KEY)"
        self.convertedKey = "\(projectId)_\(id)_\(Track.CONVERTED_MODEL_ID_KEY)"

        self.isMuted = Track.userDefaults.bool(forKey: mutedKey)
        self.volume = Track.userDefaults.object(forKey: volumeKey) != nil ? Track.userDefaults.float(forKey: volumeKey) : 1.0
        self.convertedModelId = Track.userDefaults.object(forKey: convertedKey) != nil ? Track.userDefaults.integer(forKey: convertedKey) : nil

        // Initialize any track-specific properties
        self.playerNode = AVAudioPlayerNode()
        self.audioFileUrl = Track.getAudioFileURL(projectId, id)
        
        if FileManager.default.fileExists(atPath: self.audioFileUrl.path) {
            self.state = .hasContent

            if let convertedModelId = convertedModelId {
                audioFileUrl = getConvertedURL(modelId: convertedModelId)
            }
        }
    }
    
    class func getAudioFileURL(_ projectId: UUID, _ id: Int) -> URL {
        return getDocumentsDirectory().appendingPathComponent("recording_\(projectId)_\(id).wav")
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
        Track.userDefaults.set(isMuted, forKey: mutedKey)
        print("Track \(id): Muted")
    }
    
    func unmute() {
        isMuted = false;
        Track.userDefaults.set(isMuted, forKey: mutedKey)
        print("Track \(id): Unmuted")
    }
    
    func reset() {
        let originalFileUrl = Track.getAudioFileURL(projectId, id)
        if FileManager.default.fileExists(atPath: originalFileUrl.path) {
            do {
                try FileManager.default.removeItem(at: originalFileUrl)
                print("Deleted file at \(originalFileUrl.lastPathComponent)")
                self.deleteConvertedFiles(withPrefix: "recording_\(projectId)_\(id)")
                self.removeKeys()
                state = .empty
                isMuted = false
                playerNode?.reset()
                audioFileUrl = Track.getAudioFileURL(projectId, id)
                convertedModelId = nil
                audioFile = nil
                volume = 1.0
            } catch {
                print("Couldn’t delete file: \(error)")
            }
        } else {
            print("No file to delete at \(originalFileUrl.path)")
        }
    }
    
    func checkConversion(modelId: Int) -> Bool {
        let conversionURL = getDocumentsDirectory().appendingPathComponent("ConvertedWavs").appendingPathComponent("recording_\(projectId)_\(id)_converted_\(modelId).wav")
        
        if FileManager.default.fileExists(atPath: conversionURL.path) {
            return true
        } else {
            print("file not exists in url: \(audioFileUrl)")
            return false
        }
    }
    
    func useConversion(modelId: Int) {
        convertedModelId = modelId
        Track.userDefaults.set(convertedModelId, forKey: convertedKey)
        audioFileUrl = getConvertedURL(modelId: modelId)
    }
    
    func useOriginal() {
        convertedModelId = nil
        Track.userDefaults.set(convertedModelId, forKey: convertedKey)
        audioFileUrl = Track.getAudioFileURL(projectId, id)
    }
    
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
        getDocumentsDirectory().appendingPathComponent("ConvertedWavs").appendingPathComponent("recording_\(projectId)_\(id)_converted_\(modelId).wav")
    }
    
    // MARK: - Audio Duration and Seeking Methods
    
    func getAudioDuration() -> Double? {
        guard let audioFile = audioFile else {
            // Try to load the audio file to get duration
            do {
                if FileManager.default.fileExists(atPath: audioFileUrl.path) {
                    let tempAudioFile = try AVAudioFile(forReading: audioFileUrl)
                    let duration = Double(tempAudioFile.length) / tempAudioFile.fileFormat.sampleRate
                    return duration
                }
            } catch {
                print("Track \(id): Error loading audio file for duration: \(error)")
            }
            return nil
        }
        
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        return duration
    }
    
    func seekAndSchedulePlayback(at time: AVAudioTime, seekTime: Double) {
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
        
        // Calculate the frame position to start from
        let sampleRate = audioFile.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(seekTime * sampleRate)
        let frameCount = audioFile.length - startFrame
        
        guard startFrame >= 0 && startFrame < audioFile.length else {
            print("Track \(id): Seek time out of bounds")
            return
        }
        
        playerNode.volume = volume
        
        // Schedule the file segment starting from the seek position
        playerNode.scheduleSegment(audioFile, startingFrame: startFrame, frameCount: AVAudioFrameCount(frameCount), at: time) {
            print("Track \(self.id): Finished playing from seek position")
        }
        
        playerNode.play()
        state = .playing
        print("Track \(id): Playing from \(seekTime) seconds at \(time)")
    }

    func updateVolume(volume: Float) {
        self.volume = volume
        Track.userDefaults.set(volume, forKey: volumeKey)
    }

    private func deleteConvertedFiles(withPrefix prefix: String) {
        let fileManager = FileManager.default
        let folderURL = getDocumentsDirectory().appendingPathComponent("ConvertedWavs")
        
        do {
            // 1) List everything in the folder
            let files = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: []
            )
            
            // 2) Filter those whose filename begins with your prefix
            let matching = files.filter { $0.lastPathComponent.hasPrefix(prefix) }
            
            // 3) Remove each one
            for fileURL in matching {
                do {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted:", fileURL.lastPathComponent)
                } catch {
                    print("Failed to delete \(fileURL.lastPathComponent):", error)
                }
            }
        } catch {
            print("Couldn’t list directory:", error)
        }
    }

    private func removeKeys() {
        Track.userDefaults.removeObject(forKey: mutedKey)
        Track.userDefaults.removeObject(forKey: volumeKey)
        Track.userDefaults.removeObject(forKey: convertedKey)
    }
}
