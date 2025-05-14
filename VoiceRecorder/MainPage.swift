//
//  NewMainPage.swift
//  VoiceRecorder
//
//  Created by Victor Yu on 5/2/25.
//  Copyright © 2025 Vasiliy Lada. All rights reserved.
//

import SwiftUI

struct MainPage: View {
    @StateObject private var controller = MainPageController()
    @State private var showSlidersMenu = true
    
    var body: some View {
        VStack {
            // Top Controls
            HStack {
                Button(action: {
                    print("Metronome button tapped")
                    controller.getVoiceModel()
                }) {
                    Image(systemName: "metronome")
                        .font(.system(size: 30))
                        .foregroundColor(.blue) // Set metronome to blue
                }
                Spacer()
                Button(action: {
                    print("Sliders button tapped")
                    showSlidersMenu = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 30))
                        .foregroundColor(.blue) // Set sliders to blue
                }
                Button(action: {
                    print("Recorder button tapped")
                    controller.toggleOverdub()
                }) {
                    Image(systemName: controller.isRecordMode ? "stop.fill" : "record.circle")
                        .font(.system(size: 30))
                        .foregroundColor(.red)
                }
            }
            .frame(maxHeight: 60)
            .padding()
            
            VStack{
                TrackView(track: controller.getTrack(id: 1), focused: $controller.focusedTrack).padding(.bottom, 20)
                TrackView(track: controller.getTrack(id: 2), focused: $controller.focusedTrack).padding(.bottom, 20)
                TrackView(track: controller.getTrack(id: 3), focused: $controller.focusedTrack).padding(.bottom, 20)
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
                    controller.togglePlayback()
                }) {
                    Image(systemName: controller.isPlaybackMode ? "pause.fill" : "play.fill")
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
        
        // 3) attach the sheet here
        .sheet(isPresented: $showSlidersMenu) {
            SlidersMenuView(track: controller.getTrack(id: controller.focusedTrack))
                .environmentObject(controller)
                .presentationDetents([.fraction(0.7)])   // exactly half screen
                .presentationDragIndicator(.visible)      // shows the grab bar
        }
    }
}

struct TrackView: View {
    @StateObject var track: Track
    var hasWaveform: Bool = false
    @Binding var focused: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Track \(track.id)")
                .font(.headline)
                .padding(.leading)
            RoundedRectangle(cornerRadius: 10)
                .fill(focused == track.id ? Color(.systemBlue).opacity(0.1) : Color(.systemGray6))
                .frame(height: 60)
                .overlay(
                    Group {
                        if track.isMuted {
                            HStack {
                                Spacer()
                                Image(systemName: "speaker.slash.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else if track.state == .hasContent {
                            HStack {
                                Spacer()
                                Image(systemName: "waveform.and.mic")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else if track.state == .recording {
                            Text("Recording")
                                .foregroundColor(.gray)
                        } else if track.state == .playing {
                            Text("Playing")
                                .foregroundColor(.gray)
                        } else {
                            Text("Empty")
                                .foregroundColor(.gray)
                        }
                    }
                )
                .padding(.horizontal)
                .onTapGesture {
                    focused = track.id
                }
        }
        .padding(.bottom, 8)
    }
}

struct SlidersMenuView: View {
    @StateObject var track: Track
    @EnvironmentObject var controller: MainPageController
    
    // choose a width that fits both "Mute" and "Unmute"
    private let pillWidth: CGFloat = 100
    private let pillHeight: CGFloat = 40
    
    var body: some View {
        VStack {
            Text("Track \(track.id)")
                .font(.headline)
                .padding()
            
            // — Volume Slider
            VStack(alignment: .leading) {
                Text("Volume")
                    .font(.subheadline)
                Slider(
                    value: Binding(
                        get: { track.volume },
                        set: { newVal in
                            track.volume = newVal
                        }
                    ),
                    in: 0...1
                )
                .disabled(track.isMuted)
                .opacity(track.isMuted ? 0.5 : 1)
            }
            .padding()
            
            HStack(spacing: 40) {
                // — Mute/Unmute
                Button {
                    controller.toggleMute(id: track.id)
                } label: {
                    Text(track.isMuted ? "Unmute" : "Mute")
                        .font(.headline)
                        .frame(width: pillWidth, height: pillHeight)
                        .background(
                            Capsule()
                                .fill(controller
                                    .getTrack(id: track.id)
                                    .isMuted
                                      ? Color.yellow.opacity(0.2)
                                      : Color.gray.opacity(0.2)
                                )
                        )
                        .foregroundColor(.primary)
                }
                
                // Delete button
                Button {
                    controller.deleteAudio(id: track.id)
                } label: {
                    Text("Delete")
                        .font(.headline)
                        .frame(width: pillWidth, height: pillHeight)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.2))
                        )
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            VStack(spacing: 20) {
                HStack(spacing: 40) {
                    Button {
                        controller.convertAudio(trackId: track.id, modelId: 1304810)
                    } label: {
                        Text("Violin")
                            .font(.headline)
                            .frame(width: pillWidth, height: pillHeight)
                            .background(
                                Capsule()
                                    .fill(controller
                                        .getTrack(id: track.id).convertedModelId == 1304810
                                          ? Color.yellow.opacity(0.2)
                                          : Color.gray.opacity(0.2)
                                    )
                            )
                            .foregroundColor(.blue)
                    }
                    Button {
                        controller.convertAudio(trackId: track.id, modelId: 1331486)
                    } label: {
                        Text("Electric Guitar")
                            .font(.headline)
                            .frame(width: pillWidth, height: pillHeight)
                            .background(
                                Capsule()
                                    .fill(controller
                                        .getTrack(id: track.id).convertedModelId == 1331486
                                          ? Color.yellow.opacity(0.2)
                                          : Color.gray.opacity(0.2)
                                    )
                            )
                            .foregroundColor(.blue)
                    }
                    Button {
                        controller.convertAudio(trackId: track.id, modelId: 1331492)
                    } label: {
                        Text("Flute")
                            .font(.headline)
                            .frame(width: pillWidth, height: pillHeight)
                            .background(
                                Capsule()
                                    .fill(controller
                                        .getTrack(id: track.id).convertedModelId == 1331492
                                          ? Color.yellow.opacity(0.2)
                                          : Color.gray.opacity(0.2)
                                    )
                            )
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                
                HStack(spacing: 40) {
                    Button {
                        controller.convertAudio(trackId: track.id, modelId: 1304790)
                    } label: {
                        Text("Metal Guitar")
                            .font(.headline)
                            .frame(width: pillWidth, height: pillHeight)
                            .background(
                                Capsule()
                                    .fill(controller
                                        .getTrack(id: track.id).convertedModelId == 1304790
                                          ? Color.yellow.opacity(0.2)
                                          : Color.gray.opacity(0.2)
                                    )
                            )
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    MainPage()
}
