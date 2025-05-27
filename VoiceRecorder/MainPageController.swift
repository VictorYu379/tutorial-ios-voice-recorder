import Foundation


enum AppState {
    case idle
    case playing
    case recording
    case converting
}

class MainPageController: ObservableObject {
    @Published var focusedTrack: Int = 1
    @Published var state: AppState = .idle
    @Published var showSlidersMenu: Bool = false
    
    // Progress tracking properties
    @Published var currentTime: Double = 0.0
    @Published var totalDuration: Double = 0.0
    @Published var isSeekingProgress: Bool = false
    
    private var tracks: [Int: Track]
    private var soundManager: SoundManager
    private var voiceConversionManager: VoiceConversionManager
    private var progressTimer: Timer?
    
    private var pageNum: Int = 1
    private var pollTimer: Timer?
    private var resumeOffset: Double = 0.0
    
    init() {
        self.tracks = [
            1: Track(id: 1),
            2: Track(id: 2),
            3: Track(id: 3),
        ]
        self.soundManager = SoundManager(tracks: tracks)
        self.voiceConversionManager = VoiceConversionManager()
        updateTotalDuration()
    }
    
    func toggleOverdub() {
        if state == .recording {
            stopOverdub()
            state = .idle
        } else {
            state = .recording
            startOverdub()
        }
    }
    
    func togglePlayback() {
        if state == .playing {
            pausePlaying()
        } else {
            resumePlaying()
        }
    }

    func stopPlayback() {
        stopPlaying()
    }
    
    func toggleMute(id: Int) {
        guard let track = tracks[id] else {
            return
        }
        if track.isMuted {
            track.unmute()
        } else {
            track.mute()
        }
    }
    
    func deleteAudio(id: Int) {
        guard let track = tracks[id] else {
            return
        }
        track.reset()
        updateTotalDuration()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func getTrack(id: Int) -> Track {
        return tracks[id]!
    }
    
    func getVoiceModel() {
        self.voiceConversionManager.fetchVoiceModels(page: pageNum) { result in
            switch result {
            case .success(let models):
                print("API response: \(models.count)")
                for model in models {
                    print("Title: \(model.title), ID: \(model.id)")
                }
            case .failure(let err):
                print("Error fetching voice models:", err)
            }
        }
        pageNum = pageNum + 1
    }
    
    func convertAudio(trackId: Int, modelId: Int) {
        guard let track = tracks[trackId] else { return }
        
        if track.convertedModelId == modelId {
            track.useOriginal()
            print("will restore to original audio")
            return
        }
        
        if track.checkConversion(modelId: modelId) {
            track.useConversion(modelId: modelId)
            print("will use existing conversion")
            return
        }
        
        state = .converting
        
        print("conversion not existing, will call API")
        // one-liner now!
        voiceConversionManager.convert(
            fileURL: track.getURL(),
            convertedFileURL: track.getConvertedURL(modelId: modelId),
            trackId: trackId,
            modelId: modelId
        ) { [weak self] downloadResult in
            DispatchQueue.main.async {
                switch downloadResult {
                case .failure(let err):
                    print("Conversion failed:", err)
                    
                case .success(let localURL):
                    print("Converted WAV saved to:", localURL.path)
                    // finally apply it to the track:
                    self?.tracks[trackId]?.useConversion(modelId: modelId)
                    self?.state = .idle
                    self?.showSlidersMenu = true
                }
            }
        }
    }

    func shouldDisablePlaybackButtons() -> Bool {
        return state != .idle && state != .playing
    }

    func shouldDisableRecordButtons() -> Bool {
        return state != .idle && state != .recording
    }

    // MARK: - Progress Tracking Methods
    
    func updateTotalDuration() {
        var maxDuration: Double = 0.0
        for track in tracks.values {
            if track.state == .hasContent || track.state == .playing {
                if let duration = track.getAudioDuration() {
                    maxDuration = max(maxDuration, duration)
                }
            }
        }
        totalDuration = maxDuration
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, !self.isSeekingProgress else { return }
            self.updateCurrentTime()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateCurrentTime() {
        // Find any playing track to get the current time reference
        for track in tracks.values {
            if track.state == .playing, let playerNode = track.getPlayerNode() {
                if let lastRenderTime = playerNode.lastRenderTime,
                   let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) {
                    let elapsedTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                    currentTime = resumeOffset + elapsedTime
                    break // Use the first playing track as reference
                }
            }
        }
        
        // Ensure current time doesn't exceed total duration
        currentTime = min(currentTime, totalDuration)
        
        // If we've reached the end of the longest track, stop and reset to beginning
        if currentTime >= totalDuration {
            print("Playback finished - resetting to beginning")
            stopPlaying()
        }
    }
    
    func seekToTime(_ time: Double) {
        // TODO: Implement seeking logic later
        print("Seeking to: \(time) seconds (not implemented yet)")
    }

    private func stopOverdub() {
        soundManager.stopRecording(trackNumber: focusedTrack)
        soundManager.stopPlayback()
        updateTotalDuration()
    }

    private func startOverdub() {
        if !soundManager.prepareForPlayback()
            || !soundManager.prepareToRecord(trackNumber: focusedTrack) {
            print("Overdub preparation failed")
            return
        }
        let startTime = SoundManager.getStartTime()
        soundManager.startRecording(trackNumber: focusedTrack, at: startTime.recordAt)
        soundManager.startPlayback(at: startTime.playAt, skippingTrack: focusedTrack)
    }

    // MARK: - Playback Control Methods

    // Update the pause method
    private func pausePlaying() {
        soundManager.stopPlayback()
        stopProgressTimer()
        print("Playback paused at \(currentTime) seconds")
        state = .idle
    }
    
    // Update the resume method
    private func resumePlaying() {
        // Set the resume offset to current position
        resumeOffset = currentTime
        
        let startTime = SoundManager.getStartTime()
        if !soundManager.prepareForPlayback() {
            print("Playback preparation failed")
            return
        }
        
        state = .playing
        print("Resuming playback from \(currentTime) seconds")
        
        // Schedule tracks that have content at current position
        for track in tracks.values {
            if let trackDuration = track.getAudioDuration(), currentTime < trackDuration {
                track.seekAndSchedulePlayback(at: startTime.playAt, seekTime: currentTime)
            }
        }
        soundManager.isPlaying = true
        startProgressTimer()
    }
    
    // Update the stop method to reset offset
    private func stopPlaying() {
        soundManager.stopPlayback()
        stopProgressTimer()
        currentTime = 0.0
        resumeOffset = 0.0  // Reset offset
        print("Playback stopped and reset to beginning")
        state = .idle
    }
}
