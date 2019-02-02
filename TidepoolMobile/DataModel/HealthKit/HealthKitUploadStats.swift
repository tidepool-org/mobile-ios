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
import CocoaLumberjack
import CryptoSwift

class HealthKitUploadStats: NSObject {
    init(type: HealthKitUploadType, mode: HealthKitUploadReader.Mode) {
        DDLogVerbose("trace")
        
        self.uploadType = type
        self.uploadTypeName = type.typeName
        self.mode = mode
        
        super.init()

        self.load()
    }

    fileprivate(set) var uploadType: HealthKitUploadType
    fileprivate(set) var uploadTypeName: String
    fileprivate(set) var mode: HealthKitUploadReader.Mode

    fileprivate(set) var hasSuccessfullyUploaded = false
    fileprivate(set) var lastUploadAttemptTime = Date.distantPast
    fileprivate(set) var lastUploadAttemptSampleCount = 0
    fileprivate(set) var lastSuccessfulUploadTime = Date.distantPast
    
    fileprivate(set) var lastSuccessfulUploadEarliestSampleTime = Date.distantPast
    fileprivate(set) var lastSuccessfulUploadLatestSampleTime = Date.distantPast
    
    fileprivate(set) var totalDaysHistorical = 0
    fileprivate(set) var currentDayHistorical = 0
    fileprivate(set) var startDateHistoricalSamples = Date.distantPast
    fileprivate(set) var endDateHistoricalSamples = Date.distantPast

