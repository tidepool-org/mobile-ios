//
//  HKSettingAnchor.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import HealthKit

class HKSettingAnchor: HKSettingType {
    init(key: String) {
        super.init(key)
    }

    var value: HKQueryAnchor? {
        set(newValue) {
            let queryAnchorData = newValue != nil ? NSKeyedArchiver.archivedData(withRootObject: newValue!) : nil
            defaults.set(queryAnchorData, forKey: self.settingKey)
            _anchorValue = nil
        }
        get {
            if _anchorValue == nil {
                if let anchorData = defaults.object(forKey: settingKey) {
                    do {
                        _anchorValue = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [HKQueryAnchor.self], from: anchorData as! Data) as? HKQueryAnchor
                    } catch {
                    }
                }
            }
            return _anchorValue
        }
    }
    
    override func reset() {
        _anchorValue = nil
        removeSetting()
    }
    private var _anchorValue: HKQueryAnchor?
}
