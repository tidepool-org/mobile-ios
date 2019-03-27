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

class HealthKitUploadManager:
        NSObject,
        URLSessionDelegate,
        URLSessionTaskDelegate
{
    static let sharedInstance = HealthKitUploadManager()
    let settings = GlobalSettings.sharedInstance
    
    private override init() {
        DDLogVerbose("\(#function)")

        super.init()
        self.configure()
        // Reset persistent uploader state if uploader version is upgraded
        let latestUploaderVersion = 8
        let lastExecutedUploaderVersion = settings.intForKey(.lastExecutedUploaderVersionKey)
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            settings.updateIntForKey(.lastExecutedUploaderVersionKey, value: latestUploaderVersion)
            resetPersistentData = true
        }
        if resetPersistentData {
            self.resetPersistentState(switchingHealthKitUsers: false)
        }
    }

    private func configure() {
        for uploadType in HealthKitConfiguration.sharedInstance!.healthKitUploadTypes {
            let helper = HealthKitUploadHelper(uploadType)
            uploadHelpers.append(helper)
        }
    }
    private var uploadHelpers: [HealthKitUploadHelper] = []

    /// Return array of stats per type for specified mode
    func statsForMode(_ mode: TPUploader.Mode) -> [TPUploaderStats] {
        //
        var allStats: [TPUploaderStats] = []
        for helper in uploadHelpers {
            allStats.append(helper.stats[mode]!.stats)
        }
        return allStats
    }
    
    func isUploadInProgressForMode(_ mode: TPUploader.Mode) -> Bool {
        var result = false
        for helper in uploadHelpers {
            if helper.isUploading[mode]! {
                //print("still uploading for type: \(helper.uploadType.typeName) and mode: \(mode)")
                result = true
                break
            }
        }
        return result
    }
 
    func resetPersistentStateForMode(_ mode: TPUploader.Mode) {
        for helper in uploadHelpers {
            helper.resetPersistentState(mode: mode)
        }
    }

    func resetPersistentState(switchingHealthKitUsers: Bool) {
        DDLogVerbose("\(#function)")

        for helper in uploadHelpers {
            helper.resetPersistentState(mode: TPUploader.Mode.Current)
            helper.resetPersistentState(mode: TPUploader.Mode.HistoricalAll)
        }
        
        if switchingHealthKitUsers {
            settings.removeSettingForKey(.hasPresentedSyncUI)
        }
    }
    
    func startUploading(mode: TPUploader.Mode, currentUserId: String) {
        DDLogVerbose("mode: \(mode.rawValue)")

        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, unable to upload. Mode: \(mode)")
            return
        }

        if TPUploaderServiceAPI.connector?.currentUploadId != nil {
            for helper in self.uploadHelpers {
                helper.startUploading(mode: mode, currentUserId: currentUserId)
            }
        } else {
            DDLogError("Unable to startUploading - no currentUploadId available!")
        }
        
    }
    
    func stopUploading(mode: TPUploader.Mode, reason: TPUploader.StoppedReason) {
        DDLogVerbose("mode: \(mode.rawValue)")

        for helper in uploadHelpers {
            helper.stopUploading(mode: mode, reason: reason)
        }
    }
    
    func stopUploading(reason: TPUploader.StoppedReason) {
        for helper in uploadHelpers {
            helper.stopUploading(reason: reason)
        }
    }

    func resumeUploadingIfResumable(currentUserId: String?) {
        DDLogVerbose("\(#function)")
        if TPUploaderServiceAPI.connector?.currentUploadId != nil {
            for helper in uploadHelpers {
                helper.resumeUploadingIfResumable(currentUserId: currentUserId)
            }
        } else {
            DDLogError("Unable to resumeUploading - no currentUploadId available!")
        }
    }
}

//
// MARK: - Private helper class
//

import UIKit  // for UIApplication...

