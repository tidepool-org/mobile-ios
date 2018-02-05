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

class HealthKitBloodGlucoseUploadStats: NSObject {
    init(mode: HealthKitBloodGlucoseUploadReader.Mode) {
        DDLogVerbose("trace")
        
        self.mode = mode
        
        super.init()

        self.load()
    }

    fileprivate(set) var mode: HealthKitBloodGlucoseUploadReader.Mode

    fileprivate(set) var hasSuccessfullyUploaded = false
    fileprivate(set) var lastUploadAttemptTime = Date.distantPast
    fileprivate(set) var lastUploadAttemptSampleCount = 0
    fileprivate(set) var lastSuccessfulUploadTime = Date.distantPast
    
    fileprivate(set) var lastSuccessfulUploadEarliestSampleTime = Date.distantPast
    fileprivate(set) var lastSuccessfulUploadLatestSampleTime = Date.distantPast
    
    fileprivate(set) var totalDaysHistorical = 0
    fileprivate(set) var currentDayHistorical = 0
    fileprivate(set) var startDateHistoricalBloodGlucoseSamples = Date.distantPast
    fileprivate(set) var endDateHistoricalBloodGlucoseSamples = Date.distantPast

    func resetPersistentState() {
        DDLogVerbose("trace")

        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalUploadCountKey))

        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsStartDateHistoricalBloodGlucoseSamplesKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsEndDateHistoricalBloodGlucoseSamplesKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalDaysHistoricalBloodGlucoseSamplesKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsCurrentDayHistoricalKey))
        
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptSampleCountKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptEarliestSampleTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptLatestSampleTimeKey))
        
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadEarliestSampleTimeKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadLatestSampleTimeKey))
        
        UserDefaults.standard.synchronize()
        
        self.load()
    }

    func updateForUploadAttempt(sampleCount: Int, uploadAttemptTime: Date, earliestSampleTime: Date, latestSampleTime: Date) {
        DDLogVerbose("trace")

        DDLogInfo("Attempting to upload: \(sampleCount) samples, at: \(uploadAttemptTime), with latest sample time: \(latestSampleTime), mode: \(self.mode)")
        
        self.lastUploadAttemptTime = uploadAttemptTime
        self.lastUploadAttemptSampleCount = sampleCount
        
        self.lastUploadAttemptEarliestSampleTime = earliestSampleTime
        UserDefaults.standard.set(self.lastUploadAttemptEarliestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptEarliestSampleTimeKey))

        self.lastUploadAttemptLatestSampleTime = latestSampleTime
        UserDefaults.standard.set(self.lastUploadAttemptLatestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptLatestSampleTimeKey))
        
        UserDefaults.standard.set(self.lastUploadAttemptTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptTimeKey))
        UserDefaults.standard.set(self.lastUploadAttemptSampleCount, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptSampleCountKey))
        
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: self.mode))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.AttemptUpload), object: self.mode))
        }
    }
    
    func updateForSuccessfulUpload(lastSuccessfulUploadTime: Date) {
        DDLogVerbose("trace")
        
        self.totalUploadCount += self.lastUploadAttemptSampleCount
        self.hasSuccessfullyUploaded = self.totalUploadCount > 0
        self.lastSuccessfulUploadTime = lastSuccessfulUploadTime

        self.lastSuccessfulUploadEarliestSampleTime = self.lastUploadAttemptEarliestSampleTime
        UserDefaults.standard.set(self.lastSuccessfulUploadEarliestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadEarliestSampleTimeKey))

        self.lastSuccessfulUploadLatestSampleTime = self.lastUploadAttemptLatestSampleTime
        UserDefaults.standard.set(self.lastSuccessfulUploadLatestSampleTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadLatestSampleTimeKey))

        if self.mode != HealthKitBloodGlucoseUploadReader.Mode.Current {
            if self.totalDaysHistorical > 0 {
                self.currentDayHistorical = self.startDateHistoricalBloodGlucoseSamples.differenceInDays(self.lastSuccessfulUploadLatestSampleTime)
            }
            UserDefaults.standard.set(self.currentDayHistorical, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsCurrentDayHistoricalKey))
        }
        
        UserDefaults.standard.set(self.lastSuccessfulUploadTime, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadTimeKey))
        UserDefaults.standard.set(self.totalUploadCount, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalUploadCountKey))
        UserDefaults.standard.synchronize()
        
        let message = "Successfully uploaded \(self.lastUploadAttemptSampleCount) samples, upload time: \(lastSuccessfulUploadTime), earliest sample date: \(self.lastSuccessfulUploadEarliestSampleTime), latest sample date: \(self.lastSuccessfulUploadLatestSampleTime), mode: \(self.mode). "
        DDLogInfo(message)
        if AppDelegate.testMode {
            let localNotificationMessage = UILocalNotification()
            localNotificationMessage.alertBody = message
            DispatchQueue.main.async {
                UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
            }
        }
        if self.totalDaysHistorical > 0 {
            DDLogInfo("Uploaded \(self.currentDayHistorical) of \(self.totalDaysHistorical) days of historical data")
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: self.mode))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.UploadSuccessful), object: self.mode))
        }
    }

    func updateHistoricalSamplesDateRangeFromHealthKitAsync() {
        DDLogVerbose("trace")
        
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {
            (error: NSError?, startDate: Date?, endDate: Date?) in
            
            if error != nil {
                DDLogError("Failed to update historical samples date range, error: \(String(describing: error))")
            } else if let startDate = startDate {
                self.startDateHistoricalBloodGlucoseSamples = startDate
                
                let endDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryEndDateKey)) as? Date ?? Date()
                self.endDateHistoricalBloodGlucoseSamples = endDate
                self.totalDaysHistorical = self.startDateHistoricalBloodGlucoseSamples.differenceInDays(self.endDateHistoricalBloodGlucoseSamples) + 1
                
                UserDefaults.standard.set(self.startDateHistoricalBloodGlucoseSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsStartDateHistoricalBloodGlucoseSamplesKey))
                UserDefaults.standard.set(self.endDateHistoricalBloodGlucoseSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsEndDateHistoricalBloodGlucoseSamplesKey))
                UserDefaults.standard.set(self.totalDaysHistorical, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalDaysHistoricalBloodGlucoseSamplesKey))
                UserDefaults.standard.synchronize()
                
                DDLogInfo("Updated historical samples date range, start date:\(startDate), end date: \(endDate)")
            }
        }
    }

    func updateHistoricalSamplesDateRange(startDate: Date, endDate: Date) {
        self.startDateHistoricalBloodGlucoseSamples = startDate
        self.endDateHistoricalBloodGlucoseSamples = endDate
        self.totalDaysHistorical = self.startDateHistoricalBloodGlucoseSamples.differenceInDays(self.endDateHistoricalBloodGlucoseSamples)
        
        UserDefaults.standard.set(self.startDateHistoricalBloodGlucoseSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsStartDateHistoricalBloodGlucoseSamplesKey))
        UserDefaults.standard.set(self.endDateHistoricalBloodGlucoseSamples, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsEndDateHistoricalBloodGlucoseSamplesKey))
        UserDefaults.standard.set(self.totalDaysHistorical, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalDaysHistoricalBloodGlucoseSamplesKey))
        UserDefaults.standard.synchronize()
    }
 
    // MARK: Private
    
    fileprivate func load(_ resetUser: Bool = false) {
        DDLogVerbose("trace")
        
        let statsExist = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalUploadCountKey)) != nil
        if statsExist {
            let lastSuccessfulUploadTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadTimeKey)) as? Date
            self.lastSuccessfulUploadTime = lastSuccessfulUploadTime ?? Date.distantPast

            let lastSuccessfulUploadLatestSampleTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastSuccessfulUploadLatestSampleTimeKey)) as? Date
            self.lastSuccessfulUploadLatestSampleTime = lastSuccessfulUploadLatestSampleTime ?? Date.distantPast

            self.totalUploadCount = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalUploadCountKey))
            
            let lastUploadAttemptTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptTimeKey)) as? Date
            self.lastUploadAttemptTime = lastUploadAttemptTime ?? Date.distantPast
            
            let lastUploadAttemptEarliestSampleTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptEarliestSampleTimeKey)) as? Date
            self.lastUploadAttemptEarliestSampleTime = lastUploadAttemptEarliestSampleTime ?? Date.distantPast

            let lastUploadAttemptLatestSampleTime = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptLatestSampleTimeKey)) as? Date
            self.lastUploadAttemptLatestSampleTime = lastUploadAttemptLatestSampleTime ?? Date.distantPast

            self.lastUploadAttemptSampleCount = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsLastUploadAttemptSampleCountKey))
        } else {
            self.lastSuccessfulUploadTime = Date.distantPast
            self.lastSuccessfulUploadLatestSampleTime = Date.distantPast
            self.totalUploadCount = 0

            self.lastUploadAttemptTime = Date.distantPast
            self.lastUploadAttemptEarliestSampleTime = Date.distantPast
            self.lastUploadAttemptLatestSampleTime = Date.distantPast
            self.lastUploadAttemptSampleCount = 0
        }

        if let startDateHistoricalBloodGlucoseSamplesObject = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsStartDateHistoricalBloodGlucoseSamplesKey)),
            let endDateHistoricalBloodGlucoseSamplesObject = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsEndDateHistoricalBloodGlucoseSamplesKey))
        {
            self.totalDaysHistorical = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsTotalDaysHistoricalBloodGlucoseSamplesKey))
            self.currentDayHistorical = UserDefaults.standard.integer(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.StatsCurrentDayHistoricalKey))
            self.startDateHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamplesObject as? Date ?? Date.distantPast
            self.endDateHistoricalBloodGlucoseSamples = endDateHistoricalBloodGlucoseSamplesObject as? Date ?? Date.distantPast
        } else {
            self.totalDaysHistorical = 0
            self.currentDayHistorical = 0
            self.startDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.endDateHistoricalBloodGlucoseSamples = Date.distantPast
        }

        self.hasSuccessfullyUploaded = self.totalUploadCount > 0
    }
    
    fileprivate var totalUploadCount = 0
    fileprivate var lastUploadAttemptEarliestSampleTime = Date.distantPast
    fileprivate var lastUploadAttemptLatestSampleTime = Date.distantPast    
}
