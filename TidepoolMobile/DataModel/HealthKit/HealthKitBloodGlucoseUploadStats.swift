/*
* Copyright (c) 2017, Tidepool Project
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
    fileprivate(set) var phase: HealthKitBloodGlucoseUploadPhase
    
    init(phase: HealthKitBloodGlucoseUploadPhase) {
        DDLogVerbose("trace")
        
        self.phase = phase        
        
        super.init()

        self.load()
    }

    fileprivate(set) var hasSuccessfullyUploaded = false
    
    fileprivate(set) var lastUploadAttemptTime = Date.distantPast
    fileprivate(set) var lastUploadAttemptSampleCount = 0

    fileprivate(set) var lastSuccessfulUploadTime = Date.distantPast
    
    fileprivate(set) var lastSuccessfulUploadEarliestSampleTimeForCurrentPhase = Date.distantPast
    fileprivate(set) var lastSuccessfulUploadLatestSampleTimeForCurrentPhase = Date.distantPast

    fileprivate(set) var currentDayHistorical = 0
    
    func resetPersistentState() {
        DDLogVerbose("trace")
        
        UserDefaults.standard.removeObject(forKey: self.totalUploadCountKey)
        
        UserDefaults.standard.removeObject(forKey: self.lastUploadAttemptTimeKey)
        UserDefaults.standard.removeObject(forKey: self.lastUploadAttemptSampleCountKey)
        UserDefaults.standard.removeObject(forKey: self.lastUploadAttemptEarliestSampleTimeForCurrentPhaseKey)
        UserDefaults.standard.removeObject(forKey: self.lastUploadAttemptLatestSampleTimeForCurrentPhaseKey)
        
        UserDefaults.standard.removeObject(forKey: self.lastSuccessfulUploadTimeKey)
        UserDefaults.standard.removeObject(forKey: self.lastSuccessfulUploadEarliestSampleTimeForCurrentPhaseKey)
        UserDefaults.standard.removeObject(forKey: self.lastSuccessfulUploadLatestSampleTimeForCurrentPhaseKey)
        
        UserDefaults.standard.removeObject(forKey: self.currentDayHistoricalKey)
        
        UserDefaults.standard.synchronize()
        
        self.load()
    }

    func updateForUploadAttempt(sampleCount: Int, uploadAttemptTime: Date, earliestSampleTime: Date, latestSampleTime: Date) {
        DDLogVerbose("trace")

        DDLogInfo("Attempting to upload: \(sampleCount) samples, at: \(uploadAttemptTime), with latest sample time: \(latestSampleTime)")
        
        self.lastUploadAttemptTime = uploadAttemptTime
        self.lastUploadAttemptSampleCount = sampleCount
        
        self.lastUploadAttemptEarliestSampleTimeForCurrentPhase = earliestSampleTime
        UserDefaults.standard.set(self.lastUploadAttemptEarliestSampleTimeForCurrentPhase, forKey: self.lastUploadAttemptEarliestSampleTimeForCurrentPhaseKey)

        self.lastUploadAttemptLatestSampleTimeForCurrentPhase = latestSampleTime
        UserDefaults.standard.set(self.lastUploadAttemptLatestSampleTimeForCurrentPhase, forKey: self.lastUploadAttemptLatestSampleTimeForCurrentPhaseKey)
        
        UserDefaults.standard.set(self.lastUploadAttemptTime, forKey: self.lastUploadAttemptTimeKey)
        UserDefaults.standard.set(self.lastUploadAttemptSampleCount, forKey: self.lastUploadAttemptSampleCountKey)
        
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.AttemptUpload), object: nil))
        }
    }
    
    func updateForSuccessfulUpload(lastSuccessfulUploadTime: Date) {
        DDLogVerbose("trace")
        
        self.totalUploadCount += self.lastUploadAttemptSampleCount
        self.hasSuccessfullyUploaded = self.totalUploadCount > 0
        self.lastSuccessfulUploadTime = lastSuccessfulUploadTime
        
        let message = "Successfully uploaded \(self.lastUploadAttemptSampleCount) samples. Current phase: \(self.phase.currentPhase). Upload time: \(lastSuccessfulUploadTime)"
        DDLogInfo(message)        
        if AppDelegate.testMode {
            let localNotificationMessage = UILocalNotification()
            localNotificationMessage.alertBody = message
            UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
        }

        self.lastSuccessfulUploadEarliestSampleTimeForCurrentPhase = self.lastUploadAttemptEarliestSampleTimeForCurrentPhase
        UserDefaults.standard.set(self.lastSuccessfulUploadEarliestSampleTimeForCurrentPhase, forKey: self.lastSuccessfulUploadEarliestSampleTimeForCurrentPhaseKey)

        self.lastSuccessfulUploadLatestSampleTimeForCurrentPhase = self.lastUploadAttemptLatestSampleTimeForCurrentPhase
        UserDefaults.standard.set(self.lastSuccessfulUploadLatestSampleTimeForCurrentPhase, forKey: self.lastSuccessfulUploadLatestSampleTimeForCurrentPhaseKey)

        if self.phase.currentPhase == .historical {
            if self.phase.totalDaysHistorical > 0 {
                self.currentDayHistorical = self.phase.startDateHistoricalBloodGlucoseSamples.differenceInDays(self.lastSuccessfulUploadLatestSampleTimeForCurrentPhase) + 1
                DDLogInfo("Uploaded \(self.currentDayHistorical) of \(self.phase.totalDaysHistorical) days of historical data");
            }
            UserDefaults.standard.set(self.currentDayHistorical, forKey: self.currentDayHistoricalKey)
        }
        
        UserDefaults.standard.set(self.lastSuccessfulUploadTime, forKey: self.lastSuccessfulUploadTimeKey)
        UserDefaults.standard.set(self.totalUploadCount, forKey: self.totalUploadCountKey)

        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.UploadSuccessful), object: nil))
        }
    }
    
    // MARK: Private
    
    fileprivate func load(_ resetUser: Bool = false) {
        DDLogVerbose("trace")
        
        let statsExist = UserDefaults.standard.object(forKey: self.totalUploadCountKey) != nil
        if statsExist {
            let lastSuccessfulUploadTime = UserDefaults.standard.object(forKey: self.lastSuccessfulUploadTimeKey) as? Date
            self.lastSuccessfulUploadTime = lastSuccessfulUploadTime ?? Date.distantPast

            let lastSuccessfulUploadLatestSampleTimeForCurrentPhase = UserDefaults.standard.object(forKey: self.lastSuccessfulUploadLatestSampleTimeForCurrentPhaseKey) as? Date
            self.lastSuccessfulUploadLatestSampleTimeForCurrentPhase = lastSuccessfulUploadLatestSampleTimeForCurrentPhase ?? Date.distantPast

            self.totalUploadCount = UserDefaults.standard.integer(forKey: self.totalUploadCountKey)
            
            let lastUploadAttemptTime = UserDefaults.standard.object(forKey: self.lastUploadAttemptTimeKey) as? Date
            self.lastUploadAttemptTime = lastUploadAttemptTime ?? Date.distantPast
            
            let lastUploadAttemptEarliestSampleTime = UserDefaults.standard.object(forKey: self.lastUploadAttemptEarliestSampleTimeForCurrentPhaseKey) as? Date
            self.lastUploadAttemptEarliestSampleTimeForCurrentPhase = lastUploadAttemptEarliestSampleTime ?? Date.distantPast

            let lastUploadAttemptLatestSampleTime = UserDefaults.standard.object(forKey: self.lastUploadAttemptLatestSampleTimeForCurrentPhaseKey) as? Date
            self.lastUploadAttemptLatestSampleTimeForCurrentPhase = lastUploadAttemptLatestSampleTime ?? Date.distantPast

            self.lastUploadAttemptSampleCount = UserDefaults.standard.integer(forKey: self.lastUploadAttemptSampleCountKey)

            self.currentDayHistorical = UserDefaults.standard.integer(forKey: self.currentDayHistoricalKey)
        } else {
            self.lastSuccessfulUploadTime = Date.distantPast
            self.lastSuccessfulUploadLatestSampleTimeForCurrentPhase = Date.distantPast
            self.totalUploadCount = 0

            self.lastUploadAttemptTime = Date.distantPast
            self.lastUploadAttemptEarliestSampleTimeForCurrentPhase = Date.distantPast
            self.lastUploadAttemptLatestSampleTimeForCurrentPhase = Date.distantPast
            self.lastUploadAttemptSampleCount = 0
            
            self.currentDayHistorical = 0
        }
        
        self.hasSuccessfullyUploaded = self.totalUploadCount > 0
    }
    
    fileprivate var totalUploadCount = 0
    fileprivate var lastUploadAttemptEarliestSampleTimeForCurrentPhase = Date.distantPast
    fileprivate var lastUploadAttemptLatestSampleTimeForCurrentPhase = Date.distantPast
    
    fileprivate let lastUploadAttemptSampleCountKey = "lastUploadAttemptSampleCount"
    fileprivate let lastUploadAttemptTimeKey = "lastUploadAttemptTime"
    fileprivate let lastSuccessfulUploadTimeKey = "lastUploadTimeBloodGlucoseSamples"
    fileprivate let lastSuccessfulUploadLatestSampleTimeForCurrentPhaseKey = "lastUploadSampleTimeBloodGlucoseSamples"
    fileprivate let lastSuccessfulUploadEarliestSampleTimeForCurrentPhaseKey = "lastSuccessfulUploadEarliestSampleTimeForCurrentPhaseKey"
    fileprivate let lastUploadAttemptEarliestSampleTimeForCurrentPhaseKey = "lastUploadAttemptEarliestSampleTimeForCurrentPhaseKey"
    fileprivate let lastUploadAttemptLatestSampleTimeForCurrentPhaseKey = "lastUploadAttemptLatestSampleTime"
    fileprivate let totalUploadCountKey = "totalUploadCountBloodGlucoseSamples"
    fileprivate let currentDayHistoricalKey = "currentDayHistoricalBloodGlucoseSamples"
}
