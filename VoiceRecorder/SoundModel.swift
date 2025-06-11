//
//  SoundModel.swift
//  VoiceRecorder
//
//  Created by Victor Yu on 6/10/25.
//  Copyright © 2025 Vasiliy Lada. All rights reserved.
//

import Foundation

struct SoundModel: Hashable, Identifiable {
    let name: String
    let id: Int
    let isSeparator: Bool
    
    private init(name: String, id: Int, isSeparator: Bool = false) {
        self.name = name
        self.id = id
        self.isSeparator = isSeparator
    }
    
    static let allModels: [SoundModel] = [
        // Instruments Section
        SoundModel(name: "─── 🎼 INSTRUMENTS ───", id: -1, isSeparator: true),
        SoundModel(name: "Violin", id: 1304810),
        SoundModel(name: "Accoustic Guitar", id: 1331644),
        SoundModel(name: "Electric Guitar", id: 1331486),
        SoundModel(name: "Flute", id: 1331492),
        SoundModel(name: "Metal Guitar", id: 1304790),
        SoundModel(name: "Cello", id: 201084),
        SoundModel(name: "Saxophone", id: 1312985),
        SoundModel(name: "Trombone", id: 1667093),
        SoundModel(name: "Vibraphone", id: 1645481),
        SoundModel(name: "Funky Talk Box", id: 1574304),
        SoundModel(name: "Oboe", id: 1331640),
        SoundModel(name: "Trumpet", id: 1331480),
        SoundModel(name: "Clarinet", id: 1312991),

        // Drums Section
        SoundModel(name: "─── 🥁 DRUMS ───", id: -3, isSeparator: true),
        SoundModel(name: "80's Dance Drum Machine", id: 1602174),
        SoundModel(name: "80's Drum Machine", id: 1563738),
        SoundModel(name: "Gritty Tape Drums", id: 212569),
        
        // Synths Section
        SoundModel(name: "─── 🎹 SYNTHS ───", id: -2, isSeparator: true),
        SoundModel(name: "Classic Synth", id: 1815802),
        SoundModel(name: "80's Synth", id: 1689141),
        SoundModel(name: "New Age Lead", id: 1331645),
        SoundModel(name: "Synth Choir", id: 1331641),
        SoundModel(name: "Trance Lead", id: 1331632),
        SoundModel(name: "Toy Synth", id: 1658342),
        SoundModel(name: "Saw Lead", id: 1304813),
        SoundModel(name: "Hypersaw Lead", id: 1312973),
        SoundModel(name: "Sine Wave", id: 1331494),
        SoundModel(name: "Square Wave", id: 1312995),
        SoundModel(name: "8-bit Lead", id: 1331487),
    ]
    
    // Dictionary indexed by ID for fast lookups
    private static let modelsById: [Int: SoundModel] = {
        var dict: [Int: SoundModel] = [:]
        for model in allModels {
            dict[model.id] = model
        }
        return dict
    }()
    
    // Special "None" model for when no model is selected
    static let none = SoundModel(name: "None", id: 0)
    
    // Helper to get model by ID (returns None if not found OR if it's a separator)
    static func model(for id: Int?) -> SoundModel {
        guard let id = id, 
              let model = modelsById[id], 
              !model.isSeparator else {
            return SoundModel.none
        }
        return model
    }
}
