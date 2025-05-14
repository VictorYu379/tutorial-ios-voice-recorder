import Foundation

class MainPageController: ObservableObject {
    @Published var focusedTrack: Int = 1
    @Published var isRecordMode = false
    @Published var isPlaybackMode = false
    private var tracks: [Int: Track]
    private var soundManager: SoundManager
    private var voiceConversionManager: VoiceConversionManager
    
    private var pageNum: Int = 1
    private var pollTimer: Timer?
    private var currentJobId: Int?
    
    init() {
        self.tracks = [
            1: Track(id: 1),
            2: Track(id: 2),
            3: Track(id: 3),
        ]
        self.soundManager = SoundManager(tracks: tracks)
        self.voiceConversionManager = VoiceConversionManager()
    }
    
    func toggleOverdub() {
        if isRecordMode {
            soundManager.stopRecording(trackNumber: focusedTrack)
            soundManager.stopPlayback()
        } else {
            if !soundManager.prepareForPlayback()
                || !soundManager.prepareToRecord(trackNumber: focusedTrack) {
                print("Overdub preparation failed")
                return
            }
            let startTime = SoundManager.getStartTime()
            soundManager.startRecording(trackNumber: focusedTrack, at: startTime.recordAt)
            soundManager.startPlayback(at: startTime.playAt, skippingTrack: focusedTrack)
        }
        isRecordMode.toggle()
    }
    
    func togglePlayback() {
        if isPlaybackMode {
            soundManager.stopPlayback()
        } else {
            let startTime = SoundManager.getStartTime()
            
            if !soundManager.prepareForPlayback() {
                print("Playback preparation failed")
                return
            }
            soundManager.startPlayback(at: startTime.playAt)
        }
        isPlaybackMode.toggle()
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
    
    func convertAudio(id: Int) {
        guard let track = tracks[id] else { return }
        
        // 1) start the conversion
        voiceConversionManager.startVoiceConversion(fileURL: track.getURL()) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jobId):
                    print("Job ID: \(jobId)")
                    self?.currentJobId = jobId
                    // 2) begin polling every 5s
                    self?.startPollingForConversion()
                    
                case .failure(let err):
                    print("Conversion error:", err)
                }
            }
        }
    }
    
    private func startPollingForConversion() {
        // invalidate any previous timer
        pollTimer?.invalidate()
        
        // schedule a new one
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let jobId = self.currentJobId else { return }
            self.checkConversion(jobId: jobId)
        }
    }
    
    private func checkConversion(jobId: Int) {
        voiceConversionManager.fetchConversion(jobId: jobId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileURL):
                    print("Conversion ready at URL:", fileURL)
                    // stop polling
                    self?.pollTimer?.invalidate()
                    self?.pollTimer = nil
                    
                    // download the file
                    let fileName = "converted_recording_\(self!.focusedTrack).wav"
                    self?.voiceConversionManager.downloadWav(from: fileURL, fileName: fileName) { downloadResult in
                        DispatchQueue.main.async {
                            switch downloadResult {
                            case .success(let localURL):
                                print("Saved WAV to:", localURL.path)
                                self?.changeToConvertedURL(url: localURL)
                            case .failure(let err):
                                print("Download/save error:", err)
                            }
                        }
                    }
                    
                case .failure(let err):
                    print("Still not ready (or error):", err)
                    // we keep polling
                }
            }
        }
    }
    
    private func changeToConvertedURL(url: URL) {
        tracks[focusedTrack]?.audioFileUrl = url
    }
}
