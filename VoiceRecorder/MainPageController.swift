import Foundation

class MainPageController: ObservableObject {
    @Published var focusedTrack: Int = 1
    @Published var isRecordMode = false
    @Published var isPlaybackMode = false
    @Published var isConverting: Bool = false
    @Published var showSlidersMenu: Bool = false
    private var tracks: [Int: Track]
    private var soundManager: SoundManager
    private var voiceConversionManager: VoiceConversionManager
    
    private var pageNum: Int = 1
    private var pollTimer: Timer?
    
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
        
        self.isConverting = true
        
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
                    self?.isConverting = false
                    self?.showSlidersMenu = true
                }
            }
        }
    }
}
