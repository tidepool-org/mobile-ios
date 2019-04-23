//
//  HKSettingString.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKSettingString: HKSettingType {
    init(key: String) {
        super.init(key)
    }
    
    var value: String? {
        set(newValue) {
            defaults.set(newValue, forKey: self.settingKey)
            _stringValue = nil
        }
        get {
            if _stringValue == nil {
                _stringValue = defaults.string(forKey: self.settingKey)
            }
            return _stringValue
        }
    }

    override func reset() {
        _stringValue = nil
        removeSetting()
    }

    private var _stringValue: String?
}
