//
//  HKSettingBool.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKSettingBool: HKSettingType {

    init(key: String, defaultValue: Bool = false) {
        super.init(key)
        resetValue = defaultValue
    }

    var value: Bool {
        set(newValue) {
            defaults.set(newValue, forKey: self.settingKey)
            _boolValue = nil
        }
        get {
            if _boolValue == nil {
                _boolValue = defaults.bool(forKey: self.settingKey)
            }
            return _boolValue!
        }
    }

    override func reset() {
        //DDLogVerbose("resetting key: \(settingKey)")
        if resetValue == nil {
            removeSetting()
            _boolValue = nil
        } else {
            value = resetValue!
        }
    }
    
    private var _boolValue: Bool?
    private var resetValue: Bool?
    
}
