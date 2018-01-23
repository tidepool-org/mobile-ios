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


protocol HealthKitBloodGlucoseUploadReaderDelegate: class {
    func bloodGlucoseReader(reader: HealthKitBloodGlucoseUploadReader, didReadDataForUpload uploadData: HealthKitBloodGlucoseUploadData?, error: Error?)
}

class HealthKitBloodGlucoseUploadReader: NSObject {
    fileprivate(set) var phase: HealthKitBloodGlucoseUploadPhase
    
    init(phase: HealthKitBloodGlucoseUploadPhase) {
        DDLogVerbose("trace")
        
        self.phase = phase

        super.init()
    }
    
    weak var delegate: HealthKitBloodGlucoseUploadReaderDelegate?

    fileprivate(set) var isReading = false
        
    func resetPersistentState() {
        DDLogVerbose("trace")
        
        UserDefaults.standard.removeObject(forKey: "bloodGlucoseQueryAnchor")
        UserDefaults.standard.removeObject(forKey: "bloodGlucoseQueryAnchorLast")
        UserDefaults.standard.removeObject(forKey: "bloodGlucoseUploadRecentEndDate")
        UserDefaults.standard.removeObject(forKey: "bloodGlucoseUploadRecentStartDate")
        UserDefaults.standard.removeObject(forKey: "bloodGlucoseUploadRecentStartDateFinal")
        UserDefaults.standard.synchronize()
    }

    // Start reading at current position of current phase
    func startReading() {
        DDLogVerbose("trace")
        
        guard !self.isReading else {
            DDLogVerbose("Ignoring request to start reading samples, already reading samples")
            return
        }
        
        self.isReading = true
        
        self.phase.updateHistoricalSamplesDateRangeFromHealthKitAsync()
        
        if self.phase.currentPhase == .mostRecent {
            self.startReadingMostRecent()
        } else {
            self.startReadingFromAnchor()
        }
    }
    
    func stopReading() {
        DDLogVerbose("trace")
        
        self.isReading = false
    }
    
    // Read more, first advancing position, and transitioning phase if needed
    func readMore() {
        DDLogVerbose("trace")
        
        if self.phase.currentPhase == .mostRecent {
            let bloodGlucoseUploadRecentEndDate = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDate") as! Date
            let bloodGlucoseUploadRecentStartDate = bloodGlucoseUploadRecentEndDate.addingTimeInterval(-60 * 60 * 12)
            let bloodGlucoseUploadRecentStartDateFinal = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDateFinal") as! Date
            if bloodGlucoseUploadRecentEndDate.compare(bloodGlucoseUploadRecentStartDateFinal) == .orderedAscending {
                DDLogInfo("finished reading most recent samples")
                self.phase.transitionToPhase(.historical)
            }
            else {
                UserDefaults.standard.set(bloodGlucoseUploadRecentStartDate, forKey: "bloodGlucoseUploadRecentStartDate")
                UserDefaults.standard.set(bloodGlucoseUploadRecentEndDate, forKey: "bloodGlucoseUploadRecentEndDate")
                UserDefaults.standard.synchronize()
            }
        } else {
            let newAnchor = UserDefaults.standard.object(forKey: "bloodGlucoseQueryAnchorLast")
            if newAnchor != nil {
                UserDefaults.standard.set(newAnchor, forKey: "bloodGlucoseQueryAnchor")
                UserDefaults.standard.removeObject(forKey: "bloodGlucoseQueryAnchorLast")
                UserDefaults.standard.synchronize()
            }
        }
        self.stopReading()
        self.startReading()
    }
    
    // MARK: Private

    fileprivate func startReadingFromAnchor() {
        DDLogVerbose("trace")
        
         HealthKitManager.sharedInstance.readBloodGlucoseSamplesFromAnchor(limit: 2000, resultsHandler: self.bloodGlucoseReadResultsHandler)
    }
    
    fileprivate func startReadingMostRecent() {
        DDLogVerbose("trace")
        
        let now = Date()
        let halfDayAgo = now.addingTimeInterval(-60 * 60 * 12)
        let twoWeeksAgo = now.addingTimeInterval(-60 * 60 * 24 * 14)
        var bloodGlucoseUploadRecentEndDate = now
        var bloodGlucoseUploadRecentStartDate = halfDayAgo
        var bloodGlucoseUploadRecentStartDateFinal = twoWeeksAgo
        
        let bloodGlucoseUploadRecentStartDateFinalSetting = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDateFinal")
        if bloodGlucoseUploadRecentStartDateFinalSetting == nil {
            UserDefaults.standard.set(bloodGlucoseUploadRecentEndDate, forKey: "bloodGlucoseUploadRecentEndDate")
            UserDefaults.standard.set(bloodGlucoseUploadRecentStartDate, forKey: "bloodGlucoseUploadRecentStartDate")
            UserDefaults.standard.set(bloodGlucoseUploadRecentStartDateFinal, forKey: "bloodGlucoseUploadRecentStartDateFinal")
            UserDefaults.standard.synchronize()
            DDLogInfo("final date for most upload of most recent samples: \(bloodGlucoseUploadRecentStartDateFinal)")
        } else {
            bloodGlucoseUploadRecentEndDate = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentEndDate") as! Date
            bloodGlucoseUploadRecentStartDate = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDate") as! Date
            bloodGlucoseUploadRecentStartDateFinal = bloodGlucoseUploadRecentStartDateFinalSetting as! Date
        }

         HealthKitManager.sharedInstance.readBloodGlucoseSamples(startDate: bloodGlucoseUploadRecentStartDate, endDate: bloodGlucoseUploadRecentEndDate, limit: 2000, resultsHandler: self.bloodGlucoseReadResultsHandler)
    }
    
    // NOTE: This is a HealthKit results handler, not called on main thread
    fileprivate func bloodGlucoseReadResultsHandler(_ error: NSError?, newSamples: [HKSample]?, newAnchor: HKQueryAnchor?) {
        DDLogVerbose("trace")
        
        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring")
            return
        }

        var healthKitBloodGlucoseUploadData: HealthKitBloodGlucoseUploadData?
        if error == nil {
            if let samples = newSamples {
                if samples.count > 0 {
                    healthKitBloodGlucoseUploadData = HealthKitBloodGlucoseUploadData(samples: samples, currentUserId: phase.currentUserId)
                }
            }
            
            // TODO: uploader - are we persisting new anchor even before we've successfully processed the data for this? What if there is an error processing the data?
            let queryAnchorData = newAnchor != nil ? NSKeyedArchiver.archivedData(withRootObject: newAnchor!) : nil
            UserDefaults.standard.set(queryAnchorData, forKey: "bloodGlucoseQueryAnchorLast")
            UserDefaults.standard.synchronize()
        }
        
        self.delegate?.bloodGlucoseReader(reader: self, didReadDataForUpload: healthKitBloodGlucoseUploadData, error: error)
    }
}
