/*
* Copyright (c) 2018, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import HealthKit

class HealthKitUploaderSettings {
    let defaults = UserDefaults.standard
}

class GlobalSettings: HealthKitUploaderSettings {
    static let sharedInstance = GlobalSettings()
    
    enum GlobalSettingKey {
        case interfaceEnabledKey
        case interfaceUserIdKey
        case interfaceUserNameKey
        case hkDataUploadIdKey
        case authorizationRequestedForUploaderSamplesKey
        case lastExecutedUploaderVersionKey
        case hasPresentedSyncUI
    }
    
    func removeSettingForKey(_ key: GlobalSettingKey) {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            defaults.removeObject(forKey: keyName)
            DDLogVerbose("removing setting \(keyName)")
        } else {
            DDLogError("MISSING KEY!")
        }
    }

    func boolForKey(_ key: GlobalSettingKey) -> Bool {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            return defaults.bool(forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
            return false
        }
    }

    func intForKey(_ key: GlobalSettingKey) -> Int {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            return defaults.integer(forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
            return 0
        }
    }

    func stringForKey(_ key: GlobalSettingKey) -> String? {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            return defaults.string(forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
            return nil
        }
    }

    func updateBoolForKey(_ key: GlobalSettingKey, value: Bool) {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            defaults.set(value, forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
        }
    }

    func updateIntForKey(_ key: GlobalSettingKey, value: Int) {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            defaults.set(value, forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
        }
    }

    func updateStringForKey(_ key: GlobalSettingKey, value: String?) {
        if let keyName = GlobalSettings.globalSettingKeyDict[key] {
            defaults.set(value, forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
        }
    }

    static let globalSettingKeyDict: [GlobalSettingKey: String] = [
        .interfaceEnabledKey: "kHealthKitInterfaceEnabledKey",
        .interfaceUserIdKey: "kUserIdForHealthKitInterfaceKey",
        .interfaceUserNameKey: "kUserNameForHealthKitInterfaceKey",
        .hkDataUploadIdKey: "kHKDataUploadIdKey",
        .authorizationRequestedForUploaderSamplesKey: "authorizationRequestedForUploaderSamples",
        .lastExecutedUploaderVersionKey: "LastExecutedUploaderVersionKey",
        .hasPresentedSyncUI: "HasPresentedSyncUI",
        ]
}

class PrefixedSettings: HealthKitUploaderSettings {
    private(set) var uploadTypeName: String
    private(set) var mode: TPUploader.Mode

    init(mode: TPUploader.Mode, type: HealthKitUploadType) {
        DDLogVerbose("\(#function)")
        self.uploadTypeName = type.typeName
        self.mode = mode
    }
    
    enum PrefixedKey {
        // stats
        case uploadCountKey
        case startDateHistoricalSamplesKey
        case endDateHistoricalSamplesKey
        case lastUploadAttemptSampleCountKey
        case lastUploadAttemptTimeKey
        case lastUploadAttemptEarliestSampleTimeKey
        case lastUploadAttemptLatestSampleTimeKey
        case lastSuccessfulUploadTimeKey
        case lastSuccessfulUploadLatestSampleTimeKey
        case lastSuccessfulUploadEarliestSampleTimeKey
        case totalDaysHistoricalSamplesKey
        case currentDayHistoricalKey
        // other
        case hasPendingUploadsKey
        case queryAnchorKey
        case queryAnchorLastKey
        case queryStartDateKey
        case queryEndDateKey
    }
    
    func removeSettingForKey(_ key: PrefixedKey) {
        if let keyName = fullKey(key) {
            defaults.removeObject(forKey: keyName)
            DDLogVerbose("removing setting \(keyName)")
        } else {
            DDLogError("MISSING KEY!")
        }
    }
    
    func objectForKey(_ key: PrefixedKey) -> Any? {
        if let keyName = fullKey(key) {
            return defaults.object(forKey:keyName)
        } else {
            DDLogError("MISSING KEY!")
            return nil
        }
    }
    
    func intForKey(_ key: PrefixedKey) -> Int {
        if let keyName = fullKey(key) {
            return defaults.integer(forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
            return 0
        }
    }

    func boolForKey(_ key: PrefixedKey) -> Bool {
        if let keyName = fullKey(key) {
            return defaults.bool(forKey: keyName)
        } else {
            DDLogError("MISSING KEY!")
            return false
        }
    }

    func dateForKey(_ key: PrefixedKey) -> Date {
        if let keyName = fullKey(key) {
            if let result = defaults.object(forKey:keyName) as? Date {
                return result
            }
        } else {
            DDLogError("MISSING KEY!")
        }
        return Date.distantPast
    }
    
    func dateForKeyIfExists(_ key: PrefixedKey) -> Date? {
        if let keyName = fullKey(key) {
            if let result = defaults.object(forKey:keyName) as? Date {
                return result
            }
         } else {
            DDLogError("MISSING KEY!")
        }
        return nil
    }

    func anchorForKey(_ key: PrefixedKey) -> HKQueryAnchor? {
        var anchor: HKQueryAnchor?
        if let keyName = fullKey(key) {
            if let anchorData = defaults.object(forKey:keyName) {
                do {
                    anchor = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [HKQueryAnchor.self], from: anchorData as! Data) as? HKQueryAnchor
                } catch {
                }
            }
        } else {
            DDLogError("MISSING KEY!")
        }
        return anchor
    }
    
    func updateAnchorForKey(_ key: PrefixedKey, anchor: HKQueryAnchor?) {
        let queryAnchorData = anchor != nil ? NSKeyedArchiver.archivedData(withRootObject: anchor!) : nil
        if let keyName = fullKey(key) {
            defaults.set(queryAnchorData, forKey: keyName)
            DDLogVerbose("updated setting \(keyName)")
        } else {
            DDLogError("MISSING KEY!")
        }
    }
    
    func updateIntSettingForKey(_ key: PrefixedKey, value: Int) {
        if let keyName = fullKey(key) {
            defaults.set(value, forKey: keyName)
            DDLogVerbose("update setting \(keyName) to \(value)")
        } else {
            DDLogError("MISSING KEY!")
        }
    }
    
    func updateBoolSettingForKey(_ key: PrefixedKey, value: Bool) {
        if let keyName = fullKey(key) {
            defaults.set(value, forKey: keyName)
            DDLogVerbose("update setting \(keyName) to \(value)")
        } else {
            DDLogError("MISSING KEY!")
        }
    }

    func updateDateSettingForKey(_ key: PrefixedKey, value: Date) {
        if let keyName = fullKey(key) {
            defaults.set(value, forKey: keyName)
            DDLogVerbose("update setting \(keyName) to \(value)")
        } else {
            DDLogError("MISSING KEY!")
        }
    }
    
    private func fullKey(_ key: PrefixedKey) -> String? {
        if let baseKey = PrefixedSettings.prefixedKeyDict[key] {
            return prefixedKey(baseKey)
        } else {
            return nil
        }
    }
    
    static let prefixedKeyDict: [PrefixedKey: String] = [
        // stats
        .uploadCountKey: "StatsTotalUploadCountKey",
        .startDateHistoricalSamplesKey: "StatsStartDateHistoricalSamplesKey",
        .endDateHistoricalSamplesKey: "StatsEndDateHistoricalSamplesKey",
        .lastUploadAttemptSampleCountKey: "StatsLastUploadAttemptSampleCountKey",
        .lastUploadAttemptTimeKey: "StatsLastUploadAttemptTimeKey",
        .lastUploadAttemptEarliestSampleTimeKey: "StatsLastUploadAttemptEarliestSampleTimeKey",
        .lastUploadAttemptLatestSampleTimeKey: "StatsLastUploadAttemptLatestSampleTimeKey",
        .lastSuccessfulUploadTimeKey: "StatsLastSuccessfulUploadTimeKey",
        .lastSuccessfulUploadLatestSampleTimeKey: "StatsLastSuccessfulUploadLatestSampleTimeKey",
        .lastSuccessfulUploadEarliestSampleTimeKey: "StatsLastSuccessfulUploadEarliestSampleTimeKey",
        .totalDaysHistoricalSamplesKey: "StatsTotalDaysHistoricalSamplesKey",
        .currentDayHistoricalKey: "StatsCurrentDayHistoricalKey",
        // other
        .hasPendingUploadsKey: "HasPendingUploadsKey",
        .queryAnchorKey: "QueryAnchorKey",
        .queryAnchorLastKey: "QueryAnchorLastKey",
        .queryStartDateKey: "QueryStartDateKey",
        .queryEndDateKey: "QueryEndDateKey",
    ]

    func prefixedKey(_ key: String) -> String {
        let result = "\(self.mode)-\(self.uploadTypeName)\(key)"
        return result
    }
}

class StatsSettings: PrefixedSettings {
 
    func resetAllKeys() {
        DDLogVerbose("StatsSettings (\(uploadTypeName), \(mode))")
        for key in allStatKeys {
            removeSettingForKey(key)
        }
    }
    
    private let allStatKeys: [PrefixedKey] = [.uploadCountKey, .startDateHistoricalSamplesKey, .endDateHistoricalSamplesKey, .lastUploadAttemptSampleCountKey, .lastUploadAttemptEarliestSampleTimeKey, .lastUploadAttemptLatestSampleTimeKey, .lastSuccessfulUploadTimeKey, .lastSuccessfulUploadLatestSampleTimeKey, .lastSuccessfulUploadEarliestSampleTimeKey, .totalDaysHistoricalSamplesKey, .currentDayHistoricalKey]
    
}

class UploaderSettings: PrefixedSettings {
    
    func resetAllKeys() {
        DDLogVerbose("UploaderSettings (\(uploadTypeName), \(mode))")
        for key in allUploaderKeys {
            removeSettingForKey(key)
        }
    }
    
    private let allUploaderKeys: [PrefixedKey] = [.queryAnchorKey, .queryAnchorLastKey, .queryStartDateKey, .queryEndDateKey]
    
}

