//
//  HKTypeModeSettings.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 4/8/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

class HKTypeModeSettings {

    private(set) var typeName: String
    private(set) var mode: TPUploader.Mode

    // Not persisted... used privately
    var lastUploadAttemptEarliestSampleTime: Date? = nil
    var lastUploadAttemptLatestSampleTime: Date? = nil
    var lastUploadAttemptTime : Date? = nil
    var lastUploadAttemptSampleCount = 0

    // Persistent settings
    var uploadCount: HKSettingInt
    var startDateHistoricalSamples: HKSettingDate
    var endDateHistoricalSamples: HKSettingDate
    var lastSuccessfulUploadTime: HKSettingDate
    var lastSuccessfulUploadLatestSampleTime: HKSettingDate
    var lastSuccessfulUploadEarliestSampleTime: HKSettingDate
    // other
    var queryAnchor: HKSettingAnchor
    var queryStartDate: HKSettingDate
    var queryEndDate: HKSettingDate

    func stats() -> TPUploaderStats {
        DDLogVerbose("HKTypeModeSettings (\(typeName), \(mode))")
        var result = TPUploaderStats(typeName: typeName, mode: mode)
        result.hasSuccessfullyUploaded = self.uploadCount.value > 0
        result.lastSuccessfulUploadTime = self.lastSuccessfulUploadTime.value
        
        var totalDaysHistorical = 0
        var currentDayHistorical = 0
        if mode == .HistoricalAll {
            if let earliestDay = self.startDateHistoricalSamples.value, let latestDay = self.endDateHistoricalSamples.value {
                if earliestDay.compare(Date.distantFuture) != .orderedSame {
                    totalDaysHistorical = earliestDay.differenceInDays(latestDay) + 1
                    if let currentDay = lastSuccessfulUploadEarliestSampleTime.value {
                        currentDayHistorical = currentDay.differenceInDays(latestDay) + 1
                    }
                }
            }
        }
        result.totalDaysHistorical = totalDaysHistorical
        result.currentDayHistorical = currentDayHistorical
        
        result.lastSuccessfulUploadEarliestSampleTime = self.lastSuccessfulUploadEarliestSampleTime.value
        result.lastSuccessfulUploadLatestSampleTime = self.lastSuccessfulUploadLatestSampleTime.value
        result.startDateHistoricalSamples = self.startDateHistoricalSamples.value
        result.endDateHistoricalSamples = self.endDateHistoricalSamples.value
        result.totalUploadCount = self.uploadCount.value
        return result
    }
    
    func resetAllStatsKeys() {
        DDLogVerbose("HKTypeModeSettings (\(typeName), \(mode))")
        for setting in statSettings {
            setting.reset()
        }
    }
    
    func resetAllReaderKeys() {
        DDLogVerbose("HKTypeModeSettings (\(typeName), \(mode))")
        for setting in readerSettings {
            setting.reset()
        }
    }
    
    func resetPersistentState() {
        DDLogVerbose("HKTypeModeSettings: (\(typeName), \(mode.rawValue))")
        resetAllStatsKeys()
        // also reset all the non-persisted info
        resetAttemptStats()
    }

    func resetAttemptStats() {
        DDLogVerbose("HKTypeModeSettings: (\(typeName), \(mode.rawValue))")
        lastUploadAttemptEarliestSampleTime = nil
        lastUploadAttemptLatestSampleTime = nil
        lastUploadAttemptTime = nil
        lastUploadAttemptSampleCount = 0
    }

    func updateForHistoricalSampleRange(startDate: Date, endDate: Date) {
        self.startDateHistoricalSamples.value = startDate
        self.endDateHistoricalSamples.value = endDate
        DDLogInfo("Updated historical samples date range for \(typeName): start date \(startDate), end date \(endDate)")
    }

    func updateForUploadAttempt(sampleCount: Int, uploadAttemptTime: Date, earliestSampleTime: Date, latestSampleTime: Date) {
        DDLogInfo("(\(self.mode),  \(self.typeName)) Prepared samples for upload: \(sampleCount) samples, at: \(uploadAttemptTime), with earliest sample time: \(earliestSampleTime), with latest sample time: \(latestSampleTime)")
        
        self.lastUploadAttemptTime = uploadAttemptTime
        self.lastUploadAttemptSampleCount = sampleCount
        guard sampleCount > 0 else {
            DDLogInfo("Upload with zero samples (deletes only)")
            return
        }
        self.lastUploadAttemptEarliestSampleTime = earliestSampleTime
        self.lastUploadAttemptLatestSampleTime = latestSampleTime
        //postNotifications([TPUploaderNotifications.Updated])
    }

