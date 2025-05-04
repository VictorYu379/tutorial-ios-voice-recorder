//
//  NewMainPage.swift
//  VoiceRecorder
//
//  Created by Victor Yu on 5/2/25.
//  Copyright © 2025 Vasiliy Lada. All rights reserved.
//

import SwiftUI

struct MainPage: View {
    private let soundManager = SoundManager()
    @State private var focusedTrack: Int = 1
    @State private var isRecording = false
    
    var body: some View {
        VStack {
            // Top Controls
            HStack {
                Button(action: {
                    print("Metronome button tapped")
                }) {
                    Image(systemName: "metronome")
                        .font(.system(size: 30))
                        .foregroundColor(.blue) // Set metronome to blue
                }
                Spacer()
                Button(action: {
                    print("Sliders button tapped")
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 30))
                        .foregroundColor(.blue) // Set sliders to blue
                }
                Button(action: {
                    print("Recorder button tapped")
                    if isRecording {
                        soundManager.stopRecording()
                    } else {
                        soundManager.startRecording(trackNumber: focusedTrack)
                    }
                    isRecording.toggle()
                }) {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle")
                        .font(.system(size: 30))
                        .foregroundColor(.red)
                }
            }
            .padding()

            VStack{
                TrackView(trackNumber: 1, focusedTrack: $focusedTrack).padding(.bottom, 20)
                TrackView(trackNumber: 2, hasWaveform: true, focusedTrack: $focusedTrack).padding(.bottom, 20)
                TrackView(trackNumber: 3, focusedTrack: $focusedTrack).padding(.bottom, 20)
            }
            .padding(.vertical)

            Spacer()

            // Bottom Controls
            HStack {
                Button(action: {
                    print("backward button tapped")
                }) {
                    Image(systemName: "backward")
                        .font(.system(size: 30, weight: .semibold)) // Equivalent to largeTitle
                }

                Spacer()

                Button(action: {
                    print("skip back button tapped")
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 30, weight: .medium)) // Equivalent to title2 (approx.)
                        .padding(8)
                }

                Spacer()

                Button(action: {
                    print("play/pause button tapped")
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 30, weight: .semibold)) // Equivalent to largeTitle
                }

                Spacer()

                Button(action: {
                    print("skip forward button tapped")
                }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 30, weight: .medium)) // Equivalent to title2 (approx.)
                        .padding(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 50)
        .padding(.horizontal, 20)
    }
}

struct TrackView: View {
    let trackNumber: Int
    var hasWaveform: Bool = false
    @Binding var focusedTrack: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("Track \(trackNumber)")
                .font(.headline)
                .padding(.leading)
            RoundedRectangle(cornerRadius: 10)
                .fill(focusedTrack == trackNumber ? Color(.systemBlue).opacity(0.1) : Color(.systemGray6))
                .frame(height: 60)
                .overlay(
                    Group {
                        if hasWaveform {
                            HStack {
                                Spacer()
                                Image(systemName: "waveform.and.mic")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else {
                            Text("Empty")
                                .foregroundColor(.gray)
                        }
                    }
                )
                .padding(.horizontal)
                .onTapGesture {
                    focusedTrack = trackNumber
                }
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    MainPage()
}
