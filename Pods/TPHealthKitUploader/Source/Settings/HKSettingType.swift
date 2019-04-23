//
//  HKSettingType.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKSettingType {
    let defaults = UserDefaults.standard
    var settingKey: String
    init(_ key: String) {
        self.settingKey = key
    }
    
    func removeSetting() {
        //DDLogVerbose("removeSetting for key: \(settingKey)")
        defaults.removeObject(forKey: settingKey)
    }

    // Override and clear value!
    func reset() {
        DDLogError("Err: must override reset() for key \(settingKey)")
    }
}