    func resetPersistentState() {
        DDLogVerbose("trace")

        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalUploadCountKey))

        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsStartDateHistoricalSamplesKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsEndDateHistoricalSamplesKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalDaysHistoricalSamplesKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsCurrentDayHistoricalKey))
        
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptSampleCountKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptEarliestSampleTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptLatestSampleTimeKey))
        
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadEarliestSampleTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadLatestSampleTimeKey))
        
        UserDefaults.standard.synchronize()
        
        self.load()
    }

    func updateForUploadAttempt(sampleCount: Int, uploadAttemptTime: Date, earliestSampleTime: Date, latestSampleTime: Date) {
        DDLogInfo("Attempting to upload: \(sampleCount) samples, at: \(uploadAttemptTime), with earliest sample time: \(earliestSampleTime), with latest sample time: \(latestSampleTime), mode: \(self.mode), type: \(self.uploadTypeName)")
        
        self.lastUploadAttemptTime = uploadAttemptTime
        self.lastUploadAttemptSampleCount = sampleCount
        
        guard sampleCount > 0 else {
            DDLogInfo("Upload with zero samples (deletes only)")
            return
        }
        
        self.lastUploadAttemptEarliestSampleTime = earliestSampleTime
        UserDefaults.standard.set(self.lastUploadAttemptEarliestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptEarliestSampleTimeKey))

        self.lastUploadAttemptLatestSampleTime = latestSampleTime
        UserDefaults.standard.set(self.lastUploadAttemptLatestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptLatestSampleTimeKey))
        
        UserDefaults.standard.set(self.lastUploadAttemptTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptTimeKey))
        UserDefaults.standard.set(self.lastUploadAttemptSampleCount, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptSampleCountKey))
        
        UserDefaults.standard.synchronize()
        
        let uploadInfo : Dictionary<String, Any> = [
            "type" : self.uploadTypeName,
            "mode" : self.mode
        ]

        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: self.mode, userInfo: uploadInfo))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.AttemptUpload), object: self.mode, userInfo: uploadInfo))
        }
    }
    
    func updateForSuccessfulUpload(lastSuccessfulUploadTime: Date) {
        DDLogVerbose("trace")
        
        guard self.lastUploadAttemptSampleCount > 0 else {
            DDLogInfo("Skip update for delete only uploads, date range unknown")
            return
        }
        
        self.totalUploadCount += self.lastUploadAttemptSampleCount
        self.hasSuccessfullyUploaded = self.totalUploadCount > 0
        self.lastSuccessfulUploadTime = lastSuccessfulUploadTime

        self.lastSuccessfulUploadEarliestSampleTime = self.lastUploadAttemptEarliestSampleTime
        UserDefaults.standard.set(self.lastSuccessfulUploadEarliestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadEarliestSampleTimeKey))

        self.lastSuccessfulUploadLatestSampleTime = self.lastUploadAttemptLatestSampleTime
        UserDefaults.standard.set(self.lastSuccessfulUploadLatestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadLatestSampleTimeKey))

        if self.mode != HealthKitUploadReader.Mode.Current {
            if self.totalDaysHistorical > 0 {
                self.currentDayHistorical = self.startDateHistoricalSamples.differenceInDays(self.lastSuccessfulUploadLatestSampleTime)
            }
            UserDefaults.standard.set(self.currentDayHistorical, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsCurrentDayHistoricalKey))
        }
        
        UserDefaults.standard.set(self.lastSuccessfulUploadTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadTimeKey))
        UserDefaults.standard.set(self.totalUploadCount, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalUploadCountKey))
        UserDefaults.standard.synchronize()
        
        let message = "Successfully uploaded \(self.lastUploadAttemptSampleCount) samples, upload time: \(lastSuccessfulUploadTime), earliest sample date: \(self.lastSuccessfulUploadEarliestSampleTime), latest sample date: \(self.lastSuccessfulUploadLatestSampleTime), mode: \(self.mode), type: \(self.uploadTypeName). "
        DDLogInfo(message)
        UIApplication.localNotifyMessage(message)
        if self.totalDaysHistorical > 0 {
            DDLogInfo("Uploaded \(self.currentDayHistorical) of \(self.totalDaysHistorical) days of historical data")
        }

        let uploadInfo : Dictionary<String, Any> = [
            "type" : self.uploadTypeName,
            "mode" : self.mode
        ]

        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: self.mode, userInfo: uploadInfo))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.UploadSuccessful), object: self.mode, userInfo: uploadInfo))
        }
    }

    func updateHistoricalSamplesDateRangeFromHealthKitAsync() {
        DDLogVerbose("trace")
        
        let sampleType = uploadType.hkSampleType()!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {
            (error: NSError?, startDate: Date?, endDate: Date?) in
            
            if error != nil {
                DDLogError("Failed to update historical samples date range, error: \(String(describing: error))")
            } else if let startDate = startDate {
                self.startDateHistoricalSamples = startDate
                
                let endDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.UploadQueryEndDateKey)) as? Date ?? Date()
                self.endDateHistoricalSamples = endDate
                self.totalDaysHistorical = self.startDateHistoricalSamples.differenceInDays(self.endDateHistoricalSamples) + 1
                
                UserDefaults.standard.set(self.startDateHistoricalSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsStartDateHistoricalSamplesKey))
                UserDefaults.standard.set(self.endDateHistoricalSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsEndDateHistoricalSamplesKey))
                UserDefaults.standard.set(self.totalDaysHistorical, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalDaysHistoricalSamplesKey))
                UserDefaults.standard.synchronize()
                
                DDLogInfo("Updated historical samples date range, start date:\(startDate), end date: \(endDate)")
            }
        }
    }

    func updateHistoricalSamplesDateRange(startDate: Date, endDate: Date) {
        self.startDateHistoricalSamples = startDate
        self.endDateHistoricalSamples = endDate
        self.totalDaysHistorical = self.startDateHistoricalSamples.differenceInDays(self.endDateHistoricalSamples)
        
        UserDefaults.standard.set(self.startDateHistoricalSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsStartDateHistoricalSamplesKey))
        UserDefaults.standard.set(self.endDateHistoricalSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsEndDateHistoricalSamplesKey))
        UserDefaults.standard.set(self.totalDaysHistorical, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalDaysHistoricalSamplesKey))
        UserDefaults.standard.synchronize()
    }
 
    // MARK: Private
    
    fileprivate func load(_ resetUser: Bool = false) {
        DDLogVerbose("trace")
        
        let statsExist = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalUploadCountKey)) != nil
        if statsExist {
            let lastSuccessfulUploadTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadTimeKey)) as? Date
            self.lastSuccessfulUploadTime = lastSuccessfulUploadTime ?? Date.distantPast

            let lastSuccessfulUploadLatestSampleTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastSuccessfulUploadLatestSampleTimeKey)) as? Date
            self.lastSuccessfulUploadLatestSampleTime = lastSuccessfulUploadLatestSampleTime ?? Date.distantPast

            self.totalUploadCount = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalUploadCountKey))
            
            let lastUploadAttemptTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptTimeKey)) as? Date
            self.lastUploadAttemptTime = lastUploadAttemptTime ?? Date.distantPast
            
            let lastUploadAttemptEarliestSampleTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptEarliestSampleTimeKey)) as? Date
            self.lastUploadAttemptEarliestSampleTime = lastUploadAttemptEarliestSampleTime ?? Date.distantPast

            let lastUploadAttemptLatestSampleTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptLatestSampleTimeKey)) as? Date
            self.lastUploadAttemptLatestSampleTime = lastUploadAttemptLatestSampleTime ?? Date.distantPast

            self.lastUploadAttemptSampleCount = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsLastUploadAttemptSampleCountKey))
        } else {
            self.lastSuccessfulUploadTime = Date.distantPast
            self.lastSuccessfulUploadLatestSampleTime = Date.distantPast
            self.totalUploadCount = 0

            self.lastUploadAttemptTime = Date.distantPast
            self.lastUploadAttemptEarliestSampleTime = Date.distantPast
            self.lastUploadAttemptLatestSampleTime = Date.distantPast
            self.lastUploadAttemptSampleCount = 0
        }

        if let startDateHistoricalSamplesObject = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsStartDateHistoricalSamplesKey)),
            let endDateHistoricalSamplesObject = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsEndDateHistoricalSamplesKey))
        {
            self.totalDaysHistorical = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsTotalDaysHistoricalSamplesKey))
            self.currentDayHistorical = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadTypeName, key: HealthKitSettings.StatsCurrentDayHistoricalKey))
            self.startDateHistoricalSamples = startDateHistoricalSamplesObject as? Date ?? Date.distantPast
            self.endDateHistoricalSamples = endDateHistoricalSamplesObject as? Date ?? Date.distantPast
        } else {
            self.totalDaysHistorical = 0
            self.currentDayHistorical = 0
            self.startDateHistoricalSamples = Date.distantPast
            self.endDateHistoricalSamples = Date.distantPast
        }

        self.hasSuccessfullyUploaded = self.totalUploadCount > 0
    }
    
    fileprivate var totalUploadCount = 0
    fileprivate var lastUploadAttemptEarliestSampleTime = Date.distantPast
    fileprivate var lastUploadAttemptLatestSampleTime = Date.distantPast    
}
