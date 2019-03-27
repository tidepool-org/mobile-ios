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

// NOTE: These delegate methods are usually called indirectly from HealthKit or a URLSession delegate, on a background queue, not on main thread
protocol HealthKitUploadReaderDelegate: class {
    func uploadReaderDidStartReading(reader: HealthKitUploadReader)
    func uploadReader(reader: HealthKitUploadReader, didStopReading reason: TPUploader.StoppedReason)
    func uploadReader(reader: HealthKitUploadReader, didReadDataForUpload uploadData: HealthKitUploadData, error: Error?)
}

/// There can be an instance of this class for each mode for each type of upload object.
class HealthKitUploadReader: NSObject {
    
    init(type: HealthKitUploadType, mode: TPUploader.Mode) {
        DDLogVerbose("\(#function)")
        
        self.uploadType = type
        self.mode = mode
        self.uploaderSettings = UploaderSettings(mode: mode, type: type)
        super.init()
    }
    
    weak var delegate: HealthKitUploadReaderDelegate?
    let uploaderSettings: UploaderSettings
    
    private(set) var uploadType: HealthKitUploadType
    private(set) var mode: TPUploader.Mode
    private(set) var isReading = false
    var currentUserId: String?

    func isResumable() -> Bool {
        var isResumable = false
        if self.mode == TPUploader.Mode.Current {
            isResumable = true
        } else {
            if let _ = uploaderSettings.objectForKey(.queryStartDateKey), let _ = uploaderSettings.objectForKey(.queryEndDateKey) {
                isResumable = true
            }
        }
        return isResumable
    }
    
    func isFreshHistoricalUpload() -> Bool {
        if mode == TPUploader.Mode.HistoricalAll {
            if uploaderSettings.objectForKey(.queryStartDateKey) == nil {
                return true
            }
        }
        return false
    }
    
    func resetPersistentState() {
        DDLogVerbose("HealthKitUploadReader:\(#function) type: \(uploadType.typeName), mode: \(mode.rawValue)")
        uploaderSettings.resetAllKeys()
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
    
    func promoteLastAnchor() {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")
        let newAnchor = uploaderSettings.anchorForKey(.queryAnchorLastKey)
        if newAnchor != nil {
            uploaderSettings.updateAnchorForKey(.queryAnchorKey, anchor: newAnchor)
            uploaderSettings.removeSettingForKey(.queryAnchorLastKey)
        }
    }
    
    func stopReading(reason: TPUploader.StoppedReason) {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")

        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring. Mode: \(self.mode)")
            return
        }

        self.isReading = false
        
        self.delegate?.uploadReader(reader: self, didStopReading: reason)
    }
    
    func readMore() {
        DDLogInfo("type: \(uploadType.typeName), mode: \(mode.rawValue)")

        // Load the anchor
        let anchor = uploaderSettings.anchorForKey(.queryAnchorKey)

        // Get the start and end dates for the predicate
        var startDate = uploaderSettings.dateForKeyIfExists(.queryStartDateKey)
        var endDate = uploaderSettings.dateForKeyIfExists(.queryEndDateKey)
        if (startDate == nil || endDate == nil) {
            DDLogInfo("startDate nil: \(startDate == nil), endDate nil: \(endDate == nil)")
            if (self.mode == TPUploader.Mode.Current) {
                endDate = Date.distantFuture
                // try setting current mode to 4 hours prior in case there are some straggling events that will be posted for the current day. E.g., in the case of Loop, there is a 3 hour delay in getting some items posted...
                startDate = Date().addingTimeInterval(-60 * 60 * 4)
            } else if (self.mode == TPUploader.Mode.HistoricalAll) {
                endDate = Date().addingTimeInterval(-60 * 60 * 4)
                startDate = Date.distantPast
            }
            uploaderSettings.updateDateSettingForKey(.queryEndDateKey, value: endDate!)
            uploaderSettings.updateDateSettingForKey(.queryStartDateKey, value: startDate!)
        }
        
        DDLogInfo("using query start: \(startDate!), end: \(endDate!)")
       // Set up predicate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        
        // Read samples from anchor
        HealthKitManager.sharedInstance.readSamplesFromAnchorForType(self.uploadType, predicate: predicate, anchor: anchor, limit: 500, resultsHandler: self.samplesReadResultsHandler)
    }
    
    // MARK: Private
    
    // NOTE: This is a HealthKit results handler, not called on main thread
    private func samplesReadResultsHandler(_ error: NSError?, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, newAnchor: HKQueryAnchor?) {
        DDLogVerbose("(\(uploadType.typeName), mode: \(mode.rawValue))")
        
        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring")
            return
        }
        
        guard let currentUserId = self.currentUserId else {
            DDLogInfo("No logged in user, unable to upload")
            return
        }
        
        if error == nil {
            uploaderSettings.updateAnchorForKey(.queryAnchorLastKey, anchor: newAnchor)
        }
        
        let healthKitUploadData = HealthKitUploadData(self.uploadType, newSamples: newSamples, deletedSamples: deletedSamples, currentUserId: currentUserId)
        self.delegate?.uploadReader(reader: self, didReadDataForUpload: healthKitUploadData, error: error)
    }
}
