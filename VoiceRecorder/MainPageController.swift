import Foundation


enum AppState {
    case idle
    case playing
    case recording
    case converting
}

class MainPageController: ObservableObject, SoundManagerDelegate {
    
    @Published var focusedTrack: Int = 1
    @Published var state: AppState = .idle
    @Published var showPopupMenu: Bool = true
    @Published var showSyncSettings: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var totalDuration: Double = 0.0
    @Published var syncDelta: Double = 0.0 {  // Add property observer
        didSet {
            soundManager.delta = syncDelta
        }
    }
    @Published var project: ProjectInfo
    private let userDefaults = UserDefaults.standard
    private let SYNC_DELTA_KEY = "syncDelta"
    
    // Track state before seeking for resume functionality
    private var wasPlayingBeforeSeeking: Bool = false
    
    private var tracks: [Int: Track]
    private var soundManager: SoundManager
    private var voiceConversionManager: VoiceConversionManager
    
    private var pageNum: Int = 1
    
    init(project: ProjectInfo) {
        self.project = project
        self.tracks = [
            1: Track(projectId: project.id, id: 1),
            2: Track(projectId: project.id, id: 2),
            3: Track(projectId: project.id, id: 3),
        ]
        self.soundManager = SoundManager(projectId: project.id, tracks: tracks)
        self.voiceConversionManager = VoiceConversionManager()
        self.syncDelta = userDefaults.double(forKey: SYNC_DELTA_KEY)
        
        soundManager.delegate = self
        soundManager.updateTotalDuration()
        
        totalDuration = soundManager.totalDuration
        currentTime = soundManager.currentTime
    }
    
    func toggleOverdub() {
        if state == .recording {
            stopOverdub()
            state = .idle
        } else {
            startOverdub()
            state = .recording
        }
    }
    
    func togglePlayback() {
        print("project: \(project.name)")
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
        soundManager.stopPlaying()
        track.reset()
        soundManager.updateTotalDuration()
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
    
    func convertAudio(trackId: Int, modelId: Int, octaveShift: Int = 0) {
        guard let track = tracks[trackId] else { return }
        
        state = .converting
        
        print("conversion not existing, will call API")
        // one-liner now!
        voiceConversionManager.convert(
            fileURL: Track.getOriginalAudioFileURL(project.id, trackId),
            convertedFileURL: track.getConvertedURL(modelId: modelId),
            trackId: trackId,
            modelId: modelId,
            octaveShift: octaveShift
        ) { [weak self] downloadResult in
            DispatchQueue.main.async {
                switch downloadResult {
                case .failure(let err):
                    print("Conversion failed:", err)
                    
                case .success(let localURL):
                    print("Converted WAV saved to:", localURL.path)
                    // finally apply it to the track:
                    self?.tracks[trackId]?.useConversion(modelId: modelId, octaveShift: octaveShift)
                    self?.state = .idle
                    self?.showPopupMenu = true
                }
            }
        }
    }
    
    func shouldDisablePlaybackButtons() -> Bool {
        return state != .idle && state != .playing
    }
    
    func shouldDisableRecordButtons() -> Bool {
        return state != .idle && state != .recording || self.getTrack(id: focusedTrack).state == .hasContent
    }
    
    func shouldDisableConvertButton(model: SoundModel, track: Track, octaveShift: Int) -> Bool {
        return model.id <= 0 || model.isSeparator || !track.shouldConvert(newModelId: model.id, newOctaveShift: octaveShift)
    }
    
    // MARK: - SoundManagerDelegate
    func soundManagerDidUpdateProgress() {
        currentTime = soundManager.currentTime
    }
    
    func soundManagerDidFinishPlayback() {
        currentTime = 0.0
        state = .idle
    }
    
    func soundManagerDidUpdateTotalDuration() {
        totalDuration = soundManager.totalDuration
    }
    
    // MARK: - Progress Tracking Methods
    
    func pausePlaybackIfNeeded() {
        // Remember if we were playing before seeking
        wasPlayingBeforeSeeking = (state == .playing)
        
        if state == .playing {
            soundManager.pausePlaying()
            print("Paused playback for seeking. Was playing: \(wasPlayingBeforeSeeking)")
        }
    }
    
    func seekToTime(_ time: Double) {
        // Ensure the seek time is within valid bounds
        let seekTime = max(0.0, min(time, totalDuration))
        
        print("Seeking to: \(seekTime) seconds")
        
        soundManager.seekTo(seekTime)
        currentTime = seekTime
        if wasPlayingBeforeSeeking {
            soundManager.resumePlaying()
        }
        
        // Reset the seeking state flag
        wasPlayingBeforeSeeking = false
    }
    
    func updateSyncDelta(delta: Double) {
        userDefaults.set(delta, forKey: SYNC_DELTA_KEY)
    }
    
    private func stopOverdub() {
        soundManager.stopRecording(trackNumber: focusedTrack)
        soundManager.stopPlayback()
        soundManager.updateTotalDuration()
    }
    
    private func startOverdub() {
        // first reset the tracks
        soundManager.stopPlaying()
        
        if !soundManager.prepareForPlayback()
            || !soundManager.prepareToRecord(trackNumber: focusedTrack) {
            print("Overdub preparation failed")
            return
        }
        let startTime = soundManager.getStartTime()
        soundManager.startRecording(trackNumber: focusedTrack, at: startTime.recordAt)
        soundManager.startPlayback(at: startTime.playAt, skippingTrack: focusedTrack)
    }
    
    // MARK: - Playback Control Methods
    
    // Update the pause method
    private func pausePlaying() {
        soundManager.pausePlaying()
        print("Playback paused at \(currentTime) seconds")
        state = .idle
    }
    
    // Update the resume method
    private func resumePlaying() {
        soundManager.resumePlaying()
        state = .playing
        print("Resuming playback from \(currentTime) seconds")
    }
    
    // Update the stop method to reset offset
    private func stopPlaying() {
        soundManager.stopPlaying()
        print("Playback stopped and reset to beginning")
        // state = .idle
    }
}
