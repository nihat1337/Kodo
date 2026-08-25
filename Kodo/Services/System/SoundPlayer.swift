//
//  SoundPlayer.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import AudioToolbox

struct SoundPlayer {

    private let scanSoundID: SystemSoundID = 1057

    func playScanSound() {
        AudioServicesPlaySystemSound(scanSoundID)
    }
}
