import Foundation
import AVFoundation

class SoundManager: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder!
    private var audioEngine: AVAudioEngine!
    @Published var isRecording: Bool = false  // Track recording state
    @Published var isPlaying: Bool = false // Track playback state
    @Published var hasStartedRecording: Bool = false // New state for actual start
    private var tracks: [Int: Track]

    // MARK: - Initialization
    init(tracks: [Int: Track]) {
        self.tracks = tracks
        self.audioEngine = AVAudioEngine()
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Recorder Setup
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker]) // Use .record
            try audioSession.setActive(true)
        } catch {
            print("Error initializing audio session: \(error)")
            audioRecorder = nil
        }
    }
    
    class func getStartTime() -> AVAudioTime {
        let offsetTicks = AVAudioTime.hostTime(forSeconds: 0.1)
        return AVAudioTime(hostTime: mach_absolute_time() + offsetTicks)
    }
    
    func prepareToRecord(trackNumber: Int) -> Bool {
        guard !isRecording else {
            print("Already recording.")
            return false
        }
        
        // Use trackNumber to construct the recording URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingURL = documentsDirectory.appendingPathComponent("recording_\(trackNumber).m4a") // Consistent naming

        do {
            let recordSettings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ] as [String : Any]
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: recordSettings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
        } catch {
            print("Error setting up audio recorder: \(error)")
            audioRecorder = nil
            return false
        }
        
        return true
    }
    
    // MARK: - Recording Control
    func startRecording(trackNumber: Int, at startTime: AVAudioTime) {
        guard !isRecording else {
            print("Already recording.")
            return
        }
        
        guard let audioRecorder = audioRecorder else {
            print("Audio recorder is not initialized.")
            return
        }
        
        // Schedule the recording at specific time
        let seconds: TimeInterval = AVAudioTime.seconds(forHostTime: startTime.hostTime)
        audioRecorder.record(atTime: seconds)
//        // Notify when recording *actually* starts
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//            self?.hasStartedRecording = true // Set this when recording begins
//            print("Recording actually started.")
//        }
        
        isRecording = true // Set the recording state *before* scheduling
        print("Scheduled recording for track \(trackNumber) in 0.1 seconds.")
    }

    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Finished recording to: \(recorder.url)")
            isRecording = false // Update recording state
            hasStartedRecording = false // Also reset this state
        } else {
            print("Recording failed.")
            isRecording = false
            hasStartedRecording = false
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio encode error occurred: \(error?.localizedDescription ?? "Unknown error")")
        isRecording = false
        hasStartedRecording = false
    }

    func stopRecording() {
        guard isRecording else {
            print("Not currently recording.")
            return
        }
        
        guard let audioRecorder = audioRecorder else {
            print("Audio recorder is not initialized.")
            return
        }

        audioRecorder.stop() // This will trigger delegate methods
        isRecording = false; //stopRecording should set this to false
        hasStartedRecording = false; // Also reset this.
        print("Stopped recording.")
    }
    
    // TODO: - Implement playback methods
    func prepareForPlayback() -> Bool {
        guard !isPlaying else {
            print("Already playing.")
            return false
        }
        
        guard let audioEngine = audioEngine else {
            print("Audio engine is not initialized.")
            return false
        }
        
        var havePlayback = false
        for track in tracks.values {
            // prepare playback on all tracks
            if !track.prepareForPlayback() {
                print("Track \(track.id) is not prepared for playback.")
                continue
            }
            
            // connect all nodes to mixer of the audio engine
            if let playerNode = track.getPlayerNode(), let audioFormat = track.getAudioFormat() {
                audioEngine.attach(playerNode)
                audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
                print("Track \(track.id) is connected to audio engine.")
                havePlayback = true
            } else {
                print("Track \(track.id) is not connected.")
            }
        }
        
        if havePlayback {
            do {
                try audioEngine.start()
            } catch {
                print("Error starting audio engine: \(error)")
                return false
            }
        }
        
        return true
    }
    
    func startPlayback(at startTime: AVAudioTime) {
        // get the time interval for playback start
        for track in tracks.values {
            track.scheduleToPlay(at: startTime)
        }
        
        isPlaying = true
    }
    
    func stopPlayback() {
        // stop all player nodes
        for track in tracks.values {
            track.stop()
        }
        
        isPlaying = false
    }

}
