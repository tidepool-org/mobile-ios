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

class HealthKitUploadStats: NSObject {
    
    init(type: HealthKitUploadType, mode: TPUploader.Mode) {
        DDLogVerbose("\(#function)")
        self.stats = TPUploaderStats(typeName: type.typeName, mode: mode)
        self.uploadType = type
        self.uploadTypeName = type.typeName
        self.mode = mode
        self.statSettings = StatsSettings(mode: mode, type: type)
        super.init()
        self.load()
    }

    private(set) var stats: TPUploaderStats
    private let statSettings: StatsSettings
    
    private(set) var uploadType: HealthKitUploadType
    private(set) var uploadTypeName: String
    private(set) var mode: TPUploader.Mode
    
    func resetPersistentState() {
        DDLogVerbose("HealthKitUploadStats:\(#function) type: \(uploadType.typeName), mode: \(mode.rawValue)")

        statSettings.resetAllKeys()
        self.stats = TPUploaderStats(typeName: uploadTypeName, mode: mode)
        self.load()
    }

    func updateForUploadAttempt(sampleCount: Int, uploadAttemptTime: Date, earliestSampleTime: Date, latestSampleTime: Date) {
        DDLogInfo("Attempting to upload: \(sampleCount) samples, at: \(uploadAttemptTime), with earliest sample time: \(earliestSampleTime), with latest sample time: \(latestSampleTime), mode: \(self.mode), type: \(self.uploadTypeName)")
        
        self.stats.lastUploadAttemptTime = uploadAttemptTime
        statSettings.updateDateSettingForKey(.lastUploadAttemptTimeKey, value: uploadAttemptTime)

        self.stats.lastUploadAttemptSampleCount = sampleCount
        statSettings.updateIntSettingForKey(.lastUploadAttemptSampleCountKey, value: sampleCount)

        guard sampleCount > 0 else {
            DDLogInfo("Upload with zero samples (deletes only)")
            return
        }
        
        self.stats.lastUploadAttemptEarliestSampleTime = earliestSampleTime
        statSettings.updateDateSettingForKey(.lastUploadAttemptEarliestSampleTimeKey, value: earliestSampleTime)

        self.stats.lastUploadAttemptLatestSampleTime = latestSampleTime
        statSettings.updateDateSettingForKey(.lastUploadAttemptLatestSampleTimeKey, value: latestSampleTime)

        postNotifications([TPUploaderNotifications.Updated])
    }
    
