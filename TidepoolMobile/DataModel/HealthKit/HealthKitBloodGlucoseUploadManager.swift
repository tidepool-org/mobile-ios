/*
* Copyright (c) 2016, Tidepool Project
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

class HealthKitBloodGlucoseUploadManager:
        NSObject,
        URLSessionDelegate,
        URLSessionTaskDelegate,
        HealthKitBloodGlucoseUploaderDelegate,
        HealthKitBloodGlucoseUploadReaderDelegate
{
    static let sharedInstance = HealthKitBloodGlucoseUploadManager()
    
    fileprivate(set) var stats: [HealthKitBloodGlucoseUploadReader.Mode: HealthKitBloodGlucoseUploadStats] = [:]
    fileprivate(set) var isUploading: [HealthKitBloodGlucoseUploadReader.Mode: Bool] = [:]
    var hasPresentedSyncUI: Bool {
        get {
            return UserDefaults.standard.bool(forKey: HealthKitSettings.HasPresentedSyncUI)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: HealthKitSettings.HasPresentedSyncUI);
        }
    }

    fileprivate override init() {
        DDLogVerbose("trace")

        super.init()
        
        // Init reader, uploader, stats for Mode.Current
        var mode = HealthKitBloodGlucoseUploadReader.Mode.Current
        self.readers[mode] = HealthKitBloodGlucoseUploadReader(mode: mode)
        self.readers[mode]!.delegate = self
        self.uploaders[mode] = HealthKitBloodGlucoseUploader(mode: mode)
        self.uploaders[mode]!.delegate = self
        self.stats[mode] = HealthKitBloodGlucoseUploadStats(mode: mode)
        self.isUploading[mode] = false
        
        // Init reader, uploader, stats for HistoricalLastTwoWeeks
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks
        self.readers[mode] = HealthKitBloodGlucoseUploadReader(mode: mode)
        self.readers[mode]!.delegate = self
        self.uploaders[mode] = HealthKitBloodGlucoseUploader(mode: mode)
        self.uploaders[mode]!.delegate = self
        self.stats[mode] = HealthKitBloodGlucoseUploadStats(mode: mode)
        self.isUploading[mode] = false

        // Init reader, uploader, stats for Mode.HistoricalAll
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll
        self.readers[mode] = HealthKitBloodGlucoseUploadReader(mode: mode)
        self.readers[mode]!.delegate = self
        self.uploaders[mode] = HealthKitBloodGlucoseUploader(mode: mode)
        self.uploaders[mode]!.delegate = self
        self.stats[mode] = HealthKitBloodGlucoseUploadStats(mode: mode)
        self.isUploading[mode] = false

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

    func resetPersistentState(switchingHealthKitUsers: Bool) {
        DDLogVerbose("trace")

        self.resetPersistentState(mode: HealthKitBloodGlucoseUploadReader.Mode.Current)
        self.resetPersistentState(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks)
        self.resetPersistentState(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll)
        
        if switchingHealthKitUsers {
            UserDefaults.standard.removeObject(forKey: HealthKitSettings.HasPresentedSyncUI)
            UserDefaults.standard.synchronize()
        }
    }
    
    func resetPersistentState(mode: HealthKitBloodGlucoseUploadReader.Mode) {
        DDLogVerbose("trace")
        
        self.readers[mode]!.resetPersistentState()
        self.stats[mode]!.resetPersistentState()
    }

    var makeBloodGlucoseDataUploadRequestHandler: (() throws -> URLRequest) = {
        DDLogVerbose("trace")
        
        throw NSError(domain: "HealthKitBloodGlucoseUploadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no upload request handler is configured"])
    }
    
    func startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode, currentUserId: String) {
        DDLogVerbose("trace")

        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, unable to upload. Mode: \(mode)")
            return
        }
        
        guard !self.isUploading[mode]! else {
            DDLogInfo("Alreadg uploading, ignoring. Mode: \(mode)")
            return
        }

        self.isUploading[mode] = true
        self.readers[mode]!.currentUserId = currentUserId
        self.uploaders[mode]!.cancelTasks() // Cancel any pending tasks (also resets pending state, so we don't get stuck not being able to upload due to early termination or crash wherein the persistent state tracking pending uploads was not reset

        if (mode == HealthKitBloodGlucoseUploadReader.Mode.Current) {
            // Observe new samples for Current mode
            HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()
            HealthKitManager.sharedInstance.startObservingBloodGlucoseSamples(self.bloodGlucoseObservationHandler)
        }
        
        var isFreshHistoricalUpload = false
        if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll || mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks {
            isFreshHistoricalUpload = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryStartDateKey)) == nil
        }

        DDLogInfo("Start reading samples after starting upload. Mode: \(mode)")
        self.readers[mode]!.startReading()

        if (isFreshHistoricalUpload) {
            if (mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll) {
                // Asynchronously find the start date
                self.stats[mode]!.updateHistoricalSamplesDateRangeFromHealthKitAsync()
            } else if (mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks) {
                // The start/end dates for reading HistoricalLastTwoWeeks data are guaranteed to be written by now, so, read those and update the stats
                let startDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryStartDateKey)) as? Date
                let endDate = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryEndDateKey)) as? Date
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
    
    func stopUploading(mode: HealthKitBloodGlucoseUploadReader.Mode, reason: HealthKitBloodGlucoseUploadReader.StoppedReason) {
        DDLogVerbose("trace")
        
        guard self.isUploading[mode]! else {
            DDLogInfo("Not currently uploading, ignoring. Mode: \(mode)")
            return
        }

        DDLogInfo("stopUploading. Mode: \(mode). reason: \(String(describing: reason))")

        self.isUploading[mode] = false
        self.readers[mode]!.currentUserId = nil

        self.readers[mode]!.stopReading(reason: reason)
        self.uploaders[mode]!.cancelTasks()

        if (mode == HealthKitBloodGlucoseUploadReader.Mode.Current) {
            HealthKitManager.sharedInstance.disableBackgroundDeliveryWorkoutSamples()
            HealthKitManager.sharedInstance.stopObservingBloodGlucoseSamples()
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
    
    func stopUploading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason) {
        var mode = HealthKitBloodGlucoseUploadReader.Mode.Current
        if (self.isUploading[mode]!) {
            self.stopUploading(mode: mode, reason: reason)
        }
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks
        if (self.isUploading[mode]!) {
            self.stopUploading(mode: mode, reason: reason)
        }
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll
        if (self.isUploading[mode]!) {
            self.stopUploading(mode: mode, reason: reason)
        }        
    }

    func resumeUploadingIfResumable(currentUserId: String?) {
        DDLogVerbose("trace")

        var mode = HealthKitBloodGlucoseUploadReader.Mode.Current
        self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll
        self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks
        self.resumeUploadingIfResumable(mode: mode, currentUserId: currentUserId)
    }

    func isResumable(mode: HealthKitBloodGlucoseUploadReader.Mode) -> Bool {
        return self.readers[mode]!.isResumable()
    }

    func resumeUploadingIfResumable(mode: HealthKitBloodGlucoseUploadReader.Mode, currentUserId: String?) {
        DDLogVerbose("trace")

        if (currentUserId != nil && !self.isUploading[mode]! && self.isResumable(mode: mode)) {
            if mode == HealthKitBloodGlucoseUploadReader.Mode.Current {
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
    
    // MARK: Private

    // NOTE: This is a query observer handler called from HealthKit, not on main thread
    fileprivate func bloodGlucoseObservationHandler(_ error: NSError?) {
        DDLogVerbose("trace")

        DispatchQueue.main.async {
            DDLogInfo("bloodGlucoseObservationHandler on main thread")

            let mode = HealthKitBloodGlucoseUploadReader.Mode.Current
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
                    message = "Observation query called, start reading samples from anchor and prepare upload. Mode: \(mode)"

                    self.readers[mode]!.startReading()
                } else {
                    message = "Observation query called, already reading samples"
                }
                DDLogInfo(message)
                if AppDelegate.testMode {
                    let localNotificationMessage = UILocalNotification()
                    localNotificationMessage.alertBody = message
                    UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                }
            } else {
                let message = "Observation query called, with pending upload tasks. Cancel pending tasks. Will then try reading/uploading again"
                DDLogInfo(message)
                if AppDelegate.testMode {
                    let localNotificationMessage = UILocalNotification()
                    localNotificationMessage.alertBody = message
                    UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                }
                
                self.uploaders[mode]!.cancelTasks()
            }
        }
    }
    
    func bloodGlucoseReaderDidStartReading(reader: HealthKitBloodGlucoseUploadReader) {
        // Register background task for Current mode, if in background
        if reader.mode == HealthKitBloodGlucoseUploadReader.Mode.Current && UIApplication.shared.applicationState == UIApplicationState.background {
            self.beginCurrentSamplesUploadBackgroundTask()
        }
    }

    // NOTE: This is usually called on a background queue, not on main thread
    func bloodGlucoseReader(reader: HealthKitBloodGlucoseUploadReader, didStopReading reason: HealthKitBloodGlucoseUploadReader.StoppedReason) {
        DDLogVerbose("trace")

        DispatchQueue.main.async {
            DDLogInfo("didStopReading on main thread")

            // End background task for Current mode, if in background
            if reader.mode == HealthKitBloodGlucoseUploadReader.Mode.Current && UIApplication.shared.applicationState == UIApplicationState.background {
                self.endCurrentSamplesUploadBackgroundTask()
            }

            // If the reader mode is HealthKitBloodGlucoseUploadReader.Mode.Current, then we don't need to stop uploader when the reader
            // stopped reading, we should continue to try reading/uploading again when we observe more samples. Only stop uploading if
            // mode is *not* HealthKitBloodGlucoseUploadReader.Mode.Current
            if (reader.mode != HealthKitBloodGlucoseUploadReader.Mode.Current) {
                if (self.isUploading[reader.mode]!) {
                    self.stopUploading(mode: reader.mode, reason: reason)
                }
            }
        }
    }

    // NOTE: This is usually called on a background queue, not on main thread
    func bloodGlucoseUploader(uploader: HealthKitBloodGlucoseUploader, didCompleteUploadWithError error: Error?) {
        DDLogVerbose("trace")
        
        DispatchQueue.main.async {
            DDLogInfo("didCompleteUploadWithError on main thread")

            var cancelled = false
            var completed = false
            if let error = error as NSError? {
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    let message = "Upload task cancelled. Mode: \(uploader.mode)"
                    DDLogError(message)
                    if AppDelegate.testMode {
                        let localNotificationMessage = UILocalNotification()
                        localNotificationMessage.alertBody = message
                        UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                    }
                    cancelled = true
                } else {
                    let message = "Upload batch failed, stop reading. Mode: \(uploader.mode). Error: \(String(describing: error))"
                    DDLogError(message)
                    if AppDelegate.testMode {
                        let localNotificationMessage = UILocalNotification()
                        localNotificationMessage.alertBody = message
                        UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                    }
                }
            } else {
                DDLogError("Upload session succeeded! Mode: \(uploader.mode)")
                self.stats[uploader.mode]!.updateForSuccessfulUpload(lastSuccessfulUploadTime: Date())
                self.promoteLastAnchor(reader: self.readers[uploader.mode]!)
                completed = true
            }

            var keepReading = cancelled || completed
            if uploader.mode == HealthKitBloodGlucoseUploadReader.Mode.Current && UIApplication.shared.applicationState == UIApplicationState.background {
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
                    self.readers[uploader.mode]!.stopReading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason.error(error: error))
                } else {
                    self.readers[uploader.mode]!.stopReading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason.noResultsFromQuery)
                }
            }
        }
    }
    
    // NOTE: This is a query results handler called from HealthKit, not on main thread
    func bloodGlucoseReader(reader: HealthKitBloodGlucoseUploadReader, didReadDataForUpload uploadData: HealthKitBloodGlucoseUploadData, error: Error?)
    {
        DDLogVerbose("trace")

        DispatchQueue.main.async {
            DDLogInfo("didReadDataForUpload on main thread")

            if let error = error {
                DDLogError("Stop reading most recent samples. Mode: \(reader.mode). Error: \(String(describing: error))")
                reader.stopReading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason.error(error: error))
            } else {
                guard self.isUploading[reader.mode]! else {
                    DDLogError("Ignore didReadDataForUpload, not currently uploading. Mode: \(reader.mode)")
                    return
                }
                
                if uploadData.filteredSamples.count > 0 {
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

    fileprivate func handleNewResults(reader: HealthKitBloodGlucoseUploadReader, uploadData: HealthKitBloodGlucoseUploadData) {
        DDLogVerbose("trace")

        do {
            let request = try self.makeBloodGlucoseDataUploadRequestHandler()

            let message = "Start next upload for \(uploadData.filteredSamples.count) samples. Mode: \(reader.mode)"
            DDLogInfo(message)
            if AppDelegate.testMode {
                let localNotificationMessage = UILocalNotification()
                localNotificationMessage.alertBody = message
                UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
            }

            self.stats[reader.mode]!.updateForUploadAttempt(sampleCount: uploadData.filteredSamples.count, uploadAttemptTime: Date(), earliestSampleTime: uploadData.earliestSampleTime, latestSampleTime: uploadData.latestSampleTime)
            try self.uploaders[reader.mode]!.startUploadSessionTasks(with: request, data: uploadData)
        } catch let error {
            DDLogError("Failed to prepare upload. Mode: \(reader.mode). Error: \(String(describing: error))")
            reader.stopReading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason.error(error: error))
        }
    }

    fileprivate func handleNoResults(reader: HealthKitBloodGlucoseUploadReader) {
        DDLogVerbose("trace")

        reader.stopReading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason.noResultsFromQuery)
    }
    
    fileprivate func promoteLastAnchor(reader: HealthKitBloodGlucoseUploadReader) {
        DDLogVerbose("trace")

        let newAnchor = UserDefaults.standard.object(forKey: HealthKitSettings.prefixedKey(prefix: reader.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorLastKey))
        if newAnchor != nil {
            UserDefaults.standard.set(newAnchor, forKey: HealthKitSettings.prefixedKey(prefix: reader.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorKey))
            UserDefaults.standard.removeObject(forKey: HealthKitSettings.prefixedKey(prefix: reader.mode.rawValue, key: HealthKitSettings.BloodGlucoseQueryAnchorLastKey))
            UserDefaults.standard.synchronize()
        }
    }

    fileprivate func beginCurrentSamplesUploadBackgroundTask() {
        if currentSamplesUploadBackgroundTaskIdentifier == nil {
            self.currentSamplesUploadBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                () -> Void in
                DispatchQueue.main.async {
                    let message = "Background time expired"
                    DDLogInfo(message)
                    if AppDelegate.testMode {
                        let localNotificationMessage = UILocalNotification()
                        localNotificationMessage.alertBody = message
                        UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                    }
                }
            })
            
            DispatchQueue.main.async {
                let message = "Begin background task. Remaining background time: \(UIApplication.shared.backgroundTimeRemaining)"
                DDLogInfo(message)
                if AppDelegate.testMode {
                    let localNotificationMessage = UILocalNotification()
                    localNotificationMessage.alertBody = message
                    UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                }
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
                if AppDelegate.testMode {
                    let localNotificationMessage = UILocalNotification()
                    localNotificationMessage.alertBody = message
                    UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                }
            }
        }
    }

    fileprivate var readers: [HealthKitBloodGlucoseUploadReader.Mode: HealthKitBloodGlucoseUploadReader] = [:]
    fileprivate var uploaders: [HealthKitBloodGlucoseUploadReader.Mode: HealthKitBloodGlucoseUploader] = [:]
    fileprivate var currentSamplesUploadBackgroundTaskIdentifier: UIBackgroundTaskIdentifier?
}
