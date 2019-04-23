//
//  HKSettingInt.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKSettingInt: HKSettingType {
   
    init(key: String, defaultValue: Int = 0) {
        super.init(key)
        resetValue = defaultValue
    }

    var value: Int {
        set(newValue) {
            defaults.set(newValue, forKey: self.settingKey)
            _intValue = nil
            //DDLogVerbose("set \(settingKey) to \(newValue)")
        }
        get {
            if _intValue == nil {
                _intValue = defaults.integer(forKey: self.settingKey)
            }
            //DDLogVerbose("returning \(_intValue!) for \(settingKey)")
            return _intValue!
        }
    }
    
    override func reset() {
        //DDLogVerbose("resetting key: \(settingKey)")
        if resetValue == nil {
            removeSetting()
            _intValue = nil
        } else {
            value = resetValue!
        }
    }

    private var _intValue: Int?
    private var resetValue: Int?

}
