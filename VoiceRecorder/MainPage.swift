//
//  NewMainPage.swift
//  VoiceRecorder
//
//  Created by Victor Yu on 5/2/25.
//  Copyright © 2025 Vasiliy Lada. All rights reserved.
//

import SwiftUI

struct MainPage: View {
    let project: ProjectInfo?
    @StateObject private var controller: MainPageController
    @Environment(\.dismiss) private var dismiss
    
    init(project: ProjectInfo) {
        self.project = project
        self._controller = StateObject(wrappedValue: MainPageController(project: project))
    }
    
    var body: some View {
        ZStack {
            VStack {
                // Top Controls
                HStack {
                    // Custom Back Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 25, weight: .semibold))
                        // .foregroundColor(.blue)
                    }

                    Spacer()

                    Button(action: {
                        print("Metronome button tapped")
                        controller.getVoiceModel()
                    }) {
                        Image(systemName: "metronome")
                            .font(.system(size: 30))
                    }
                    .disabled(true)
                    
                    Button(action: {
                        print("Settings button tapped")
                        controller.showSyncSettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 30))
                    }
                    .disabled(controller.state == .recording)
                }
                .frame(maxHeight: 60)
                .padding()
                
                VStack{
                    TrackView(track: controller.getTrack(id: 1), focused: $controller.focusedTrack, controller: controller).padding(.bottom, 20)
                    TrackView(track: controller.getTrack(id: 2), focused: $controller.focusedTrack, controller: controller).padding(.bottom, 20)
                    TrackView(track: controller.getTrack(id: 3), focused: $controller.focusedTrack, controller: controller).padding(.bottom, 20)
                }
                .padding(.vertical)
                
                // Progress Bar
                AudioProgressBar(
                    currentTime: $controller.currentTime,
                    totalDuration: controller.totalDuration,
                    onStartSeeking: {
                        controller.pausePlaybackIfNeeded()
                    },
                    onEndSeeking: { time in
                        controller.seekToTime(time)
                    }
                )
                .disabled(controller.shouldDisablePlaybackButtons())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Spacer()
                
                // Bottom Controls
                HStack {
                    Spacer()
                    
                    let track = controller.getTrack(id: controller.focusedTrack)
                    
                    Button(action: {
                        print("play/pause button tapped")
                        controller.togglePlayback()
                    }) {
                        Image(systemName: controller.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .semibold)) // Equivalent to largeTitle
                    }
                    .disabled(controller.shouldDisablePlaybackButtons())
                    
                    Spacer()
                    
                    Button(action: {
                        print("Recorder button tapped")
                        controller.toggleOverdub()
                    }) {
                        Image(systemName: controller.state == .recording ? "stop.fill" : "record.circle")
                            .font(.system(size: 30))
                            .foregroundColor(controller.shouldDisableRecordButtons() ? .gray : .red)
                    }
                    .disabled(controller.shouldDisableRecordButtons())
                    .opacity((controller.shouldDisableRecordButtons()) ? 0.5 : 1.0)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
            }
            .padding(.bottom, 50)
            .padding(.leading, 20)    // Left padding
            .padding(.trailing, 15)   // Right padding
            
            
//             3) attach the sheet here
            .sheet(isPresented: $controller.showPopupMenu) {
                TrackPopupMenuView(track: controller.getTrack(id: controller.focusedTrack))
                    .environmentObject(controller)
                    .presentationDetents([.fraction(0.7), .large])   // exactly half screen
                    .presentationDragIndicator(.visible)      // shows the grab bar
            }

            // Add sync settings sheet
            .sheet(isPresented: $controller.showSyncSettings) {
                SyncSettingsView(
                    syncDelta: $controller.syncDelta,
                    showSyncSettings: $controller.showSyncSettings, 
                    onSyncDeltaChanged: { delta in
                        controller.updateSyncDelta(delta: delta)
                    }
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
            
            // ── Simple Spinner Overlay ──
            if controller.state == .converting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                ProgressView("Converting…")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
    }
}

struct TrackView: View {
    @StateObject var track: Track
    @Binding var focused: Int
    let controller: MainPageController
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Track \(track.id)")
                .font(.headline)
                .padding(.leading)
            
            HStack {
                // Main track content
                RoundedRectangle(cornerRadius: 10)
                    .fill(focused == track.id ? Color(.systemBlue).opacity(0.1) : Color(.systemGray6))
                    .frame(height: 60)
                    .overlay(
                        Group {
                            if track.isMuted {
                                Image(systemName: "speaker.slash.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            } else if track.state == .hasContent {
                                Image(systemName: "waveform.and.mic")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
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
                    .onTapGesture {
                        focused = track.id
                    }
                
                // Three-dot settings button (separate from rectangle)
                Button(action: {
                    print("Settings button tapped for Track \(track.id)")
                    focused = track.id
                    controller.showPopupMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .opacity(controller.shouldDisablePlaybackButtons() ? 0.6 : 1.0)  // Dim entire track when recording
        .allowsHitTesting(!controller.shouldDisablePlaybackButtons())  // Disable all interactions when recording
    }
}

struct SyncSettingsView: View {
    @Binding var syncDelta: Double
    @Binding var showSyncSettings: Bool
    let onSyncDeltaChanged: (Double) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Sync Adjustment")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Adjust the timing between recording and playback to fix sync issues with different audio devices.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                VStack(spacing: 20) {
                    HStack {
                        Text("Recording Earlier")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Recording Later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $syncDelta,
                        in: -1.0...1.0,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                // User finished dragging - seek and resume if needed
                                onSyncDeltaChanged(syncDelta)
                            }
                        }
                    )
                    .accentColor(.blue)
                    
                    HStack {
                        Text("-1.0s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Current: \(String(format: "%.2f", syncDelta))s")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("+1.0s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Negative values: Recording starts earlier")
                    Text("• Positive values: Recording starts later")
                    Text("• Use when overdubbing feels out of sync")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                showSyncSettings = false
            })
        }
    }
}

struct AudioProgressBar: View {
    @Binding var currentTime: Double
    let totalDuration: Double
    let onStartSeeking: () -> Void
    let onEndSeeking: (Double) -> Void
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(totalDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress slider using native Slider
            Slider(
                value: $currentTime,
                in: 0...totalDuration,
                onEditingChanged: { editing in
                    if editing {
                        // User started dragging - pause audio and mark as seeking
                        onStartSeeking()
                    } else {
                        // User finished dragging - seek and resume if needed
                        onEndSeeking(currentTime)
                    }
                }
            )
            .accentColor(.blue)
        }
    }
}

#Preview {
    MainPage(project: ProjectInfo(name: "Test Project"))
}
