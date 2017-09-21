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

class HealthKitBloodGlucoseUploadPhase: NSObject {
    init(currentUserId: String) {
        DDLogVerbose("trace")
        
        self.currentUserId = currentUserId
        
        super.init()

        self.load()
    }

    enum Phases: Int {
        case mostRecent
        case historical
        case current
    }

    var currentUserId = ""
    fileprivate(set) var currentPhase = Phases.mostRecent
    fileprivate(set) var totalDaysHistorical = 0
    fileprivate(set) var startDateHistoricalBloodGlucoseSamples = Date.distantPast
    fileprivate(set) var endDateHistoricalBloodGlucoseSamples = Date.distantPast
    
    func resetPersistentState() {
        DDLogVerbose("trace")
        
        UserDefaults.standard.removeObject(forKey: "uploadPhaseBloodGlucoseSamples")
        
        UserDefaults.standard.removeObject(forKey: "startDateHistoricalBloodGlucoseSamples")
        UserDefaults.standard.removeObject(forKey: "endDateHistoricalBloodGlucoseSamples")
        UserDefaults.standard.removeObject(forKey: "totalDaysHistoricalBloodGlucoseSamples")
        
        UserDefaults.standard.synchronize()
        
        self.load()
    }
    
    func transitionToPhase(_ newPhase: Phases) {
        DDLogVerbose("trace")
        
        let message = "Transitioning to phase: \(newPhase) from phase: \(self.currentPhase)"
        DDLogInfo(message)
        if AppDelegate.testMode {
            let localNotificationMessage = UILocalNotification()
            localNotificationMessage.alertBody = message
            UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
        }
        
        self.currentPhase = newPhase
        
        UserDefaults.standard.set(self.currentPhase.rawValue, forKey: "uploadPhaseBloodGlucoseSamples")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.PhaseTransition), object: nil))
        }
    }
    
    func updateHistoricalSamplesDateRangeFromHealthKitAsync() {
        DDLogVerbose("trace")
        
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {
            (error: NSError?, startDate: Date?, endDate: Date?) in
            
            if error == nil && startDate != nil && endDate != nil {
                self.startDateHistoricalBloodGlucoseSamples = startDate!
                self.endDateHistoricalBloodGlucoseSamples = endDate!
                self.totalDaysHistorical = self.startDateHistoricalBloodGlucoseSamples.differenceInDays(self.endDateHistoricalBloodGlucoseSamples) + 1
                
                UserDefaults.standard.set(startDate, forKey: "startDateHistoricalBloodGlucoseSamples")
                UserDefaults.standard.set(endDate, forKey: "endDateHistoricalBloodGlucoseSamples")
                UserDefaults.standard.set(endDate, forKey: "totalDaysHistoricalBloodGlucoseSamples")
                UserDefaults.standard.synchronize()
                
                DDLogInfo("Updated historical samples date range, start date:\(startDate!), end date: \(endDate!)")
            } else {
                DDLogError("Failed to update historical samples date range, error: \(String(describing: error))")
            }
        }
    }
    
    // MARK: Private
    
    fileprivate func load() {
        DDLogVerbose("trace")
        
        var phase = Phases.mostRecent
        
        if let persistedPhaseObject = UserDefaults.standard.object(forKey: "uploadPhaseBloodGlucoseSamples"),
           let persistedPhase = HealthKitBloodGlucoseUploadPhase.Phases(rawValue: (persistedPhaseObject as AnyObject).intValue)
        {
            phase = persistedPhase

            let startDateHistoricalBloodGlucoseSamples = UserDefaults.standard.object(forKey: "startDateHistoricalBloodGlucoseSamples") as? Date
            self.startDateHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples ?? Date.distantPast
            let endDateHistoricalBloodGlucoseSamples = UserDefaults.standard.object(forKey: "endDateHistoricalBloodGlucoseSamples") as? Date
            self.endDateHistoricalBloodGlucoseSamples = endDateHistoricalBloodGlucoseSamples ?? Date.distantPast
            self.totalDaysHistorical = UserDefaults.standard.integer(forKey: "totalDaysHistoricalBloodGlucoseSamples")
        } else {
            self.startDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.endDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.totalDaysHistorical = 0
        }
        
        self.transitionToPhase(phase)
    }
}