/// Helper class to apply functions to each type of upload data
private class HealthKitUploadHelper: HealthKitSampleUploaderDelegate, HealthKitUploadReaderDelegate {
    private(set) var uploadType: HealthKitUploadType
    init(_ type: HealthKitUploadType) {
        self.uploadType = type
        DDLogVerbose("(\(uploadType.typeName))")
        // init reader, uploader, stats for the different modes
        self.initForMode(TPUploader.Mode.Current)
        self.initForMode(TPUploader.Mode.HistoricalAll)
    }
    
    private var readers: [TPUploader.Mode: HealthKitUploadReader] = [:]
    private var uploaders: [TPUploader.Mode: HealthKitUploader] = [:]
    private(set) var stats: [TPUploader.Mode: HealthKitUploadStats] = [:]
    private(set) var isUploading: [TPUploader.Mode: Bool] = [:]
    
    private func initForMode(_ mode: TPUploader.Mode) {
        self.readers[mode] = HealthKitUploadReader(type: self.uploadType, mode: mode)
        self.readers[mode]!.delegate = self
        self.uploaders[mode] = HealthKitUploader(mode: mode, uploadType: self.uploadType)
        self.uploaders[mode]!.delegate = self
        self.stats[mode] = HealthKitUploadStats(type: self.uploadType, mode: mode)
        self.isUploading[mode] = false
    }
    
    func resetPersistentState(mode: TPUploader.Mode) {
        DDLogVerbose("helper resetPersistentState: type: \(uploadType.typeName), mode: \(mode.rawValue)")
        self.readers[mode]!.resetPersistentState()
        //self.stats[mode]!.resetPersistentState()
    }
    
    func markNotResumable(mode: TPUploader.Mode) {
        // Clear out the upload reader...
        DDLogVerbose("(\(uploadType.typeName), mode: \(mode.rawValue))")
        self.readers[mode]!.resetPersistentState()
    }
    
    func startUploading(mode: TPUploader.Mode, currentUserId: String) {
        DDLogVerbose("(\(uploadType.typeName), mode: \(mode.rawValue))")
        
        guard !self.isUploading[mode]! else {
            DDLogInfo("Already uploading, ignoring. Mode: \(mode)")
            return
        }
        
        // If upload reader has been reset, ensure stats are also reset!
        if !isResumable(mode: mode) {
            self.stats[mode]!.resetPersistentState()
        }
        
        self.isUploading[mode] = true
        self.readers[mode]!.currentUserId = currentUserId
        self.uploaders[mode]!.cancelTasks() // Cancel any pending tasks (also resets pending state, so we don't get stuck not being able to upload due to early termination or crash wherein the persistent state tracking pending uploads was not reset
        
        if (mode == TPUploader.Mode.Current) {
            // Observe new samples for Current mode
            HealthKitManager.sharedInstance.enableBackgroundDeliverySamplesForType(uploadType)
            HealthKitManager.sharedInstance.startObservingSamplesForType(uploadType, self.uploadObservationHandler)
        }
        
        let isFreshHistoricalUpload = self.readers[mode]!.isFreshHistoricalUpload()
        
        DDLogInfo("Start reading samples after starting upload. Mode: \(mode)")
        self.readers[mode]!.startReading()
        
        if (isFreshHistoricalUpload) {
            if (mode == TPUploader.Mode.HistoricalAll) {
                // Asynchronously find the start date
                self.stats[mode]!.updateHistoricalSamplesDateRangeFromHealthKitAsync()
            }
        }
        
        let uploadInfo : Dictionary<String, Any> = [
            "type" : self.uploadType.typeName,
            "mode" : mode
        ]
        postNotifications([TPUploaderNotifications.Updated, TPUploaderNotifications.TurnOnUploader], mode: mode, uploadInfo: uploadInfo)
    }
    
