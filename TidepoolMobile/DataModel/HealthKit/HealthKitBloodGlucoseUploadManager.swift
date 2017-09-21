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
    fileprivate override init() {
        DDLogVerbose("trace")
        
        self.phase = HealthKitBloodGlucoseUploadPhase(currentUserId: "")
        self.stats = HealthKitBloodGlucoseUploadStats(phase: phase)
        self.reader = HealthKitBloodGlucoseUploadReader(phase: phase)
        self.uploader = HealthKitBloodGlucoseUploader()
        
        super.init()

        self.uploader.delegate = self
        self.reader.delegate = self
        
        // Check uploader version. If it's changed, then we should reupload everything again. Changing uploader version
        // shouldn't be done lightly, since reuploading lots of data on app upgrade is not ideal. It can be used, though,
        // to fix up 'stats' related to the upload status of the user's store of data, and also to fill gaps if there were
        // samples that were missed during read/upload with past uploader due to bugs.
        let latestUploaderVersion = 6
        let lastExecutedUploaderVersion = UserDefaults.standard.integer(forKey: "lastExecutedUploaderVersion")
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            UserDefaults.standard.set(latestUploaderVersion, forKey: "lastExecutedUploaderVersion")
            resetPersistentData = true
        }
        if resetPersistentData {
            self.resetPersistentState()
        }
    }
    
    func resetPersistentState() {
        self.phase.resetPersistentState()
        self.stats.resetPersistentState()
        self.reader.resetPersistentState()
    }
    
    fileprivate(set) var isUploading = false
    fileprivate(set) var phase: HealthKitBloodGlucoseUploadPhase
    fileprivate(set) var stats: HealthKitBloodGlucoseUploadStats
    
    var makeBloodGlucoseDataUploadRequestHandler: (() throws -> URLRequest) = {
        throw NSError(domain: "HealthKitBloodGlucoseUploadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no user is logged in"])
    }
    
    func startUploading(currentUserId: String) {
        DDLogVerbose("trace")

        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, unable to upload")
            return
        }
        
        self.isUploading = true
        self.phase.currentUserId = currentUserId
        
        HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()
        HealthKitManager.sharedInstance.startObservingBloodGlucoseSamples(self.bloodGlucoseObservationHandler)

        if !self.uploader.hasPendingUploadTasks() {
            DDLogInfo("Start reading samples again after starting upload")
            self.reader.startReading()
        } else {
            DDLogInfo("Don't start reading samples again after starting upload, we still have pending upload tasks")
        }

        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.TurnOnUploader), object: nil))
    }
    
    func stopUploading() {
        DDLogVerbose("trace")
        
        guard self.isUploading else {
            DDLogInfo("Not currently uploading, ignoring")
            return
        }

        self.reader.stopReading()
        self.uploader.cancelTasks()
        
        HealthKitManager.sharedInstance.disableBackgroundDeliveryWorkoutSamples()
        HealthKitManager.sharedInstance.stopObservingBloodGlucoseSamples()
        
        self.isUploading = false
        self.phase.currentUserId = ""

        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil))
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: HealthKitNotifications.TurnOffUploader), object: nil))
    }
    
    // MARK: Upload session coordination (with UIApplicationDelegate)

    func ensureUploadSession(background: Bool) {
        DDLogVerbose("trace")
        
        self.uploader.ensureUploadSession(background: background)        
    }
    
    func handleEventsForBackgroundURLSession(with identifier: String, completionHandler: @escaping () -> Void) {
        DDLogVerbose("trace")

        self.uploader.handleEventsForBackgroundURLSession(with: identifier, completionHandler: completionHandler)
    }
    
    // MARK: Private

    // NOTE: This is a query observer handler called from HealthKit, not on main thread
    fileprivate func bloodGlucoseObservationHandler(_ error: NSError?) {
        DDLogVerbose("trace")

        DispatchQueue.main.async {
            DDLogInfo("bloodGlucoseObservationHandler on main thread")

            guard self.isUploading else {
                DDLogInfo("Not currently uploading, ignoring")
                return
            }
            
            guard error == nil else {
                return
            }
                        
            if !self.uploader.hasPendingUploadTasks() {
                var message = ""
                if !self.reader.isReading {
                    message = "Observed new samples written to HealthKit, read samples from current position and prepare upload"

                    self.reader.startReading()
                    
                    UserDefaults.standard.set(Date(), forKey: "lastAttemptToRead")
                    UserDefaults.standard.synchronize()
                } else {
                    message = "Observed new samples written to HealthKit, already reading samples"
                }
                DDLogInfo(message)
                if AppDelegate.testMode {
                    let localNotificationMessage = UILocalNotification()
                    localNotificationMessage.alertBody = message
                    UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                }
            } else {
                let lastAttemptToRead = UserDefaults.standard.object(forKey: "lastAttemptToRead") as? Date ?? Date()
                let timeAgoInMinutes = round(abs(Date().timeIntervalSince(lastAttemptToRead))) / 60
                if timeAgoInMinutes > 20 {
                    let message = "Observed new samples written to HealthKit, with pending upload tasks. It's been more than 20 minutes. Just cancel any pending tasks and reset pending state, so next time we can start reading/uploading samples again"
                    DDLogInfo(message)
                    if AppDelegate.testMode {
                        let localNotificationMessage = UILocalNotification()
                        localNotificationMessage.alertBody = message
                        UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                    }
                    
                    self.uploader.cancelTasks()
                } else {
                    let message = "Observed new samples written to HealthKit, with pending upload tasks. Don't read samples since we have pending upload tasks."
                    DDLogInfo(message)
                    if AppDelegate.testMode {
                        let localNotificationMessage = UILocalNotification()
                        localNotificationMessage.alertBody = message
                        UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                    }
                }
            }
        }
    }
    
    // NOTE: This is called from a URLSession delegate, not on main thread
    func bloodGlucoseUploader(uploader: HealthKitBloodGlucoseUploader, didCompleteUploadWithError error: Error?) {
        DDLogVerbose("trace")
        
        DispatchQueue.main.async {
            DDLogInfo("didCompleteUploadWithError on main thread")

            if let error = error {
                let message = "Upload batch failed, stop reading, error: \(String(describing: error))"
                DDLogError(message)                
                if AppDelegate.testMode {
                    let localNotificationMessage = UILocalNotification()
                    localNotificationMessage.alertBody = message
                    UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
                }

                self.reader.stopReading()
            } else {
                DDLogError("Upload session succeeded!")
                self.stats.updateForSuccessfulUpload(lastSuccessfulUploadTime: Date())
                self.reader.readMore()
            }
        }
    }
    
    func bloodGlucoseUploaderDidCreateSession(uploader: HealthKitBloodGlucoseUploader) {
        DDLogVerbose("trace")

        if self.isUploading {
            if !self.uploader.hasPendingUploadTasks() {
                DDLogInfo("Start reading samples again after ensuring upload session")
                self.reader.startReading()
            } else {
                DDLogInfo("Don't start reading samples again after ensuring upload session, we still have pending upload tasks")
            }
        }
    }
    
    // NOTE: This is a query results handler called from HealthKit, not on main thread
    func bloodGlucoseReader(reader: HealthKitBloodGlucoseUploadReader, didReadDataForUpload uploadData: HealthKitBloodGlucoseUploadData?, error: Error?)
    {
        DDLogVerbose("trace")
        
        if error != nil {
            DispatchQueue.main.async {
                DDLogInfo("readerResultsHandler on main thread")
                
                DDLogError("stop reading most recent samples, error: \(String(describing: error))")
                self.reader.stopReading()
            }
        } else {
            if let uploadData = uploadData, uploadData.samples.count > 0 {
                self.handleResults(uploadData: uploadData)
            } else {
                self.handleNoResults()
            }
        }
    }

    // NOTE: This is a query results handler called from HealthKit, not on main thread
    fileprivate func handleResults(uploadData: HealthKitBloodGlucoseUploadData) {
        DDLogVerbose("trace")

        do {
            let request = try self.makeBloodGlucoseDataUploadRequestHandler()

            let message = "Start next upload for \(uploadData.samples.count) samples"
            DDLogInfo(message)
            if AppDelegate.testMode {
                let localNotificationMessage = UILocalNotification()
                localNotificationMessage.alertBody = message
                UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
            }

            self.stats.updateForUploadAttempt(sampleCount: uploadData.samples.count, uploadAttemptTime: Date(), earliestSampleTime: uploadData.earliestSampleTime, latestSampleTime: uploadData.latestSampleTime)
            try self.uploader.startUploadSessionTasks(with: request, data: uploadData)
        } catch let error as NSError {
            DDLogError("Failed to prepare upload, error: \(String(describing: error))")
            self.reader.stopReading()
        }
    }

    // NOTE: This is a query results handler called from HealthKit, not on main thread
    fileprivate func handleNoResults() {
        DDLogVerbose("trace")

        DispatchQueue.main.async {
            DDLogInfo("handleNoResults on main thread")
            
            if self.phase.currentPhase == .mostRecent {
                self.reader.readMore()
            } else {
                self.reader.stopReading()
                if self.phase.currentPhase == .historical {
                    self.phase.transitionToPhase(.current)
                }
            }
        }
    }

    fileprivate var reader: HealthKitBloodGlucoseUploadReader
    fileprivate var uploader: HealthKitBloodGlucoseUploader
}
