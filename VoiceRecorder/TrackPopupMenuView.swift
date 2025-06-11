//
//  SlidersMenuView.swift
//  VoiceRecorder
//
//  Created by Victor Yu on 6/10/25.
//  Copyright © 2025 Vasiliy Lada. All rights reserved.
//

import SwiftUI

struct TrackPopupMenuView: View {
    @ObservedObject var track: Track
    @State private var selectedModel: SoundModel = SoundModel.none
    @EnvironmentObject var controller: MainPageController
    @State private var showPicker: Bool = false
    @State private var octaveShift: Int = 0
    
    private let pillWidth: CGFloat = 120
    private let pillHeight: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Track \(track.id)")
                .font(.headline)
                .padding(.top)
            
            // — Volume Slider Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume")
                    .font(.subheadline)
                Slider(
                    value: $track.volume,
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing {
                            track.updateVolume(volume: track.volume)
                        }
                    }
                )
                .disabled(track.isMuted)
                .opacity(track.isMuted ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            
            // — Control Buttons Section
            HStack(spacing: 40) {
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
                
                Button {
                    controller.deleteAudio(id: track.id)
                    controller.showPopupMenu = false
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
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            // — Sound Model Selection
            VStack(alignment: .leading, spacing: 15) {
                // Model Selection Display
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        showPicker = true
                    }) {
                        HStack {
                            Text("Selected model")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedModel.name)
                                .font(.body)
                                .foregroundColor(selectedModel == SoundModel.none ? .gray : .blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .sheet(isPresented: $showPicker) {
                ModelPickerView(
                    selectedModel: $selectedModel,
                    onComplete: {
                        // If a separator is selected when picker closes, reset to "None"
                        if selectedModel.isSeparator {
                            selectedModel = SoundModel.none
                        }
                    }
                )
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.visible)
            }
            
            // — Pitch Shift Slider Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Pitch Shift")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 8) {
                    // Pitch shift slider
                    Slider(
                        value: Binding(
                            get: { Double(octaveShift) },
                            set: { octaveShift = Int($0) }
                        ),
                        in: -2...2,
                        step: 1
                    )
                    .accentColor(.blue)
                    .padding(.horizontal, 20)
                    
                    // Current value display
                    Text("Current: \(octaveShift >= 0 ? "+" : "")\(octaveShift) octave")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            // Convert Button
            Button {
                controller.convertAudio(trackId: track.id, modelId: selectedModel.id, octaveShift: octaveShift)
                controller.showPopupMenu = false
            } label: {
                Text("Convert")
                    .font(.headline)
                    .frame(width: pillWidth, height: pillHeight)
                    .background(
                        Capsule()
                            .fill(controller.shouldDisableConvertButton(model: selectedModel, track: track, octaveShift: octaveShift) ? Color.gray.opacity(0.1) : Color.blue.opacity(0.2))
                    )
                    .foregroundColor(controller.shouldDisableConvertButton(model: selectedModel, track: track, octaveShift: octaveShift) ? .gray : .blue)
            }
            .disabled(controller.shouldDisableConvertButton(model: selectedModel, track: track, octaveShift: octaveShift))
            .padding(.horizontal, 20)
        }
        .background(Color(.systemBackground))
        .opacity(track.state == .empty ? 0.6 : 1.0)
        .allowsHitTesting(track.state != .empty)
        .onAppear {
            selectedModel = SoundModel.model(for: track.convertedModelId)
            octaveShift = track.octaveShift
        }
    }
}

struct ModelPickerView: View {
    @Binding var selectedModel: SoundModel
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Sound Model")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Picker("Sound Model", selection: $selectedModel) {
                    ForEach(SoundModel.allModels, id: \.id) { model in
                        Text(model.name)
                            .font(model.isSeparator ? .caption : .body)
                            .foregroundColor(model.isSeparator ? .secondary : .primary)
                            .tag(model)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 180)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    onComplete()
                    dismiss()
                }
            )
        }
    }
}
