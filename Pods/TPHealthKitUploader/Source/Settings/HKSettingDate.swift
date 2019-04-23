//
//  HKSettingDate.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKSettingDate: HKSettingType {
    init(key: String) {
        super.init(key)
    }

    var value: Date? {
        set(newValue) {
            defaults.set(newValue, forKey: self.settingKey)
            _dateValue = nil
        }
        get {
            if _dateValue == nil {
                _dateValue = defaults.object(forKey: self.settingKey) as? Date
            }
            return _dateValue
        }
    }
    
    override func reset() {
        _dateValue = nil
        removeSetting()
    }

    private var _dateValue: Date?
}
