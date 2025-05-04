import Foundation
import AVFoundation

class SoundManager: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder!
    private var recordingTimer: Timer?
    @Published var isRecording: Bool = false  // Track recording state
    @Published var hasStartedRecording: Bool = false // New state for actual start

    // MARK: - Initialization
    override init() {
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
        recordingTimer?.invalidate()
        recordingTimer = nil;
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio encode error occurred: \(error?.localizedDescription ?? "Unknown error")")
        isRecording = false
        hasStartedRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil;
    }

    // MARK: - Recording Control
    func startRecording(trackNumber: Int) {
        guard !isRecording else {
            print("Already recording.")
            return
        }
        
        // Use trackNumber to construct the recording URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingURL = documentsDirectory.appendingPathComponent("track_\(trackNumber).m4a") // Consistent naming

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
            audioRecorder = nil;
            return; // IMPORTANT: Return after error
        }
        
        // Schedule the recording to start after 0.5 seconds
        let timeOffset = audioRecorder.deviceCurrentTime + 0.5
        audioRecorder?.record(atTime: timeOffset)
        // Notify when recording *actually* starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.hasStartedRecording = true // Set this when recording begins
            print("Recording actually started.")
        }
        
        isRecording = true // Set the recording state *before* scheduling
        print("Scheduled recording for track \(trackNumber) in \(0.5) seconds.")

        // Set a timer to stop the recording after 3 minutes (180 seconds)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: false) { [weak self] _ in
            self?.stopRecording() // Use self?. to avoid retain cycles.
        }

    }

    func stopRecording() {
        guard isRecording else {
            print("Not currently recording.")
            return
        }

        audioRecorder?.stop() // This will trigger delegate methods
        recordingTimer?.invalidate()
        recordingTimer = nil;
        isRecording = false; //stopRecording should set this to false
        hasStartedRecording = false; // Also reset this.
        print("Stopped recording.")
        // The delegate method audioRecorderDidFinishRecording will handle saving.
    }
    
    // TODO: - Implement playback methods
}
