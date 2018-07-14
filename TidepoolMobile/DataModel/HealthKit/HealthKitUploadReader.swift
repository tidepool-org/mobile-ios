/*
* Copyright (c) 2017-2018, Tidepool Project
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
protocol HealthKitUploadReaderDelegate: class {
    func uploadReaderDidStartReading(reader: HealthKitUploadReader)
    func uploadReader(reader: HealthKitUploadReader, didStopReading reason: HealthKitUploadReader.StoppedReason)
    func uploadReader(reader: HealthKitUploadReader, didReadDataForUpload uploadData: HealthKitUploadData, error: Error?)
}

/// There can be an instance of this class for each mode for each type of upload object.
class HealthKitUploadReader: NSObject {
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

    init(type: HealthKitUploadType, mode: Mode) {
        DDLogVerbose("trace")
        
        self.uploadType = type
        self.mode = mode

        super.init()
    }
    
    weak var delegate: HealthKitUploadReaderDelegate?

    fileprivate(set) var uploadType: HealthKitUploadType
    fileprivate(set) var mode: Mode
    fileprivate(set) var isReading = false
    var currentUserId: String?

    func isResumable() -> Bool {
        var isResumable = false

        if self.mode == HealthKitUploadReader.Mode.Current {
            isResumable = true
        } else {
            if let _ = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryStartDateKey)),
               let _ = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryEndDateKey)) {
                isResumable = true
            }
        }

        return isResumable
    }
    
    func resetPersistentState() {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")
        
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorLastKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryStartDateKey))
        UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryEndDateKey))
        UserDefaults.standard.synchronize()
    }

    func startReading() {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")
        
        guard !self.isReading else {
            DDLogVerbose("Ignoring request to start reading samples, already reading samples")
            return
        }
        
        self.isReading = true

        self.delegate?.uploadReaderDidStartReading(reader: self)

        self.readMore()
    }
    
    func stopReading(reason: StoppedReason) {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")

        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring. Mode: \(self.mode)")
            return
        }

        self.isReading = false
        
        self.delegate?.uploadReader(reader: self, didStopReading: reason)
    }
    
    func readMore() {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")

        // Load the anchor
        var anchor: HKQueryAnchor?
        let anchorData = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorKey))
        if anchorData != nil {
            anchor = NSKeyedUnarchiver.unarchiveObject(with: anchorData as! Data) as? HKQueryAnchor
        }

        // Get the start and end dates for the predicate
        var startDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryStartDateKey)) as? Date
        var endDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryEndDateKey)) as? Date
        if (startDate == nil || endDate == nil) {
            if (self.mode == HealthKitUploadReader.Mode.Current) {
                endDate = Date.distantFuture
                startDate = Date()
            } else if (self.mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks) {
                endDate = Date()
                startDate = endDate!.addingTimeInterval(-60 * 60 * 24 * 14) // Two weeks ago
            } else if (self.mode == HealthKitUploadReader.Mode.HistoricalAll) {
                endDate = Date()
                startDate = Date.distantPast
            }

            UserDefaults.standard.set(endDate, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryEndDateKey))
            UserDefaults.standard.set(startDate, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryStartDateKey))
            UserDefaults.standard.synchronize()
        }
        
        // Set up predicate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        
        // Read samples from anchor
        HealthKitManager.sharedInstance.readSamplesFromAnchorForType(self.uploadType, predicate: predicate, anchor: anchor, limit: 2000, resultsHandler: self.samplesReadResultsHandler)
    }
    
    // MARK: Private
    
    // NOTE: This is a HealthKit results handler, not called on main thread
    fileprivate func samplesReadResultsHandler(_ error: NSError?, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, newAnchor: HKQueryAnchor?) {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")
        
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
            UserDefaults.standard.set(queryAnchorData, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorLastKey))
            UserDefaults.standard.synchronize()
        }
        
        let healthKitUploadData = HealthKitUploadData(self.uploadType, newSamples: newSamples, deletedSamples: deletedSamples, currentUserId: currentUserId)
        self.delegate?.uploadReader(reader: self, didReadDataForUpload: healthKitUploadData, error: error)
    }
}
