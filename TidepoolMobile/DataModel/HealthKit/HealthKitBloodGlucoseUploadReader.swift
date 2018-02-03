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

// NOTE: These delegate methods are usually called indirectly from HealthKit or a URLSession delegate, on a background queue, not on main thread
protocol HealthKitBloodGlucoseUploadReaderDelegate: class {
    func bloodGlucoseReader(reader: HealthKitBloodGlucoseUploadReader, didStopReading reason: HealthKitBloodGlucoseUploadReader.StoppedReason)
    func bloodGlucoseReader(reader: HealthKitBloodGlucoseUploadReader, didReadDataForUpload uploadData: HealthKitBloodGlucoseUploadData, error: Error?)
}

class HealthKitBloodGlucoseUploadReader: NSObject {
    enum Mode: String {
        case Current = "Current"
        case HistoricalAll = "HistoricalAll"
        case HistoricalLastTwoWeeks = "HistoricalLastTwoWeeks"
    }
    
    enum StoppedReason {
        case error(error: Error)
        case background
        case turnOffInterface
        case noResultsFromQuery
    }

    init(mode: Mode) {
        DDLogVerbose("trace")
        
        self.mode = mode

        super.init()
    }
    
    weak var delegate: HealthKitBloodGlucoseUploadReaderDelegate?

    fileprivate(set) var mode: Mode
    fileprivate(set) var isReading = false
    var currentUserId: String?

    func isResumable() -> Bool {
        var isResumable = false
        
        let anchorData = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorKey))
        let anchorLastData = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorLastKey))
        if (anchorData != nil && anchorLastData != nil) {
            isResumable = true
        }
        
        return isResumable
    }
    
    func resetPersistentState() {
        DDLogVerbose("trace")
        
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorLastKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryStartDateKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryEndDateKey))
        UserDefaults.standard.synchronize()
    }

    func startReading() {
        DDLogVerbose("trace")
        
        guard !self.isReading else {
            DDLogVerbose("Ignoring request to start reading samples, already reading samples")
            return
        }
        
        self.isReading = true

        self.readMore()
    }
    
    func stopReading(reason: StoppedReason) {
        DDLogVerbose("trace")

        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring. Mode: \(self.mode)")
            return
        }

        self.isReading = false
        
        self.delegate?.bloodGlucoseReader(reader: self, didStopReading: reason)
    }
    
    func readMore() {
        DDLogVerbose("trace")

        // Load the anchor
        var anchor: HKQueryAnchor?
        let anchorData = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorKey))
        if anchorData != nil {
            anchor = NSKeyedUnarchiver.unarchiveObject(with: anchorData as! Data) as? HKQueryAnchor
        }

        // Get the start and end dates for the predicate
        var startDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryStartDateKey)) as? Date
        var endDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryEndDateKey)) as? Date
        if (startDate == nil || endDate == nil) {
            if (self.mode == HealthKitBloodGlucoseUploadReader.Mode.Current) {
                endDate = Date.distantFuture
                startDate = Date()
            } else if (self.mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks) {
                endDate = Date()
                startDate = endDate!.addingTimeInterval(-60 * 60 * 24 * 14) // Two weeks ago
            } else if (self.mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll) {
                endDate = Date()
                startDate = Date.distantPast
            }

            UserDefaults.standard.set(endDate, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryEndDateKey))
            UserDefaults.standard.set(startDate, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryStartDateKey))
            UserDefaults.standard.synchronize()
        }
        
        // Set up predicate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        
        // Read samples from anchor
        HealthKitManager.sharedInstance.readBloodGlucoseSamplesFromAnchor(predicate: predicate, anchor: anchor, limit: 2000, resultsHandler: self.bloodGlucoseReadResultsHandler)
    }
    
    // MARK: Private
    
    // NOTE: This is a HealthKit results handler, not called on main thread
    fileprivate func bloodGlucoseReadResultsHandler(_ error: NSError?, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, newAnchor: HKQueryAnchor?) {
        DDLogVerbose("trace")
        
        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring")
            return
        }
        
        guard let currentUserId = self.currentUserId else {
            DDLogInfo("No logged in user, unable to upload")
            return
        }
        
        if error == nil {
            let queryAnchorData = newAnchor != nil ? NSKeyedArchiver.archivedData(withRootObject: newAnchor!) : nil
            UserDefaults.standard.set(queryAnchorData, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorLastKey))
            UserDefaults.standard.synchronize()
        }
        
        let healthKitBloodGlucoseUploadData = HealthKitBloodGlucoseUploadData(newSamples: newSamples, deletedSamples: deletedSamples, currentUserId: currentUserId)
        self.delegate?.bloodGlucoseReader(reader: self, didReadDataForUpload: healthKitBloodGlucoseUploadData, error: error)
    }
}
