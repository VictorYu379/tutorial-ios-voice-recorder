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
        self.audioEngine.mainMixerNode.volume = 1.0
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Recorder Setup
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true)
            if audioSession.isInputGainSettable {
                do {
                    try audioSession.setInputGain(0.5)
                    print("Successfully set input gain to 1.0")
                } catch {
                    print("Error setting input gain: \(error.localizedDescription)")
                    throw error
                }
            } else {
                print("Input gain is not settable for the current audio route (\(audioSession.currentRoute.inputs.first?.portName ?? "Unknown Input")). Cannot set gain.")
            }
            logCurrentAudioRoute(for: audioSession, context: "Initial Setup")
        } catch {
            print("Error initializing audio session: \(error)")
            audioRecorder = nil
        }
    }
    
    // MARK: - Audio Route Handling & Logging
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        let session = AVAudioSession.sharedInstance()
        logCurrentAudioRoute(for: session, context: "Route Change - Reason: \(reason)")

        // Optional: Add logic to reconfigure engine or UI based on route changes
        // For example, if a preferred device is disconnected.
        // For Bluetooth, the system usually handles the switch well if the category is set correctly.
    }

    private func logCurrentAudioRoute(for session: AVAudioSession, context: String) {
        print("\n--- Audio Route Information (\(context)) ---")
        print("Category: \(session.category.rawValue), Options: \(session.categoryOptions)")
        print("Mode: \(session.mode.rawValue)")
        print("Sample Rate: \(session.sampleRate), IO Buffer Duration: \(session.ioBufferDuration)")

        if let currentRoute = session.currentRoute.outputs.first {
            print("Current Output: \(currentRoute.portName) (Type: \(currentRoute.portType.rawValue))")
        } else {
            print("No current output route.")
        }

        if let currentInput = session.currentRoute.inputs.first {
            print("Current Input: \(currentInput.portName) (Type: \(currentInput.portType.rawValue))")
//            print("Input Preferred Sample Rate: \(currentInput.preferredSampleRate)")
//            print("Input Preferred Channels: \(currentInput.preferredNumberOfChannels)")
        } else {
            print("No current input route.")
        }

        print("Available Inputs:")
        session.availableInputs?.forEach { inputPort in
            print("- \(inputPort.portName) (Type: \(inputPort.portType.rawValue)) UID: \(inputPort.uid)")
            if inputPort.portType == .bluetoothHFP || inputPort.portType == .bluetoothLE {
                 print("  (Bluetooth Mic: \(inputPort.portName))")
            }
        }
        print("--- End Audio Route Information ---\n")
    }

    class func getStartTime() -> (recordAt: AVAudioTime, playAt: AVAudioTime) {
        let baseDelay: TimeInterval = 0.1
        let delta = 0.35
        
//        let session = AVAudioSession.sharedInstance()
//        // These are in seconds
//        let inLatency  = session.inputLatency
//        let outLatency = session.outputLatency
        
        // If playback is slower (outLatency > inLatency), start playback earlier by that delta
        print("delta between input and output: \(delta)")
        
        // Compute a common hostTime anchor
        let hostTimeNow = mach_absolute_time()
        
        // Recorder at host + baseDelay
        let recordHost = hostTimeNow + AVAudioTime.hostTime(forSeconds: baseDelay + delta)
        // Playback at host + (baseDelay – delta) so it actually comes out at the same time as the recording start
        let playHost   = hostTimeNow + AVAudioTime.hostTime(forSeconds: baseDelay)
        
        return (
          recordAt: AVAudioTime(hostTime: recordHost),
          playAt:   AVAudioTime(hostTime: playHost)
        )
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
        print("Recording at \(startTime)")
        let seconds: TimeInterval = AVAudioTime.seconds(forHostTime: startTime.hostTime)
        audioRecorder.record(atTime: seconds)
//        // Notify when recording *actually* starts
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//            self?.hasStartedRecording = true // Set this when recording begins
//            print("Recording actually started.")
//        }
        
        isRecording = true // Set the recording state *before* scheduling
        tracks[trackNumber]?.state = .recording
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

    func stopRecording(trackNumber: Int) {
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
        tracks[trackNumber]?.state = .hasContent
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
    
    func startPlayback(at startTime: AVAudioTime, skippingTrack skipID: Int? = nil) {
        // get the time interval for playback start
        for track in tracks.values {
            // if this is the track to skip, don’t schedule it
            if let skip = skipID, track.id == skip {
                continue
            }
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
