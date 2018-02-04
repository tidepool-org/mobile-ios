//
//  ToolSettings.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

import Foundation
import CoreBluetooth

let TRANSFER_SERVICE_UUID = "2664a7bd-2d22-4f07-af86-0ecea8db7b9b"
let TRANSFER_CHARACTERISTIC_UUID = "037b43da-cd53-44c0-9807-7c1621fc6375"

let NOTIFY_MTU = 20

let transferServiceUUID = CBUUID(string: TRANSFER_SERVICE_UUID)
let transferCharacteristicUUID = CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)

// simulate a new BG sample every 5 minutes...
let kBGSampleSpacingSeconds: TimeInterval = 5.0 * 60.0
// for testing, just use 20 seconds!
//let kBGSampleSpacingSeconds: TimeInterval = 5.0 * 4.0

class ToolUserDefaults {
    static let sharedInstance = ToolUserDefaults()

    var bgMinValue: ToolIntSetting
    var bgMaxValue: ToolIntSetting
    
    init() {
        self.bgMinValue = ToolIntSetting(key: "kBgMinValueKey", defaultValue: 50)
        self.bgMaxValue = ToolIntSetting(key: "kBgMaxValueKey", defaultValue: 200)
    }
}


// Simple class for handling Int user default settings
class ToolIntSetting {
    private var _intValue: Int? = nil
    private var settingKey: String
    private var defaultSetting: Int
    private let defaults = UserDefaults.standard
    
    init(key: String, defaultValue: Int) {
        self.settingKey = key
        self.defaultSetting = defaultValue
    }
    
    var intValue: Int {
        set(newValue) {
            defaults.set(newValue, forKey: settingKey)
            _intValue = nil
        }
        get {
            if _intValue == nil {
                let intValue = defaults.object(forKey: settingKey)
                if let intValue = intValue as? Int {
                    _intValue = intValue
                } else {
                    _intValue = defaultSetting
                }
            }
            return _intValue!
        }
    }
}
