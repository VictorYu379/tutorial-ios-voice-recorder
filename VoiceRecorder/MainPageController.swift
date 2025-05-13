import Foundation

class MainPageController: ObservableObject {
    @Published var focusedTrack: Int = 1
    @Published var isRecordMode = false
    @Published var isPlaybackMode = false
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
}
