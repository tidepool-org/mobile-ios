/*
* Copyright (c) 2016-2018, Tidepool Project
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

// Note: The current upload/historical upload boundary is set some time delta in the past. For previous releases this was 4 hours in order to pick up deletes from Loop that occur 3 hours after Dexcom samples are reported, since only the current upload picks up new deletes (anchor query).
// The delta is somewhat arbitrary, but should be at least 4 hours. Here it is set to 1 week. On a complete reset (e.g., incompatible uploader update), all samples back this far will be re-uploaded, so it should not be too long in the past.
let kCurrentStartTimeInPast: TimeInterval = (-60 * 60 * 24 * 7)

class HealthKitUploadManager:
        NSObject,
        URLSessionDelegate,
        URLSessionTaskDelegate
{
    static let sharedInstance = HealthKitUploadManager()
    let settings = HKGlobalSettings.sharedInstance
    
    private override init() {
        DDLogVerbose("\(#function)")

        currentHelper = HealthKitUploadHelper(.Current)
        historicalHelper = HealthKitUploadHelper(.HistoricalAll)
        super.init()

        // Reset persistent uploader state if uploader version is upgraded
        let latestUploaderVersion = 8
        let lastExecutedUploaderVersion = settings.lastExecutedUploaderVersion.value
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            settings.lastExecutedUploaderVersion.value = latestUploaderVersion
            resetPersistentData = true
        }
        if resetPersistentData {
            self.resetPersistentState(switchingHealthKitUsers: false)
        }
    }
    private var currentHelper: HealthKitUploadHelper
    private var historicalHelper: HealthKitUploadHelper
    
    /// Return array of stats per type for specified mode
    func statsForMode(_ mode: TPUploader.Mode) -> [TPUploaderStats] {
        let helper = mode == .Current ? currentHelper : historicalHelper
        var result: [TPUploaderStats] = []
        for reader in helper.readers {
            result.append(reader.readerSettings.stats())
        }
        return result
    }
    
    func isUploadInProgressForMode(_ mode: TPUploader.Mode) -> Bool {
        let helper = mode == .Current ? currentHelper : historicalHelper
        let result = helper.isUploading
        DDLogVerbose("returning \(result) for mode \(mode)")
        return result
    }
 
    func resetPersistentStateForMode(_ mode: TPUploader.Mode) {
        DDLogVerbose("\(mode)")
        let helper = mode == .Current ? currentHelper : historicalHelper
        helper.resetPersistentState()
        if mode == .HistoricalAll {
            settings.resetHistoricalUploadSettings()
        } else {
            // mode == .Current
            settings.resetCurrentUploadSettings()
        }
    }

    func resetPersistentState(switchingHealthKitUsers: Bool) {
        DDLogVerbose("switchingHealthKitUsers: \(switchingHealthKitUsers)")
        currentHelper.resetPersistentState()
        historicalHelper.resetPersistentState()
        if switchingHealthKitUsers {
            settings.hasPresentedSyncUI.reset()
        }
    }
    
    func startUploading(mode: TPUploader.Mode, currentUserId: String) {
        DDLogVerbose("mode: \(mode.rawValue)")

        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, unable to upload. Mode: \(mode)")
            return
        }

        guard let serviceAPI = TPUploaderServiceAPI.connector else {
            DDLogError("Unable to startUploading - service is not configured!")
            return
        }

        guard serviceAPI.currentUploadId != nil else {
            DDLogError("Unable to startUploading - no currentUploadId available!")
            return
        }
        
        guard serviceAPI.isConnectedToNetwork() else {
            DDLogError("Unable to startUploading - currently offline!")
            return
        }

        // assume if we have current upload going on, we want to have background task servicing...
        if mode == .Current {
            self.beginSamplesUploadBackgroundTask()
        }
        
        let helper = mode == .Current ? currentHelper : historicalHelper
        helper.startUploading(currentUserId: currentUserId)
     }
    
    func stopUploading(mode: TPUploader.Mode, reason: TPUploader.StoppedReason) {
        DDLogVerbose("(\(mode.rawValue)) reason: \(reason)")
        let helper = mode == .Current ? currentHelper : historicalHelper
        helper.stopUploading(reason: reason)

        // assume if we don't have current upload going on, we don't need background task..
        if mode == .Current {
            self.endSamplesUploadBackgroundTask()
        }

    }
    
    func stopUploading(reason: TPUploader.StoppedReason) {
        DDLogVerbose("reason: \(reason)")
        self.stopUploading(mode: .Current, reason: reason)
        self.stopUploading(mode: .HistoricalAll, reason: reason)
    }

    func resumeUploadingIfResumable(currentUserId: String?) {
        DDLogVerbose("")
        if TPUploaderServiceAPI.connector?.currentUploadId != nil {
            currentHelper.resumeUploadingIfResumable(currentUserId: currentUserId)
            historicalHelper.resumeUploadingIfResumable(currentUserId: currentUserId)
        } else {
            DDLogError("Unable to resumeUploading - no currentUploadId available!")
        }
    }
    
    // Note that beginBackgroundTask calls need to be balanced with endBackgroundTask calls!
    // Current app has a separate call for each mode/type. It calls begin on startReading() and end on stopReading(), if app is in background and mode is .Current. If app transitions to foreground after a begin, the end would not be called!
    // TODO: It is unclear whether this helps or not; it's not just reading, but also uploading that would need the time. For the new model, we'd want to turn this on before doing a round of reads, and perhaps off after expiration or completion of background upload?
    private func beginSamplesUploadBackgroundTask() {
//        if currentSamplesUploadBackgroundTaskIdentifier == nil {
//            self.currentSamplesUploadBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
//                () -> Void in
//                DispatchQueue.main.async {
//                    let message = "Background time expired"
//                    DDLogInfo(message)
//                    //UIApplication.localNotifyMessage(message)
//                }
//            })
//        }
    }
    
    private func endSamplesUploadBackgroundTask() {
//        if let currentSamplesUploadBackgroundTaskIdentifier = self.currentSamplesUploadBackgroundTaskIdentifier {
//            UIApplication.shared.endBackgroundTask(currentSamplesUploadBackgroundTaskIdentifier)
//            self.currentSamplesUploadBackgroundTaskIdentifier = nil
//
//        }
    }
    
    private var currentSamplesUploadBackgroundTaskIdentifier: UIBackgroundTaskIdentifier?

}

//
// MARK: - Private helper class
//

import UIKit  // for UIApplication...

/// Helper class to apply functions to each type of upload data
private class HealthKitUploadHelper: HealthKitSampleUploaderDelegate, HealthKitUploadReaderDelegate {
    
    init(_ mode: TPUploader.Mode) {
        self.mode = mode
        self.isUploading = false
        self.uploader = HealthKitUploader(mode)
        self.uploader.delegate = self
        // init reader, stats for the different types
        let hkTypes = HealthKitConfiguration.sharedInstance.healthKitUploadTypes
        for hkType in hkTypes {
            let reader = HealthKitUploadReader(type: hkType, mode: self.mode)
            reader.delegate = self
            self.readers.append(reader)
        }
    }
    
    private let mode: TPUploader.Mode
    private(set) var readers: [HealthKitUploadReader] = []
    private var uploader: HealthKitUploader
    private(set) var isUploading: Bool
    private var samplesToUpload = [[String: AnyObject]]()
    // dates of first and last samples in samplesToUpload buffer
    private var firstSampleDate: Date?
    private var lastSampleDate: Date?
    private var samplesToDelete = [[String: AnyObject]]()
    let settings = HKGlobalSettings.sharedInstance

    func resetPersistentState() {
        DDLogVerbose("helper resetPersistentState (\(mode.rawValue))")
        for reader in readers {
            reader.resetPersistentState()
            reader.readerSettings.resetPersistentState()
        }
        resetUploadBuffers()
    }
    
    func markNotResumable() {
        // Clear out the upload reader...
        DDLogVerbose("(mode: \(mode.rawValue))")
        resetPersistentState()
    }
    
    private func resetUploadBuffers() {
        // reset current samples...
        self.samplesToUpload = [[String: AnyObject]]()
        self.samplesToDelete = [[String: AnyObject]]()
        self.firstSampleDate = nil
        self.lastSampleDate = nil
    }
    
    private func gatherUploadSamples() {
        if samplesToUpload.count > 0 {
            DDLogError("ERR: gather called with non-empty buffer!")
        }
        self.firstSampleDate = nil
        self.lastSampleDate = nil
        
       // get readers that still have samples...
        var readersWithSamples: [HealthKitUploadReader] = []
        for reader in readers {
            reader.resetUploadStats()
            if reader.nextSampleDate() != nil {
                readersWithSamples.append(reader)
            }
        }
        DDLogVerbose("readersWithSamples: \(readersWithSamples.count)")
        guard readersWithSamples.count > 0 else {
            return
        }
        // loop to get next group of samples to upload
        var nextReader: HealthKitUploadReader?
        repeat {
            nextReader = nil
            var nextSampleDate: Date?
            for reader in readersWithSamples {
                if let sampleDate = reader.nextSampleDate() {
                    if nextSampleDate == nil {
                        nextSampleDate = sampleDate
                        nextReader = reader
                    } else {
                        if sampleDate.compare(nextSampleDate!) == .orderedDescending {
                            nextSampleDate = sampleDate
                            nextReader = reader
                        }
                    }
                }
            }
            if let reader = nextReader {
                if let nextSample = reader.popNextSample() {
                    if let sampleAsDict = reader.sampleToUploadDict(nextSample) {
                        samplesToUpload.append(sampleAsDict)
                        // remember first and last sample dates for stats...
                        if self.lastSampleDate == nil {
                            self.lastSampleDate = nextSampleDate
                        }
                        self.firstSampleDate = nextSampleDate
                    }
                }
            }
        } while nextReader != nil && samplesToUpload.count < 500
        // let each reader note attempt progress...
        let uploadTime = Date()
        for reader in readersWithSamples {
            reader.reportNextUploadStatsAtTime(uploadTime)
        }
        DDLogInfo("found samples to upload: \(samplesToUpload.count) at: \(uploadTime)")
        // note upload attempt...
        if let firstSampleDate = self.firstSampleDate, let lastSampleDate = self.lastSampleDate {
            DDLogVerbose("sample date range earliest: \(firstSampleDate), latest: \(lastSampleDate) (\(self.mode))")
        }
    }

    // Deletes are not dated, so can't be uploaded in any order. Just load up to 500 deletes...
    private func gatherUploadDeletes() {
        if samplesToDelete.count > 0 {
            DDLogError("ERR: gather deletes called with non-empty buffer!")
        }
        // loop through all readers to get any deletes...
        for reader in readers {
            var nextDeleteDict: [String: AnyObject]?
            repeat {
                nextDeleteDict = reader.nextDeletedSampleDict()
                    if nextDeleteDict != nil {
                    samplesToDelete.append(nextDeleteDict!)
                }
            } while nextDeleteDict != nil && samplesToDelete.count < 500
            if samplesToDelete.count >= 500 {
                break
            }
        }
    }

    func startUploading(currentUserId: String) {
        DDLogVerbose("(\(mode.rawValue))")
        
        guard !self.isUploading else {
            DDLogInfo("Already uploading, ignoring.")
            return
        }
        
        self.isUploading = true
        for reader in readers {
            // If upload reader has been reset, ensure stats are also reset!
            if !reader.isResumable() {
                reader.readerSettings.resetAllReaderKeys()
            }
            reader.currentUserId = currentUserId
        }
        // Cancel any pending tasks (also resets pending state, so we don't get stuck not being able to upload due to early termination or crash wherein the persistent state tracking pending uploads was not reset
        self.uploader.cancelTasks()
        
        // For initial state, set up date fenceposts
        var newHistoricalFence = Date().addingTimeInterval(kCurrentStartTimeInPast)
        if let currentStart = settings.currentStartDate.value {
            // Starting a new historical sync...
            newHistoricalFence = currentStart
        } else {
            // No current or historical sync has happened...
            settings.currentStartDate.value = newHistoricalFence
            DDLogVerbose("new currentStartDate: \(newHistoricalFence)")
        }

        if settings.historicalFenceDate.value == nil {
            // No current or historical sync has happened...
            settings.historicalFenceDate.value = newHistoricalFence
            DDLogVerbose("new historicalFenceDate: \(newHistoricalFence)")
            // Also set earliest sample date here until we discover earlier samples...
            settings.historicalEarliestDate.value = newHistoricalFence
        }

        if (mode == TPUploader.Mode.Current) {
            // Observe new samples for Current mode
            DDLogInfo("Start observing samples after starting upload. Mode: \(mode)")
            for reader in readers {
                reader.enableBackgroundDeliverySamples()
                reader.startObservingSamples()
            }
        } else {
            // Kick off reading for historical, if resumable...
            DDLogInfo("Start reading samples after starting upload. Mode: \(mode)")
            // Note: for historical, first step is to figure out sample date range...
            for reader in readers {
                reader.startReading()
            }
        }
        
        postNotifications([TPUploaderNotifications.Updated, TPUploaderNotifications.TurnOnUploader], mode: mode)
    }
    
    private func postNotifications(_ notificationNames: [String], mode: TPUploader.Mode, reason: TPUploader.StoppedReason? = nil) {
        var uploadInfo : Dictionary<String, Any> = [
            "type" : "All",
            "mode" : mode
        ]
        if let reason = reason {
            uploadInfo["reason"] = reason
        }
        for name in notificationNames {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: name), object: mode, userInfo: uploadInfo))
        }
    }

    func stopUploading(reason: TPUploader.StoppedReason) {
        DDLogVerbose("(\(mode.rawValue))")

        guard self.isUploading else {
            DDLogInfo("Not currently uploading, ignoring. Mode: \(mode)")
            return
        }
        
        DDLogInfo("stopUploading. Mode: \(mode). reason: \(String(describing: reason))")
        
        self.isUploading = false
        for reader in readers {
            reader.currentUserId = nil
            reader.stopReading()
        }
        
        self.uploader.cancelTasks()
        
        if (mode == TPUploader.Mode.Current) {
            for reader in readers {
                reader.stopObservingSamples()
            }
        }
        
        postNotifications([TPUploaderNotifications.Updated, TPUploaderNotifications.TurnOffUploader], mode: mode, reason: reason)
    }
    
    
    func isResumable() -> Bool {
        var resumableReaders = false
        for reader in readers {
            if reader.isResumable() {
                resumableReaders = true
                break
            }
        }
        return resumableReaders
    }
    
    func resumeUploadingIfResumable(currentUserId: String?) {
        DDLogVerbose("(\(mode.rawValue))")
        
        if (currentUserId != nil && !self.isUploading) {
            if mode == TPUploader.Mode.Current {
                // Always OK to resume Current
                self.startUploading(currentUserId: currentUserId!)
            } else {
                // Only resume HistoricalAll if any readers are resumable
                if isResumable() {
                    self.startUploading(currentUserId: currentUserId!)
                }
            }
        }
    }
    
    //
    // MARK: - HealthKitSampleUploaderDelegate method
    //
    
    // NOTE: This is usually called on a background queue, not on main thread
    func sampleUploader(uploader: HealthKitUploader, didCompleteUploadWithError error: Error?, rejectedSamples: [Int]?) {
        DDLogVerbose("(\(uploader.mode.rawValue))")
        
        DispatchQueue.main.async {
            DDLogInfo("didCompleteUploadWithError on main thread")
            
            // TODO: for upload errors, look at stopping upload process until conditions are more favorable...
            if let error = error as NSError? {
                // If the service didn't like certain upload samples, remove them and retry...
                if let rejectedSamples = rejectedSamples {
                    DDLogError("Service rejected \(rejectedSamples.count) samples!")
                    if rejectedSamples.count > 0 {
                        let remainingSamples = self.samplesToUpload
                            .enumerated()
                            .filter {!rejectedSamples.contains($0.offset)}
                            .map{ $0.element}
                        let originalCount = self.samplesToUpload.count
                        let remainingCount = remainingSamples.count
                        let rejectedCount = rejectedSamples.count
                        DDLogVerbose("original count: \(originalCount), remaining count: \(remainingCount), rejected counted: \(rejectedCount)")
                        if originalCount - remainingCount == rejectedCount {
                            self.samplesToUpload = remainingSamples
                            self.samplesToDelete = [[String: AnyObject]]()
                            self.tryNextUpload()
                            return
                        }
                    }
                }
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    let message = "Upload task cancelled. (\(uploader.mode))"
                    DDLogError(message)
                } else {
                    let message = "Upload batch failed, stop reading. (\(uploader.mode)). Error: \(String(describing: error))"
                    DDLogError(message)
                }
                // stop uploading on non-recoverable errors for now...
                self.stopUploading(reason: .error(error: error))
                return
            }
            
            // success!
            
            DDLogInfo("Upload session succeeded! (\(uploader.mode))")
            
            // save overall progress...
            let uploadTime = Date()
            if self.mode == .Current {
                self.settings.lastSuccessfulCurrentUploadTime.value = uploadTime
            } else {
                // for historical reads, move the end date fence to show progress
                if let earliestUploadDate = self.firstSampleDate {
                    // move to 1 second earlier tha last uploaded sample date, to avoid picking up that same sample in a loop!
                    let newFenceDate = earliestUploadDate.addingTimeInterval(-1.0)
                    DDLogVerbose("moved historical fence to \(earliestUploadDate) from \(String(describing: self.settings.historicalFenceDate.value))")
                    self.settings.historicalFenceDate.value = newFenceDate
                } else {
                    if self.samplesToUpload.count == 0 {
                        DDLogVerbose("historical fence not moved - no samples uploaded!")
                    } else {
                        DDLogError("ERR: expected move of historical fence!")
                    }
                }
            }
            
            // let readers persist any progress anchors
            for reader in self.readers {
                reader.updateForSuccessfulUpload(uploadTime)
            }
            
            // reset the upload buffers
            DDLogInfo("Successfully uploaded \(self.samplesToUpload.count) samples, \(self.samplesToDelete.count) deletes (\(self.mode))")
            self.resetUploadBuffers()
            
            // if we haven't been stopped, continue the uploading...
            guard self.isUploading else {
                DDLogInfo("stopping upload...")
                return
            }
            // Check if more deletes to do, and upload those...
            self.gatherUploadDeletes()
            if self.samplesToDelete.count > 0 {
                _ = self.tryNextUpload()
            } else {
                self.checkStartNextSampleReads()
            }
            
        }
    }
    
    private func checkStartNextSampleReads() {
        DDLogVerbose("(\(uploader.mode.rawValue))")
        var moreToRead = false
        for reader in readers {
            if reader.moreToRead() {
                moreToRead = true
                reader.startReading()
            }
        }
        // for historical upload, if we are done, enter upload stopped state. Otherwise, reading/uploading continues...
        if self.mode == .HistoricalAll && !moreToRead {
            self.stopUploading(reason: .uploadingComplete)
        }
    }
    
    //
    // MARK: - HealthKitUploadReaderDelegate methods
    //
    
    /// Called by each type reader when historical sample range has been determined. The earliest overall sample date is determined, and used for historical progress.
    func uploadReader(reader: HealthKitUploadReader, didUpdateSampleRange startDate: Date, endDate: Date) {
        DDLogVerbose("(\(reader.uploadType.typeName), \(reader.mode.rawValue))")
        if let earliestHistorical = settings.historicalEarliestDate.value {
            if startDate.compare(earliestHistorical) == .orderedAscending {
                settings.historicalEarliestDate.value = startDate
                DDLogVerbose("updated overall earliest sample date from \(earliestHistorical) to \(startDate)")
            }
        } else {
            settings.historicalEarliestDate.value = startDate
            DDLogVerbose("updated overall earliest sample date to \(startDate)")
       }
    }

    // NOTE: This is a query results handler called from HealthKit, but on main thread
    func uploadReader(reader: HealthKitUploadReader, didStop result: ReaderStoppedReason)
    {
        DDLogVerbose("(\(reader.uploadType.typeName), \(reader.mode.rawValue)) result: \(result)) [main thread]")
        
        if self.uploader.hasPendingUploadTasks() {
            // ignore new reader samples while we are uploading... could be a result of an observer query restarting a read, or one of the readers finishing while not in the "isReading" state...
            DDLogInfo("hasPendingUploadTasks, ignoring reader callback...")
            return
        }
        
        var currentReadsComplete = true
        for reader in self.readers {
            if reader.isReading {
                currentReadsComplete = false
            }
        }
        
        // if all readers are complete, see if we have samples or deletes to upload
        guard currentReadsComplete else {
            DDLogVerbose("wait for other reads to complete...")
            return
        }
        
        self.gatherUploadSamples()
        self.gatherUploadDeletes()
        
        guard self.samplesToUpload.count != 0 || self.samplesToDelete.count != 0 else {
            DDLogInfo("No samples or deletes to upload!")
            if self.mode == .HistoricalAll {
                self.stopUploading(reason: .uploadingComplete)
            }
            // for current mode, we keep the observer query active, and leave isUploading true, though all readers will be stopped...
            return
        }
        // will get called back at didCompleteUploadWithError
        self.tryNextUpload()
    }
    
    private func tryNextUpload() {
        do {
            DDLogInfo("Start next upload for \(self.samplesToUpload.count) samples, and \(self.samplesToDelete.count) deleted samples. (\(self.mode))")
            
            // first validate the samples...
            var validatedSamples = [[String: AnyObject]]()
            // Prevent serialization exceptions!
            for sample in self.samplesToUpload {
                //DDLogInfo("Next sample to upload: \(sample)")
                if JSONSerialization.isValidJSONObject(sample) {
                    validatedSamples.append(sample)
                } else {
                    DDLogError("Sample cannot be serialized to JSON!")
                    DDLogError("Sample: \(sample)")
                }
            }
            self.samplesToUpload = validatedSamples
            //print("Next samples to upload: \(samplesToUploadDictArray)")
            DDLogVerbose("Count of samples to upload: \(validatedSamples.count)")
            DDLogInfo("Start next upload for \(self.samplesToUpload.count) samples, and \(self.samplesToDelete.count) deleted samples. (\(self.mode))")

            try self.uploader.startUploadSessionTasks(with: self.samplesToUpload, deletes: self.samplesToDelete)
        } catch let error {
            DDLogError("Failed to prepare upload (\(self.mode)). Error: \(String(describing: error))")
            self.stopUploading(reason: .error(error: error))
        }
    }
    
    
}

