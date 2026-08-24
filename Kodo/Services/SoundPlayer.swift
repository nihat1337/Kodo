//
//  SoundPlayer.swift
//  Kodo
//
//  Created by Nihat Samadov on 16.08.26.
//

import AudioToolbox

struct SoundPlayer {

    /// 1057 is the short system "Tink", the closest built in sound to a scanner beep.
    private let scanSoundID: SystemSoundID = 1057

    func playScanSound() {
        AudioServicesPlaySystemSound(scanSoundID)
    }
}