    func updateForSuccessfulUpload(lastSuccessfulUploadTime: Date) {
        DDLogVerbose("HKTypeModeSettings: (\(self.mode),  \(self.typeName))")
        
        guard self.lastUploadAttemptSampleCount > 0 else {
            DDLogInfo("Skip update for reader with no upload samples")
            return
        }
        
        self.uploadCount.value += self.lastUploadAttemptSampleCount
        self.lastSuccessfulUploadTime.value = lastSuccessfulUploadTime
        
        if let lastUploadAttemptEarliestSampleTime = lastUploadAttemptEarliestSampleTime {
            self.lastSuccessfulUploadEarliestSampleTime.value = lastUploadAttemptEarliestSampleTime
        }
        
        if let lastUploadAttemptLatestSampleTime = lastUploadAttemptLatestSampleTime {
            self.lastSuccessfulUploadLatestSampleTime.value = lastUploadAttemptLatestSampleTime
        }
        
        let message = "(\(self.mode),  \(self.typeName)) Successfully uploaded \(self.lastUploadAttemptSampleCount) samples, upload time: \(String(describing: self.lastSuccessfulUploadTime.value)), earliest sample date: \(String(describing: self.lastSuccessfulUploadEarliestSampleTime.value)), latest sample date: \(String(describing: self.lastSuccessfulUploadLatestSampleTime.value))."
        DDLogInfo(message)
        postNotifications([TPUploaderNotifications.Updated, TPUploaderNotifications.UploadSuccessful])
    }

    //
    // MARK: - Private
    //
    
    let defaults = UserDefaults.standard
    
    private var statSettings: [HKSettingType]
    private var readerSettings: [HKSettingType]

    init(mode: TPUploader.Mode, typeName: String) {
        DDLogVerbose("HKTypeModeSettings (\(typeName), \(mode))")
        self.typeName = typeName
        self.mode = mode
        
        func prefixedKey(_ key: String) -> String {
            let result = "\(mode.rawValue)-\(typeName)\(key)"
            return result
        }
        
        self.uploadCount = HKSettingInt(key: prefixedKey("StatsTotalUploadCountKey"))
        self.startDateHistoricalSamples = HKSettingDate(key: prefixedKey("StatsStartDateHistoricalSamplesKey"))
        self.endDateHistoricalSamples = HKSettingDate(key: prefixedKey("StatsEndDateHistoricalSamplesKey"))
        self.lastSuccessfulUploadTime = HKSettingDate(key: prefixedKey("StatsLastSuccessfulUploadTimeKey"))
        self.lastSuccessfulUploadLatestSampleTime = HKSettingDate(key: prefixedKey("StatsLastSuccessfulUploadLatestSampleTimeKey"))
        self.lastSuccessfulUploadEarliestSampleTime = HKSettingDate(key: prefixedKey("StatsLastSuccessfulUploadEarliestSampleTimeKey"))
        // query settings used for anchor query of current samples; queryStartDate is only used for compatibility
        self.queryAnchor = HKSettingAnchor(key: prefixedKey("QueryAnchorKey"))
        self.queryStartDate = HKSettingDate(key: prefixedKey("QueryStartDateKey"))
        self.queryEndDate = HKSettingDate(key: prefixedKey("QueryEndDateKey"))

        statSettings = [
            self.uploadCount,
            self.startDateHistoricalSamples,
            self.endDateHistoricalSamples,
            self.lastSuccessfulUploadTime,
            self.lastSuccessfulUploadLatestSampleTime,
            self.lastSuccessfulUploadEarliestSampleTime,
        ]
        
        readerSettings = [
            self.queryAnchor,
            self.queryStartDate,
            self.queryEndDate]

    }

    private func postNotifications(_ notificationNames: [String]) {
        let uploadInfo : Dictionary<String, Any> = [
            "type" : self.typeName,
            "mode" : self.mode
        ]
        DispatchQueue.main.async {
            for name in notificationNames {
                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: name), object: self.mode, userInfo: uploadInfo))
            }
        }
    }

}
