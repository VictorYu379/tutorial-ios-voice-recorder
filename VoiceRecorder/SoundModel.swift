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
        SoundModel(name: "Electric Guitar", id: 1331486),
        SoundModel(name: "Flute", id: 1331492),
        SoundModel(name: "Metal Guitar", id: 1304790),
        SoundModel(name: "Cello", id: 201084),
        SoundModel(name: "Saxophone", id: 1312985),
        
        // Synths Section
        SoundModel(name: "─── 🎹 SYNTHS ───", id: -2, isSeparator: true),
        SoundModel(name: "Classic Synth", id: 1815802),
        SoundModel(name: "Toy Synth", id: 1658342),
        SoundModel(name: "Saw Lead", id: 1304813),
        SoundModel(name: "Hypersaw Lead", id: 1312973),
        SoundModel(name: "Sine Wave", id: 1331494),
        SoundModel(name: "Square Wave", id: 1312995),
        
        // Drums Section
        SoundModel(name: "─── 🥁 DRUMS ───", id: -3, isSeparator: true),
        SoundModel(name: "Acoustic Kit", id: 2000001),
        SoundModel(name: "Electronic Kit", id: 2000002),
        SoundModel(name: "Hip Hop Kit", id: 2000003),
        SoundModel(name: "Rock Kit", id: 2000004),
        SoundModel(name: "Jazz Kit", id: 2000005),
        SoundModel(name: "Trap Kit", id: 2000006)
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