    private func postNotifications(_ notificationNames: [String]) {
        let uploadInfo : Dictionary<String, Any> = [
            "type" : self.uploadTypeName,
            "mode" : self.mode
        ]
        DispatchQueue.main.async {
            for name in notificationNames {
                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: name), object: self.mode, userInfo: uploadInfo))
            }
        }
    }
    
    func updateHistoricalStatsForEndState() {
        // call when upload finishes because no more data has been found. This simply moves the curret day pointer to the end...
        self.stats.currentDayHistorical = self.stats.totalDaysHistorical
        statSettings.updateIntSettingForKey(.currentDayHistoricalKey, value: self.stats.currentDayHistorical)
    }
    
    func updateForSuccessfulUpload(lastSuccessfulUploadTime: Date) {
        DDLogVerbose("\(#function)")
        
        guard self.stats.lastUploadAttemptSampleCount > 0 else {
            DDLogInfo("Skip update for delete only uploads, date range unknown")
            return
        }
        
        self.stats.totalUploadCount += self.stats.lastUploadAttemptSampleCount
        self.stats.hasSuccessfullyUploaded = self.stats.totalUploadCount > 0
        self.stats.lastSuccessfulUploadTime = lastSuccessfulUploadTime

        self.stats.lastSuccessfulUploadEarliestSampleTime = self.stats.lastUploadAttemptEarliestSampleTime
        statSettings.updateDateSettingForKey(.lastSuccessfulUploadEarliestSampleTimeKey, value: self.stats.lastSuccessfulUploadEarliestSampleTime)

        self.stats.lastSuccessfulUploadLatestSampleTime = self.stats.lastUploadAttemptLatestSampleTime
        statSettings.updateDateSettingForKey(.lastSuccessfulUploadLatestSampleTimeKey, value: self.stats.lastSuccessfulUploadLatestSampleTime)

        if self.mode != TPUploader.Mode.Current {
            if self.stats.totalDaysHistorical > 0 {
                self.stats.currentDayHistorical = self.stats.startDateHistoricalSamples.differenceInDays(self.stats.lastSuccessfulUploadLatestSampleTime)
            }
            statSettings.updateIntSettingForKey(.currentDayHistoricalKey, value: self.stats.currentDayHistorical)
        }
        
        statSettings.updateDateSettingForKey(.lastSuccessfulUploadTimeKey, value: self.stats.lastSuccessfulUploadTime)
        statSettings.updateIntSettingForKey(.uploadCountKey, value: self.stats.totalUploadCount)
        
        let message = "Successfully uploaded \(self.stats.lastUploadAttemptSampleCount) samples, upload time: \(lastSuccessfulUploadTime), earliest sample date: \(self.stats.lastSuccessfulUploadEarliestSampleTime), latest sample date: \(self.stats.lastSuccessfulUploadLatestSampleTime), (\(self.mode), \(self.uploadTypeName)). "
        DDLogInfo(message)
        if self.stats.totalDaysHistorical > 0 {
            DDLogInfo("Uploaded \(self.stats.currentDayHistorical) of \(self.stats.totalDaysHistorical) days of historical data")
        }

        postNotifications([TPUploaderNotifications.Updated, TPUploaderNotifications.UploadSuccessful])
    }

    func updateHistoricalSamplesDateRangeFromHealthKitAsync() {
        DDLogVerbose("\(#function)")
        
        let sampleType = uploadType.hkSampleType()!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {
            (error: NSError?, startDate: Date?, endDate: Date?) in
            
            if error != nil {
                DDLogError("Failed to update historical samples date range, error: \(String(describing: error))")
            } else if let startDate = startDate {
                self.stats.startDateHistoricalSamples = startDate
                self.statSettings.updateDateSettingForKey(.startDateHistoricalSamplesKey, value: startDate)
                let endDate = self.statSettings.dateForKeyIfExists(.queryEndDateKey) ?? Date()
                self.stats.endDateHistoricalSamples = endDate
                self.statSettings.updateDateSettingForKey(.endDateHistoricalSamplesKey, value: endDate)
                
                self.stats.totalDaysHistorical = self.stats.startDateHistoricalSamples.differenceInDays(self.stats.endDateHistoricalSamples) + 1
                self.statSettings.updateIntSettingForKey(.totalDaysHistoricalSamplesKey, value: self.stats.totalDaysHistorical)
              
                DDLogInfo("Updated historical samples date range, start date:\(startDate), end date: \(endDate)")
            }
        }
    }
 
    // MARK: Private
    
    fileprivate func load(_ resetUser: Bool = false) {
        DDLogVerbose("\(#function)")
        
        let statsExist = statSettings.objectForKey(.uploadCountKey) != nil
        if statsExist {
            self.stats.lastSuccessfulUploadTime = statSettings.dateForKey(.lastSuccessfulUploadTimeKey)
            self.stats.lastSuccessfulUploadLatestSampleTime = statSettings.dateForKey(.lastSuccessfulUploadLatestSampleTimeKey)
            self.stats.totalUploadCount = statSettings.intForKey(.uploadCountKey)
            self.stats.lastUploadAttemptTime = statSettings.dateForKey(.lastUploadAttemptTimeKey)
            self.stats.lastUploadAttemptEarliestSampleTime = statSettings.dateForKey(.lastUploadAttemptEarliestSampleTimeKey)
            self.stats.lastUploadAttemptLatestSampleTime = statSettings.dateForKey(.lastUploadAttemptLatestSampleTimeKey)
            self.stats.lastUploadAttemptSampleCount = statSettings.intForKey(.lastUploadAttemptSampleCountKey)
        } else {
            self.stats.lastSuccessfulUploadTime = Date.distantPast
            self.stats.lastSuccessfulUploadLatestSampleTime = Date.distantPast
            self.stats.totalUploadCount = 0

            self.stats.lastUploadAttemptTime = Date.distantPast
            self.stats.lastUploadAttemptEarliestSampleTime = Date.distantPast
            self.stats.lastUploadAttemptLatestSampleTime = Date.distantPast
            self.stats.lastUploadAttemptSampleCount = 0
        }

        if let startDateHistoricalSamplesObject = statSettings.objectForKey(.startDateHistoricalSamplesKey),
            let endDateHistoricalSamplesObject = statSettings.objectForKey(.endDateHistoricalSamplesKey)
        {
            self.stats.totalDaysHistorical = statSettings.intForKey(.totalDaysHistoricalSamplesKey)
            self.stats.currentDayHistorical = statSettings.intForKey(.currentDayHistoricalKey)
            self.stats.startDateHistoricalSamples = startDateHistoricalSamplesObject as? Date ?? Date.distantPast
            self.stats.endDateHistoricalSamples = endDateHistoricalSamplesObject as? Date ?? Date.distantPast
        } else {
            self.stats.totalDaysHistorical = 0
            self.stats.currentDayHistorical = 0
            self.stats.startDateHistoricalSamples = Date.distantPast
            self.stats.endDateHistoricalSamples = Date.distantPast
        }

        self.stats.hasSuccessfullyUploaded = self.stats.totalUploadCount > 0
    }
}
