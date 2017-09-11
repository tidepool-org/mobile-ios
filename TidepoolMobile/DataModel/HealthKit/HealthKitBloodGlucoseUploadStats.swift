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
    fileprivate(set) var lastSuccessfulUploadTime = Date.distantPast
    
    fileprivate(set) var lastUploadAttemptTime = Date.distantPast
    fileprivate(set) var lastUploadAttemptSampleCount = 0

    fileprivate(set) var lastSuccessfulUploadLatestSampleTimeHistoricalPhase = Date.distantPast
    fileprivate(set) var lastUploadAttemptLatestSampleTimeHistoricalPhase = Date.distantPast
    
    fileprivate(set) var currentDayHistorical = 0
    
    func resetPersistentState() {
        DDLogVerbose("trace")
        
        UserDefaults.standard.removeObject(forKey: "totalUploadCountBloodGlucoseSamples")
        UserDefaults.standard.removeObject(forKey: "lastUploadTimeBloodGlucoseSamples")
        
        UserDefaults.standard.removeObject(forKey: "lastUploadAttemptTime")
        UserDefaults.standard.removeObject(forKey: "lastUploadAttemptSampleCount")
        UserDefaults.standard.removeObject(forKey: "lastUploadAttemptLatestSampleTimeHistoricalPhase")
        
        UserDefaults.standard.removeObject(forKey: "lastUploadSampleTimeBloodGlucoseSamples")
        UserDefaults.standard.removeObject(forKey: "currentDayHistoricalBloodGlucoseSamples")
        UserDefaults.standard.synchronize()
        
        self.load()
    }

    func updateForUploadAttempt(sampleCount: Int, uploadAttemptTime: Date, latestSampleTime: Date) {
        DDLogVerbose("trace")

        DDLogInfo("Attempting to upload: \(sampleCount) samples, at: \(uploadAttemptTime), with latest sample time: \(latestSampleTime)")
        
        self.lastUploadAttemptTime = uploadAttemptTime
        self.lastUploadAttemptSampleCount = sampleCount
        
        if self.phase.currentPhase == .historical {
            self.lastUploadAttemptLatestSampleTimeHistoricalPhase = latestSampleTime
            UserDefaults.standard.set(self.lastUploadAttemptLatestSampleTimeHistoricalPhase, forKey: "lastUploadAttemptLatestSampleTime")
        }
        
        UserDefaults.standard.set(self.lastUploadAttemptTime, forKey: "lastUploadAttemptTime")
        UserDefaults.standard.set(self.lastUploadAttemptSampleCount, forKey: "lastUploadAttemptSampleCount")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
        }
    }
    
    func updateForSuccessfulUpload(lastSuccessfulUploadTime: Date) {
        DDLogVerbose("trace")
        
        self.totalUploadCountBloodGlucoseSamples += self.lastUploadAttemptSampleCount
        self.hasSuccessfullyUploaded = self.totalUploadCountBloodGlucoseSamples > 0
        self.lastSuccessfulUploadTime = lastSuccessfulUploadTime
        
        let message = "Successfully uploaded \(self.lastUploadAttemptSampleCount) samples. Current phase: \(self.phase.currentPhase). Upload time: \(lastSuccessfulUploadTime)"
        DDLogInfo(message)
        
        if AppDelegate.testMode {
            let localNotificationMessage = UILocalNotification()
            localNotificationMessage.alertBody = message
            UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
        }
        
        if self.phase.currentPhase == .historical {
            if self.lastSuccessfulUploadLatestSampleTimeHistoricalPhase.compare(self.lastUploadAttemptLatestSampleTimeHistoricalPhase) == .orderedAscending {
                self.lastSuccessfulUploadLatestSampleTimeHistoricalPhase = self.lastUploadAttemptLatestSampleTimeHistoricalPhase
            }
            if self.phase.totalDaysHistorical > 0 {
                self.currentDayHistorical = self.phase.startDateHistoricalBloodGlucoseSamples.differenceInDays(self.lastSuccessfulUploadLatestSampleTimeHistoricalPhase) + 1
                DDLogInfo("Uploaded \(self.currentDayHistorical) of \(self.phase.totalDaysHistorical) days of historical data");
            }
            UserDefaults.standard.set(self.lastSuccessfulUploadLatestSampleTimeHistoricalPhase, forKey: "lastUploadSampleTimeBloodGlucoseSamples")
            UserDefaults.standard.set(self.currentDayHistorical, forKey: "currentDayHistoricalBloodGlucoseSamples")
        }
        
        UserDefaults.standard.set(self.lastSuccessfulUploadTime, forKey: "lastUploadTimeBloodGlucoseSamples")
        UserDefaults.standard.set(self.totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
        }
    }
    
    // MARK: Private
    
    fileprivate func load(_ resetUser: Bool = false) {
        DDLogVerbose("trace")
        
        let statsExist = UserDefaults.standard.object(forKey: "totalUploadCountBloodGlucoseSamples") != nil
        if statsExist {
            let lastSuccessfulUploadTime = UserDefaults.standard.object(forKey: "lastUploadTimeBloodGlucoseSamples") as? Date
            self.lastSuccessfulUploadTime = lastSuccessfulUploadTime ?? Date.distantPast
            
            let lastSuccessfulUploadLatestSampleTimeHistoricalPhase = UserDefaults.standard.object(forKey: "lastUploadSampleTimeBloodGlucoseSamples") as? Date
            self.lastSuccessfulUploadLatestSampleTimeHistoricalPhase = lastSuccessfulUploadLatestSampleTimeHistoricalPhase ?? Date.distantPast

            self.totalUploadCountBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalUploadCountBloodGlucoseSamples")
            
            let lastUploadAttemptTime = UserDefaults.standard.object(forKey: "lastUploadAttemptTime") as? Date
            self.lastUploadAttemptTime = lastUploadAttemptTime ?? Date.distantPast
            
            let lastUploadAttemptLatestSampleTime = UserDefaults.standard.object(forKey: "lastUploadAttemptLatestSampleTime") as? Date
            self.lastUploadAttemptLatestSampleTimeHistoricalPhase = lastUploadAttemptLatestSampleTime ?? Date.distantPast
            
            self.lastUploadAttemptSampleCount = UserDefaults.standard.integer(forKey: "lastUploadAttemptSampleCount")

            self.currentDayHistorical = UserDefaults.standard.integer(forKey: "currentDayHistoricalBloodGlucoseSamples")
        } else {
            self.lastSuccessfulUploadTime = Date.distantPast
            self.lastSuccessfulUploadLatestSampleTimeHistoricalPhase = Date.distantPast
            self.totalUploadCountBloodGlucoseSamples = 0

            self.lastUploadAttemptTime = Date.distantPast
            self.lastUploadAttemptLatestSampleTimeHistoricalPhase = Date.distantPast
            self.lastUploadAttemptSampleCount = 0
            
            self.currentDayHistorical = 0
        }
        
        self.hasSuccessfullyUploaded = self.totalUploadCountBloodGlucoseSamples > 0
    }
    
    fileprivate var totalUploadCountBloodGlucoseSamples = 0    
}
