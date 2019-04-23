//
//  HKGlobalSettings.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKGlobalSettings {
    static let sharedInstance = HKGlobalSettings()

    // Persistent settings
    var interfaceEnabled: HKSettingBool
    var interfaceUserId: HKSettingString
    var interfaceUserName: HKSettingString
    var hkDataUploadId: HKSettingString
    var authorizationRequestedForUploaderSamples: HKSettingBool
    var lastExecutedUploaderVersion: HKSettingInt
    var hasPresentedSyncUI: HKSettingBool
    // global upload...
    var historicalFenceDate: HKSettingDate // same as lastSuccessfulUploadEarliestSampleTime across all types
    var historicalEarliestDate: HKSettingDate
    var hasPendingHistoricalUploads: HKSettingBool
    var currentStartDate: HKSettingDate
    var hasPendingCurrentUploads: HKSettingBool
    var lastSuccessfulCurrentUploadTime: HKSettingDate

    func currentProgress() -> TPUploaderGlobalStats {
        // calculate current global progress from settings
        var totalDaysHistorical = 0
        var currentDayHistorical = 0
        if let earliestDay = self.historicalEarliestDate.value, let latestDay = self.currentStartDate.value {
            totalDaysHistorical = earliestDay.differenceInDays(latestDay) + 1
            if let currentDay = historicalFenceDate.value {
                currentDayHistorical = currentDay.differenceInDays(latestDay) + 1
            }
        }
        DDLogVerbose("HKGlobalSettings lastUpload: \(String(describing: lastSuccessfulCurrentUploadTime.value)), current historical day: \(currentDayHistorical), total historical days: \(totalDaysHistorical)")
        return TPUploaderGlobalStats(lastUpload: lastSuccessfulCurrentUploadTime.value, totalHistDays: totalDaysHistorical, currentHistDay: currentDayHistorical)
    }
    
    func resetHistoricalUploadSettings() {
        DDLogVerbose("HKGlobalSettings")
        for setting in historicalUploadSettings {
            setting.reset()
        }
    }
    
    func resetCurrentUploadSettings() {
        DDLogVerbose("HKGlobalSettings")
        for setting in currentUploadSettings {
            setting.reset()
        }
    }

    func resetAll() {
        DDLogVerbose("HKGlobalSettings")
        for setting in userSettings {
            setting.reset()
        }
        self.resetHistoricalUploadSettings()
        self.resetCurrentUploadSettings()
    }
    
    init() {
        self.interfaceEnabled = HKSettingBool(key: "kHealthKitInterfaceEnabledKey")
        self.interfaceUserId = HKSettingString(key: "kUserIdForHealthKitInterfaceKey")
        self.interfaceUserName = HKSettingString(key: "kUserNameForHealthKitInterfaceKey")
        self.hkDataUploadId = HKSettingString(key: "kHKDataUploadIdKey")
        self.authorizationRequestedForUploaderSamples = HKSettingBool(key: "authorizationRequestedForUploaderSamples")
        self.lastExecutedUploaderVersion = HKSettingInt(key: "LastExecutedUploaderVersionKey")
        self.hasPresentedSyncUI = HKSettingBool(key: "HasPresentedSyncUI")
        // global upload...
        self.historicalFenceDate = HKSettingDate(key: "historicalFenceDateKey")
        self.historicalEarliestDate = HKSettingDate(key: "historicalEarliestDateKey")
        self.hasPendingHistoricalUploads = HKSettingBool(key: "hasPendingHistoricalUploadsKey")
        self.currentStartDate = HKSettingDate(key: "currentStartDateKey")
        self.hasPendingCurrentUploads = HKSettingBool(key: "hasPendingCurrentUploadsKey")
        self.lastSuccessfulCurrentUploadTime = HKSettingDate(key: "lastSuccessfulCurrentUploadTime")

        // for global reset
        self.userSettings = [
            self.interfaceEnabled,
            self.interfaceUserId,
            self.interfaceUserName,
            self.hkDataUploadId,
            self.authorizationRequestedForUploaderSamples,
            self.lastExecutedUploaderVersion,
            self.hasPresentedSyncUI,
        ]
        self.historicalUploadSettings = [
            self.historicalFenceDate,
            self.historicalEarliestDate,
            self.hasPendingHistoricalUploads
        ]
        self.currentUploadSettings = [
            self.currentStartDate,
            self.hasPendingCurrentUploads,
            self.lastSuccessfulCurrentUploadTime,
        ]

    }
    
    private var userSettings: [HKSettingType]
    private var historicalUploadSettings: [HKSettingType]
    private var currentUploadSettings: [HKSettingType]
}