    private func postNotifications(_ notificationNames: [String], mode: TPUploader.Mode, uploadInfo: Dictionary<String, Any>) {
        for name in notificationNames {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: name), object: mode, userInfo: uploadInfo))
        }
    }

    
    func stopUploading(mode: TPUploader.Mode, reason: TPUploader.StoppedReason) {
        DDLogVerbose("(\(uploadType.typeName), mode: \(mode.rawValue))")

        guard self.isUploading[mode]! else {
            DDLogInfo("Not currently uploading, ignoring. Mode: \(mode)")
            return
        }
        
        DDLogInfo("stopUploading. Mode: \(mode). reason: \(String(describing: reason))")
        
        self.isUploading[mode] = false
        self.readers[mode]!.currentUserId = nil
        
        self.readers[mode]!.stopReading(reason: reason)
        self.uploaders[mode]!.cancelTasks()
        
        if (mode == TPUploader.Mode.Current) {
            HealthKitManager.sharedInstance.stopObservingSamplesForType(self.uploadType)
        } else {
            switch reason {
            case .noResultsFromQuery:
                DDLogInfo("Done uploading. Reset persistent state. Mode: \(mode)")
                self.markNotResumable(mode: mode)
                self.stats[mode]!.updateHistoricalStatsForEndState()
                break
            default:
                break
            }
        }
        
        let uploadInfo : Dictionary<String, Any> = [
            "type" : self.uploadType.typeName,
            "mode" : mode,
            "reason": reason
        ]
        postNotifications([TPUploaderNotifications.Updated, TPUploaderNotifications.TurnOffUploader], mode: mode, uploadInfo: uploadInfo)
    }
    
    func stopUploading(reason: TPUploader.StoppedReason) {
        DDLogVerbose("(\(uploadType.typeName))")
        var mode = TPUploader.Mode.Current
        if (self.isUploading[mode]!) {
            self.stopUploading(mode: mode, reason: reason)
        }
        mode = TPUploader.Mode.HistoricalAll
        if (self.isUploading[mode]!) {
            self.stopUploading(mode: mode, reason: reason)
        }
    }
    
    func resumeUploadingIfResumable(currentUserId: String?) {
        DDLogVerbose("(\(uploadType.typeName))")
        
        var mode = TPUploader.Mode.Current
        self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
        mode = TPUploader.Mode.HistoricalAll
        self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
    }
    
    private func isResumable(mode: TPUploader.Mode) -> Bool {
        return self.readers[mode]!.isResumable()
    }
    
    func resumeUploadingIfResumable(mode: TPUploader.Mode, currentUserId: String?) {
        DDLogVerbose("(\(uploadType.typeName), \(mode.rawValue))")
        
        if (currentUserId != nil && !self.isUploading[mode]! && self.isResumable(mode: mode)) {
            if mode == TPUploader.Mode.Current {
                // Always OK to resume Current
                self.startUploading(mode: mode, currentUserId: currentUserId!)
            } else {
                // Only resume HistoricalAll and HistoricalTwoWeeks if app is not in background state
                if UIApplication.shared.applicationState != UIApplication.State.background {
                    self.startUploading(mode: mode, currentUserId: currentUserId!)
                }
            }
        }
    }
    
    
    // NOTE: This is a query observer handler called from HealthKit, not on main thread
    private func uploadObservationHandler(_ error: NSError?) {
        DDLogVerbose("(\(uploadType.typeName))")
        
        DispatchQueue.main.async {
            DDLogInfo("uploadObservationHandler on main thread")
            
            let mode = TPUploader.Mode.Current
            guard self.isUploading[mode]! else {
                DDLogInfo("Not currently uploading, ignoring")
                return
            }
            
            guard error == nil else {
                return
            }
            
            if self.isUploading[mode]! && !self.uploaders[mode]!.hasPendingUploadTasks() {
                var message = ""
                if !self.readers[mode]!.isReading {
                    message = "Observation query called, start reading \(self.uploadType.typeName) samples from anchor and prepare upload. Mode: \(mode)"
                    
                    self.readers[mode]!.startReading()
                } else {
                    message = "Observation query called, already reading \(self.uploadType.typeName) samples"
                }
                DDLogInfo(message)
                //UIApplication.localNotifyMessage(message)
            } else {
                let message = "Observation query called, with pending \(self.uploadType.typeName) upload tasks. Cancel pending tasks. Will then try reading/uploading again"
                DDLogInfo(message)
                //UIApplication.localNotifyMessage(message)
                
                self.uploaders[mode]!.cancelTasks()
            }
        }
    }
    
    //
    // MARK: - HealthKitSampleUploaderDelegate method
    //
    
    // NOTE: This is usually called on a background queue, not on main thread
    func sampleUploader(uploader: HealthKitUploader, didCompleteUploadWithError error: Error?) {
        DDLogVerbose("(\(uploadType.typeName), \(uploader.mode.rawValue))")
        
        DispatchQueue.main.async {
            DDLogInfo("didCompleteUploadWithError on main thread")
            
            var cancelled = false
            var completed = false
            if let error = error as NSError? {
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    let message = "Upload task cancelled. Mode: \(uploader.mode), type: \(self.uploadType.typeName)"
                    DDLogError(message)
                    //UIApplication.localNotifyMessage(message)
                    cancelled = true
                } else {
                    let message = "Upload batch failed, stop reading. Mode: \(uploader.mode), type: \(self.uploadType.typeName). Error: \(String(describing: error))"
                    DDLogError(message)
                    //UIApplication.localNotifyMessage(message)
                }
            } else {
                DDLogInfo("Upload session succeeded! Mode: \(uploader.mode)")
                self.stats[uploader.mode]!.updateForSuccessfulUpload(lastSuccessfulUploadTime: Date())
                self.readers[uploader.mode]!.promoteLastAnchor()
                completed = true
            }
            
            var keepReading = cancelled || completed
            if uploader.mode == TPUploader.Mode.Current && UIApplication.shared.applicationState == UIApplication.State.background {
                if completed {
                    //TODO: ask Mark why? Doesn't this stop current uploads if the app is in the background for an extended time?
                    keepReading = false // Just do one upload batch per background task for Current mode
                }
            }
            
            if keepReading {
                if self.isUploading[uploader.mode]! {
                    self.readers[uploader.mode]!.readMore()
                } else {
                    DDLogError("Don't try to read more, not currently uploading. Mode: \(uploader.mode)")
                }
            }
            else {
                if let error = error {
                    self.readers[uploader.mode]!.stopReading(reason: TPUploader.StoppedReason.error(error: error))
                } else {
                    self.readers[uploader.mode]!.stopReading(reason: TPUploader.StoppedReason.noResultsFromQuery)
                }
            }
        }
    }
    
    //
    // MARK: - HealthKitUploadReaderDelegate methods
    //
    
    func uploadReaderDidStartReading(reader: HealthKitUploadReader) {
        // Register background task for Current mode, if in background
        if reader.mode == TPUploader.Mode.Current && UIApplication.shared.applicationState == UIApplication.State.background {
            self.beginCurrentSamplesUploadBackgroundTask()
        }
    }
    
    // NOTE: This is usually called on a background queue, not on main thread
    func uploadReader(reader: HealthKitUploadReader, didStopReading reason: TPUploader.StoppedReason) {
        DDLogVerbose("(\(uploadType.typeName), \(reader.mode.rawValue))")
        
        DispatchQueue.main.async {
            DDLogVerbose("(\(self.uploadType.typeName), \(reader.mode.rawValue)) [main thread]")
            
            // End background task for Current mode, if in background
            if reader.mode == TPUploader.Mode.Current && UIApplication.shared.applicationState == UIApplication.State.background {
                self.endCurrentSamplesUploadBackgroundTask()
            }
            
            // If the reader mode is TPUploader.Mode.Current, then we don't need to stop uploader when the reader
            // stopped reading, we should continue to try reading/uploading again when we observe more samples. Only stop uploading if
            // mode is *not* TPUploader.Mode.Current
            if (reader.mode != TPUploader.Mode.Current) {
                if (self.isUploading[reader.mode]!) {
                    self.stopUploading(mode: reader.mode, reason: reason)
                }
            }
        }
    }
    
    // NOTE: This is a query results handler called from HealthKit, not on main thread
    func uploadReader(reader: HealthKitUploadReader, didReadDataForUpload uploadData: HealthKitUploadData, error: Error?)
    {
        DDLogVerbose("(\(uploadType.typeName), \(reader.mode.rawValue))")
        
        DispatchQueue.main.async {
            DDLogVerbose("(\(self.uploadType.typeName), \(reader.mode.rawValue)) [main thread]")
            
            if let error = error {
                DDLogError("Stop reading most recent samples. Mode: \(reader.mode). Error: \(String(describing: error))")
                reader.stopReading(reason: TPUploader.StoppedReason.error(error: error))
            } else {
                guard self.isUploading[reader.mode]! else {
                    DDLogError("Ignore didReadDataForUpload, not currently uploading. Mode: \(reader.mode)")
                    return
                }
                
                if uploadData.filteredSamples.count > 0 || uploadData.deletedSamples.count > 0 {
                    self.handleNewResults(reader: reader, uploadData: uploadData)
                } else if uploadData.newOrDeletedSamplesWereDelivered {
                    self.readers[reader.mode]!.promoteLastAnchor()
                    if self.isUploading[reader.mode]! {
                        self.readers[reader.mode]!.readMore()
                    } else {
                        DDLogError("Don't try to read more, not currently uploading. Mode: \(reader.mode)")
                    }
                } else {
                    self.handleNoResults(reader: reader)
                }
            }
        }
    }
    
    // Note that beginBackgroundTask calls need to be balanced with endBackgroundTask calls!
    private func beginCurrentSamplesUploadBackgroundTask() {
        if currentSamplesUploadBackgroundTaskIdentifier == nil {
            self.currentSamplesUploadBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                () -> Void in
                DispatchQueue.main.async {
                    let message = "Background time expired"
                    DDLogInfo(message)
                    //UIApplication.localNotifyMessage(message)
                }
            })
            
            DispatchQueue.main.async {
                let message = "Begin background task for: \(self.uploadType.typeName). Remaining background time: \(UIApplication.shared.backgroundTimeRemaining)"
                DDLogInfo(message)
                //UIApplication.localNotifyMessage(message)
            }
        }
    }
    
    private func endCurrentSamplesUploadBackgroundTask() {
        if let currentSamplesUploadBackgroundTaskIdentifier = self.currentSamplesUploadBackgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(currentSamplesUploadBackgroundTaskIdentifier)
            self.currentSamplesUploadBackgroundTaskIdentifier = nil
            
            DispatchQueue.main.async {
                let message = "End background task for: \(self.uploadType.typeName). Remaining background time: \(UIApplication.shared.backgroundTimeRemaining)"
                DDLogInfo(message)
                //UIApplication.localNotifyMessage(message)
            }
        }
    }
    
    private var currentSamplesUploadBackgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    //
    // MARK: - Private methods
    //
    
    private func handleNewResults(reader: HealthKitUploadReader, uploadData: HealthKitUploadData) {
        DDLogVerbose("(\(uploadType.typeName), \(reader.mode.rawValue))")
        
        do {
            let message = "Start next upload for \(uploadData.filteredSamples.count) samples, and \(uploadData.deletedSamples.count) deleted samples. Mode: \(reader.mode), type: \(self.uploadType.typeName)"
            DDLogInfo(message)
            
            self.stats[reader.mode]!.updateForUploadAttempt(sampleCount: uploadData.filteredSamples.count, uploadAttemptTime: Date(), earliestSampleTime: uploadData.earliestSampleTime, latestSampleTime: uploadData.latestSampleTime)
            
            try self.uploaders[reader.mode]!.startUploadSessionTasks(with: uploadData)
        } catch let error {
            DDLogError("Failed to prepare upload. Mode: \(reader.mode). Error: \(String(describing: error))")
            reader.stopReading(reason: TPUploader.StoppedReason.error(error: error))
        }
    }
    
    private func handleNoResults(reader: HealthKitUploadReader) {
        DDLogVerbose("(\(uploadType.typeName), \(reader.mode.rawValue))")
        
        reader.stopReading(reason: TPUploader.StoppedReason.noResultsFromQuery)
    }
    
}

