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
import CocoaLumberjack
import CryptoSwift


class HealthKitUploadManager:
        NSObject,
        URLSessionDelegate,
        URLSessionTaskDelegate
{
    static let sharedInstance = HealthKitUploadManager()
    
    var hasPresentedSyncUI: Bool {
        get {
            return UserDefaults.standard.bool(forKey: HealthKitSettings.HasPresentedSyncUI)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: HealthKitSettings.HasPresentedSyncUI);
        }
    }

    //
    // MARK: Helper class to apply functions to each type of upload data
    //
    class UploadHelper: HealthKitSampleUploaderDelegate, HealthKitUploadReaderDelegate {
        private(set) var uploadType: HealthKitUploadType
        init(_ type: HealthKitUploadType) {
            self.uploadType = type
            DDLogVerbose("helper type: \(uploadType.typeName)")
            // init reader, uploader, stats for the different modes
            self.initForMode(HealthKitUploadReader.Mode.Current)
            self.initForMode(HealthKitUploadReader.Mode.HistoricalLastTwoWeeks)
            self.initForMode(HealthKitUploadReader.Mode.HistoricalAll)
        }
        
        private var readers: [HealthKitUploadReader.Mode: HealthKitUploadReader] = [:]
        private var uploaders: [HealthKitUploadReader.Mode: HealthKitUploader] = [:]
        private(set) var stats: [HealthKitUploadReader.Mode: HealthKitUploadStats] = [:]
        private(set) var isUploading: [HealthKitUploadReader.Mode: Bool] = [:]
        
        private func initForMode(_ mode: HealthKitUploadReader.Mode) {
            self.readers[mode] = HealthKitUploadReader(type: self.uploadType, mode: mode)
            self.readers[mode]!.delegate = self
            self.uploaders[mode] = HealthKitUploader(mode: mode, uploadType: self.uploadType)
            self.uploaders[mode]!.delegate = self
            self.stats[mode] = HealthKitUploadStats(type: self.uploadType, mode: mode)
            self.isUploading[mode] = false
        }
        
        func resetPersistentState(mode: HealthKitUploadReader.Mode) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(mode.rawValue)")
            self.readers[mode]!.resetPersistentState()
            self.stats[mode]!.resetPersistentState()
        }
        
        func startUploading(mode: HealthKitUploadReader.Mode, currentUserId: String) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(mode.rawValue)")
            
            guard !self.isUploading[mode]! else {
                DDLogInfo("Already uploading, ignoring. Mode: \(mode)")
                return
            }
            
            self.isUploading[mode] = true
            self.readers[mode]!.currentUserId = currentUserId
            self.uploaders[mode]!.cancelTasks() // Cancel any pending tasks (also resets pending state, so we don't get stuck not being able to upload due to early termination or crash wherein the persistent state tracking pending uploads was not reset
            
            if (mode == HealthKitUploadReader.Mode.Current) {
                // Observe new samples for Current mode
                HealthKitManager.sharedInstance.enableBackgroundDeliverySamplesForType(uploadType)
                HealthKitManager.sharedInstance.startObservingSamplesForType(uploadType, self.uploadObservationHandler)
            }
            
            var isFreshHistoricalUpload = false
            if mode == HealthKitUploadReader.Mode.HistoricalAll || mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks {
                isFreshHistoricalUpload = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryStartDateKey)) == nil
            }
            
            DDLogInfo("Start reading samples after starting upload. Mode: \(mode)")
            self.readers[mode]!.startReading()
            
            if (isFreshHistoricalUpload) {
                if (mode == HealthKitUploadReader.Mode.HistoricalAll) {
                    // Asynchronously find the start date
                    self.stats[mode]!.updateHistoricalSamplesDateRangeFromHealthKitAsync()
                } else if (mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks) {
                    // The start/end dates for reading HistoricalLastTwoWeeks data are guaranteed to be written by now, so, read those and update the stats
                    let startDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryStartDateKey)) as? Date
                    let endDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryEndDateKey)) as? Date
                    if let startDate = startDate,
                        let endDate = endDate {
                        self.stats[mode]!.updateHistoricalSamplesDateRange(startDate: startDate, endDate: endDate)
                    } else {
                        DDLogError("Unexpected nil startDate or endDate when starting upload. Mode: \(mode)")
                    }
                }
            }
            
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: mode))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.TurnOnUploader), object: mode))
        }
 
        func stopUploading(mode: HealthKitUploadReader.Mode, reason: HealthKitUploadReader.StoppedReason) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(mode.rawValue)")
            
            guard self.isUploading[mode]! else {
                DDLogInfo("Not currently uploading, ignoring. Mode: \(mode)")
                return
            }
            
            DDLogInfo("stopUploading. Mode: \(mode). reason: \(String(describing: reason))")
            
            self.isUploading[mode] = false
            self.readers[mode]!.currentUserId = nil
            
            self.readers[mode]!.stopReading(reason: reason)
            self.uploaders[mode]!.cancelTasks()
            
            if (mode == HealthKitUploadReader.Mode.Current) {
                HealthKitManager.sharedInstance.stopObservingSamplesForType(self.uploadType)
            } else {
                switch reason {
                case .noResultsFromQuery:
                    DDLogInfo("Done uploading. Reset persistent state. Mode: \(mode)")
                    self.resetPersistentState(mode: mode)
                    break
                default:
                    break
                }
            }
            
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: mode))
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.TurnOffUploader), object: mode, userInfo: ["reason": reason]))
        }

        func stopUploading(reason: HealthKitUploadReader.StoppedReason) {
            DDLogVerbose("helper type: \(uploadType.typeName)")
            var mode = HealthKitUploadReader.Mode.Current
            if (self.isUploading[mode]!) {
                self.stopUploading(mode: mode, reason: reason)
            }
            mode = HealthKitUploadReader.Mode.HistoricalLastTwoWeeks
            if (self.isUploading[mode]!) {
                self.stopUploading(mode: mode, reason: reason)
            }
            mode = HealthKitUploadReader.Mode.HistoricalAll
            if (self.isUploading[mode]!) {
                self.stopUploading(mode: mode, reason: reason)
            }
        }

        func resumeUploadingIfResumable(currentUserId: String?) {
            DDLogVerbose("helper type: \(uploadType.typeName)")
            
            var mode = HealthKitUploadReader.Mode.Current
            self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
            mode = HealthKitUploadReader.Mode.HistoricalAll
            self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
            mode = HealthKitUploadReader.Mode.HistoricalLastTwoWeeks
            self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
        }

        private func isResumable(mode: HealthKitUploadReader.Mode) -> Bool {
            return self.readers[mode]!.isResumable()
        }
        
        func resumeUploadingIfResumable(mode: HealthKitUploadReader.Mode, currentUserId: String?) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(mode.rawValue)")
            
            if (currentUserId != nil && !self.isUploading[mode]! && self.isResumable(mode: mode)) {
                if mode == HealthKitUploadReader.Mode.Current {
                    // Always OK to resume Current
                    self.startUploading(mode: mode, currentUserId: currentUserId!)
                } else {
                    // Only resume HistoricalAll and HistoricalTwoWeeks if app is not in background state
                    if UIApplication.shared.applicationState != UIApplicationState.background {
                        self.startUploading(mode: mode, currentUserId: currentUserId!)
                    }
                }
            }
        }


        // NOTE: This is a query observer handler called from HealthKit, not on main thread
        private func uploadObservationHandler(_ error: NSError?) {
            DDLogVerbose("helper type: \(uploadType.typeName)")
            
            DispatchQueue.main.async {
                DDLogInfo("uploadObservationHandler on main thread")
                
                let mode = HealthKitUploadReader.Mode.Current
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
                    UIApplication.localNotifyMessage(message)
                } else {
                    let message = "Observation query called, with pending \(self.uploadType.typeName) upload tasks. Cancel pending tasks. Will then try reading/uploading again"
                    DDLogInfo(message)
                    UIApplication.localNotifyMessage(message)

                    self.uploaders[mode]!.cancelTasks()
                }
            }
        }
        
        // MARK: HealthKitUploadReaderDelegate methods
        
        func uploadReaderDidStartReading(reader: HealthKitUploadReader) {
            // Register background task for Current mode, if in background
            if reader.mode == HealthKitUploadReader.Mode.Current && UIApplication.shared.applicationState == UIApplicationState.background {
                sharedInstance.beginCurrentSamplesUploadBackgroundTask()
            }
        }
        
        // NOTE: This is usually called on a background queue, not on main thread
        func uploadReader(reader: HealthKitUploadReader, didStopReading reason: HealthKitUploadReader.StoppedReason) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(reader.mode.rawValue)")
            
            DispatchQueue.main.async {
                DDLogInfo("didStopReading on main thread")
                
                // End background task for Current mode, if in background
                if reader.mode == HealthKitUploadReader.Mode.Current && UIApplication.shared.applicationState == UIApplicationState.background {
                    sharedInstance.endCurrentSamplesUploadBackgroundTask()
                }
                
                // If the reader mode is HealthKitUploadReader.Mode.Current, then we don't need to stop uploader when the reader
                // stopped reading, we should continue to try reading/uploading again when we observe more samples. Only stop uploading if
                // mode is *not* HealthKitUploadReader.Mode.Current
                if (reader.mode != HealthKitUploadReader.Mode.Current) {
                    if (self.isUploading[reader.mode]!) {
                        self.stopUploading(mode: reader.mode, reason: reason)
                    }
                }
            }
        }
        
        // NOTE: This is usually called on a background queue, not on main thread
        func sampleUploader(uploader: HealthKitUploader, didCompleteUploadWithError error: Error?) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(uploader.mode.rawValue), type: \(uploader.typeString)")
            
            DispatchQueue.main.async {
                DDLogInfo("didCompleteUploadWithError on main thread")
                
                var cancelled = false
                var completed = false
                if let error = error as NSError? {
                    if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                        let message = "Upload task cancelled. Mode: \(uploader.mode), type: \(self.uploadType.typeName)"
                        DDLogError(message)
                        UIApplication.localNotifyMessage(message)
                        cancelled = true
                    } else {
                        let message = "Upload batch failed, stop reading. Mode: \(uploader.mode), type: \(self.uploadType.typeName). Error: \(String(describing: error))"
                        DDLogError(message)
                        UIApplication.localNotifyMessage(message)
                    }
                } else {
                    DDLogError("Upload session succeeded! Mode: \(uploader.mode)")
                    self.stats[uploader.mode]!.updateForSuccessfulUpload(lastSuccessfulUploadTime: Date())
                    self.promoteLastAnchor(reader: self.readers[uploader.mode]!)
                    completed = true
                }
                
                var keepReading = cancelled || completed
                if uploader.mode == HealthKitUploadReader.Mode.Current && UIApplication.shared.applicationState == UIApplicationState.background {
                    if completed {
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
                        self.readers[uploader.mode]!.stopReading(reason: HealthKitUploadReader.StoppedReason.error(error: error))
                    } else {
                        self.readers[uploader.mode]!.stopReading(reason: HealthKitUploadReader.StoppedReason.noResultsFromQuery)
                    }
                }
            }
        }
        
        // NOTE: This is a query results handler called from HealthKit, not on main thread
        func uploadReader(reader: HealthKitUploadReader, didReadDataForUpload uploadData: HealthKitUploadData, error: Error?)
        {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(reader.mode.rawValue), type: \(reader.uploadType.typeName)")
            
            DispatchQueue.main.async {
                DDLogInfo("didReadDataForUpload on main thread")
                
                if let error = error {
                    DDLogError("Stop reading most recent samples. Mode: \(reader.mode). Error: \(String(describing: error))")
                    reader.stopReading(reason: HealthKitUploadReader.StoppedReason.error(error: error))
                } else {
                    guard self.isUploading[reader.mode]! else {
                        DDLogError("Ignore didReadDataForUpload, not currently uploading. Mode: \(reader.mode)")
                        return
                    }
                    
                    if uploadData.filteredSamples.count > 0 || uploadData.deletedSamples.count > 0 {
                        self.handleNewResults(reader: reader, uploadData: uploadData)
                    } else if uploadData.newOrDeletedSamplesWereDelivered {
                        self.promoteLastAnchor(reader: self.readers[reader.mode]!)
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

        fileprivate func handleNewResults(reader: HealthKitUploadReader, uploadData: HealthKitUploadData) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(reader.mode.rawValue), type: \(reader.uploadType.typeName)")
            
            do {
                let message = "Start next upload for \(uploadData.filteredSamples.count) samples. Mode: \(reader.mode), type: \(self.uploadType.typeName)"
                DDLogInfo(message)
                UIApplication.localNotifyMessage(message)

                self.stats[reader.mode]!.updateForUploadAttempt(sampleCount: uploadData.filteredSamples.count, uploadAttemptTime: Date(), earliestSampleTime: uploadData.earliestSampleTime, latestSampleTime: uploadData.latestSampleTime)
                try self.uploaders[reader.mode]!.startUploadSessionTasks(with: uploadData)
            } catch let error {
                DDLogError("Failed to prepare upload. Mode: \(reader.mode). Error: \(String(describing: error))")
                reader.stopReading(reason: HealthKitUploadReader.StoppedReason.error(error: error))
            }
        }
        
        fileprivate func handleNoResults(reader: HealthKitUploadReader) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(reader.mode.rawValue), type: \(reader.uploadType.typeName)")
            
            reader.stopReading(reason: HealthKitUploadReader.StoppedReason.noResultsFromQuery)
        }
        
        fileprivate func promoteLastAnchor(reader: HealthKitUploadReader) {
            DDLogVerbose("helper type: \(uploadType.typeName), mode: \(reader.mode.rawValue), type: \(reader.uploadType.typeName)")
            
            let newAnchor = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: reader.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorLastKey))
            if newAnchor != nil {
                UserDefaults.standard.set(newAnchor, forKey: HealthKitSettings.prefixedKey(prefix: reader.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorKey))
                UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: reader.mode.rawValue, type: uploadType.typeName, key: HealthKitSettings.UploadQueryAnchorLastKey))
                UserDefaults.standard.synchronize()
            }
        }

    }
   
    private var uploadHelpers: [UploadHelper] = []
    
    fileprivate override init() {
        DDLogVerbose("trace")

        super.init()
        for uploadType in appHealthKitConfiguration.healthKitUploadTypes {
            let helper = UploadHelper(uploadType)
            uploadHelpers.append(helper)
        }

        // Reset persistent uploader state if uploader version is upgraded
        let latestUploaderVersion = 7
        let lastExecutedUploaderVersion = UserDefaults.standard.integer(forKey: HealthKitSettings.LastExecutedUploaderVersionKey)
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            UserDefaults.standard.set(latestUploaderVersion, forKey: HealthKitSettings.LastExecutedUploaderVersionKey)
            UserDefaults.standard.synchronize()
            resetPersistentData = true
        }
        if resetPersistentData {
            self.resetPersistentState(switchingHealthKitUsers: false)
        }
    }

    // TODO: decide what to do with stats for other upload data, for now this just returns the stats for the first type... perhaps create an amalamated stats object for all types? Probably need to define UI first to see what we need...
    func statsForMode(_ mode: HealthKitUploadReader.Mode) -> HealthKitUploadStats {
        //
        let firstHelper = uploadHelpers[0]
        return firstHelper.stats[mode]!
    }

    func isUploadInProgressForMode(_ mode: HealthKitUploadReader.Mode) -> Bool {
        var result = false
        for helper in uploadHelpers {
            if helper.isUploading[mode]! {
                result = true
                break
            }
        }
        return result
    }
 
    func resetPersistentStateForMode(_ mode: HealthKitUploadReader.Mode) {
        for helper in uploadHelpers {
            helper.resetPersistentState(mode: mode)
        }
    }

    func resetPersistentState(switchingHealthKitUsers: Bool) {
        DDLogVerbose("trace")

        for helper in uploadHelpers {
            helper.resetPersistentState(mode: HealthKitUploadReader.Mode.Current)
            helper.resetPersistentState(mode: HealthKitUploadReader.Mode.HistoricalLastTwoWeeks)
            helper.resetPersistentState(mode: HealthKitUploadReader.Mode.HistoricalAll)
        }
        
        if switchingHealthKitUsers {
            UserDefaults.standard.removeObject(forKey: HealthKitSettings.HasPresentedSyncUI)
            UserDefaults.standard.synchronize()
        }
    }
    

    var makeDataUploadRequestHandler: ((_ httpMethod: String) throws -> URLRequest) = {_ in
        DDLogVerbose("trace")
        
        throw NSError(domain: "HealthKitUploadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no upload request handler is configured"])
    }
    
    func startUploading(mode: HealthKitUploadReader.Mode, currentUserId: String) {
        DDLogVerbose("mode: \(mode.rawValue)")

        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, unable to upload. Mode: \(mode)")
            return
        }

        APIConnector.connector().configureUploadId() {
            let dataCtl = TidepoolMobileDataController.sharedInstance
            if dataCtl.currentUploadId != nil {
                // first drain any pending timezone change events, then resume HK uploads...
                dataCtl.checkForTimezoneChange()
                dataCtl.postTimezoneEventChanges() {
                    for helper in self.uploadHelpers {
                        helper.startUploading(mode: mode, currentUserId: currentUserId)
                    }
                }
            } else {
                DDLogError("Unable to startUploading - no currentUploadId available!")
            }
        }
        
    }
    
    func stopUploading(mode: HealthKitUploadReader.Mode, reason: HealthKitUploadReader.StoppedReason) {
        DDLogVerbose("mode: \(mode.rawValue)")

        for helper in uploadHelpers {
            helper.stopUploading(mode: mode, reason: reason)
        }
    }
    
    func stopUploading(reason: HealthKitUploadReader.StoppedReason) {
        for helper in uploadHelpers {
            helper.stopUploading(reason: reason)
        }
    }

    func resumeUploadingIfResumable(currentUserId: String?) {
        DDLogVerbose("trace")
        for helper in uploadHelpers {
            helper.resumeUploadingIfResumable(currentUserId: currentUserId)
        }
    }

    func resumeUploadingIfResumable(mode: HealthKitUploadReader.Mode, currentUserId: String?) {
        DDLogVerbose("mode: \(mode.rawValue)")

        for helper in uploadHelpers {
            helper.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
        }

    }
    
    fileprivate func beginCurrentSamplesUploadBackgroundTask() {
        if currentSamplesUploadBackgroundTaskIdentifier == nil {
            self.currentSamplesUploadBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                () -> Void in
                DispatchQueue.main.async {
                    let message = "Background time expired"
                    DDLogInfo(message)
                    UIApplication.localNotifyMessage(message)
                }
            })
            
            DispatchQueue.main.async {
                let message = "Begin background task. Remaining background time: \(UIApplication.shared.backgroundTimeRemaining)"
                DDLogInfo(message)
                UIApplication.localNotifyMessage(message)
            }
        }
    }

    fileprivate func endCurrentSamplesUploadBackgroundTask() {
        if let currentSamplesUploadBackgroundTaskIdentifier = self.currentSamplesUploadBackgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(currentSamplesUploadBackgroundTaskIdentifier)
            self.currentSamplesUploadBackgroundTaskIdentifier = nil

            DispatchQueue.main.async {
                let message = "End background task. Remaining background time: \(UIApplication.shared.backgroundTimeRemaining)"
                DDLogInfo(message)
                UIApplication.localNotifyMessage(message)
            }
        }
    }

    fileprivate var currentSamplesUploadBackgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    
    
}
