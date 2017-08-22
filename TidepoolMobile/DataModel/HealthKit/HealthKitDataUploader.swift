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

// TODO: my - refactor the settings / user defaults / stats stuff. It's a bit messy and kind of clutters the core logic in the uploader. Maybe split that out to a helper

class HealthKitDataUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    // MARK: Access, authorization
    
    static let sharedInstance = HealthKitDataUploader()
    fileprivate override init() {
        DDLogVerbose("trace")

        super.init()
        
        let latestUploaderVersion = 4
        let lastExecutedUploaderVersion = UserDefaults.standard.integer(forKey: "lastExecutedUploaderVersion")
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            UserDefaults.standard.set(latestUploaderVersion, forKey: "lastExecutedUploaderVersion")
            UserDefaults.standard.synchronize()
            resetPersistentData = true
        }
        
        // Start off assuming background sessions. When app is made active after launch we'll switch to non-background session
        ensureUploadSession(background: true)
        
        initState(resetPersistentData)
     }
    
    fileprivate func initState(_ resetUser: Bool = false) {
        if resetUser {
            UserDefaults.standard.removeObject(forKey: "bloodGlucoseQueryAnchor")
            UserDefaults.standard.removeObject(forKey: "bloodGlucoseUploadRecentEndDate")
            UserDefaults.standard.removeObject(forKey: "bloodGlucoseUploadRecentStartDate")
            UserDefaults.standard.removeObject(forKey: "bloodGlucoseUploadRecentStartDateFinal")
            UserDefaults.standard.removeObject(forKey: "uploadPhaseBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "lastUploadTimeBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "lastUploadSampleTimeBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "startDateHistoricalBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "endDateHistoricalBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "totalDaysHistoricalBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "currentDayHistoricalBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountBloodGlucoseSamples")
            
            UserDefaults.standard.removeObject(forKey: "workoutQueryAnchor")
            
            UserDefaults.standard.synchronize()
            
            DDLogInfo("Upload settings have been reset anchor during migration")
        }
        
        var phase = Phases.mostRecentSamples
        let persistedPhase = UserDefaults.standard.object(forKey: "uploadPhaseBloodGlucoseSamples")
        if persistedPhase != nil {
            phase = HealthKitDataUploader.Phases(rawValue: (persistedPhase! as AnyObject).intValue)!

            let lastUploadTimeBloodGlucoseSamples = UserDefaults.standard.object(forKey: "lastUploadTimeBloodGlucoseSamples") as? Date
            let lastUploadSampleTimeBloodGlucoseSamples = UserDefaults.standard.object(forKey: "lastUploadSampleTimeBloodGlucoseSamples") as? Date
            self.lastUploadTimeBloodGlucoseSamples = lastUploadTimeBloodGlucoseSamples ?? Date.distantPast
            self.lastUploadSampleTimeBloodGlucoseSamples = lastUploadSampleTimeBloodGlucoseSamples ?? Date.distantPast

            let startDateHistoricalBloodGlucoseSamples = UserDefaults.standard.object(forKey: "startDateHistoricalBloodGlucoseSamples") as? Date
            let endDateHistoricalBloodGlucoseSamples = UserDefaults.standard.object(forKey: "endDateHistoricalBloodGlucoseSamples") as? Date
            self.startDateHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples ?? Date.distantPast
            self.endDateHistoricalBloodGlucoseSamples = endDateHistoricalBloodGlucoseSamples ?? Date.distantPast
            self.totalDaysHistoricalBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalDaysHistoricalBloodGlucoseSamples")
            self.currentDayHistoricalBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "currentDayHistoricalBloodGlucoseSamples")
            
            self.totalUploadCountBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalUploadCountBloodGlucoseSamples")
        } else {
            self.lastUploadTimeBloodGlucoseSamples = Date.distantPast
            self.lastUploadSampleTimeBloodGlucoseSamples = Date.distantPast
            
            self.startDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.endDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.totalDaysHistoricalBloodGlucoseSamples = 0
            self.currentDayHistoricalBloodGlucoseSamples = 0
            
            self.totalUploadCountBloodGlucoseSamples = 0
        }
        
        self.transitionToPhase(phase)
    }

    enum Notifications {
        // NOTE: This is not very granular, but, not clear yet that clients need more granularity. This 'Updated' notification
        // covers the following: start/stop uploading, samples uploaded, user reset (switch users), transition between
        // uploader phases (e.g. most recent last two weeks, initial historical sample upload, and final phase of 
        // just keeping up with ongoing uploading of new samples), etc
        static let Updated = "HealthKitDataUpload-updated"
    }
    
    enum Phases: Int {
        case mostRecentSamples
        case historicalSamples
        case currentSamples
    }
    
    fileprivate(set) var isUploading = false
    fileprivate(set) var uploadPhaseBloodGlucoseSamples = Phases.mostRecentSamples
    fileprivate(set) var lastUploadTimeBloodGlucoseSamples = Date.distantPast
    fileprivate(set) var totalDaysHistoricalBloodGlucoseSamples = 0
    fileprivate(set) var currentDayHistoricalBloodGlucoseSamples = 0
    fileprivate(set) var totalUploadCountBloodGlucoseSamples = 0
    
    var uploadHandler: ((_ batchMetadataPostBodyURL: URL, _ batchSamplesPostBodyURL: URL) throws -> Void) = {(batchMetadataPostBodyURL, batchSamplesPostBodyURL) in }
    
    func startUploading(currentUserId: String?) {
        DDLogVerbose("trace")
        guard currentUserId != nil else {
            DDLogInfo("No logged in user, unable to upload")
            return
        }
        
        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, ignoring request to upload")
            return
        }
        
        isUploading = true

        // Remember the user id for the uploads
        self.currentUserId = currentUserId
        
        // Start observing samples. We don't really start uploading until we've successsfully started observing
        HealthKitManager.sharedInstance.startObservingBloodGlucoseSamples(self.bloodGlucoseObservationHandler)

        DDLogInfo("start reading samples - start uploading")
        self.startReadingSamples()

        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Notifications.Updated), object: nil))
    }
    
    func stopUploading() {
        DDLogVerbose("trace")
        
        guard self.isUploading else {
            DDLogInfo("Not currently uploading, ignoring")
            return
        }
        
        HealthKitManager.sharedInstance.disableBackgroundDeliveryWorkoutSamples()
        HealthKitManager.sharedInstance.stopObservingBloodGlucoseSamples()

        self.stopReadingSamples()
        self.currentUserId = nil
        self.currentSamplesToUpload = [HKSample]()
        self.currentSamplesToUploadLatestSampleTime = Date.distantPast
        self.currentBatchUploadDict = [String: AnyObject]()
        
        self.isUploading = false

        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Notifications.Updated), object: nil))
    }

    // TODO: review; should only be called when a non-current HK user is logged in!
    func resetHealthKitUploaderForNewUser() {
        DDLogVerbose("Switching healthkit user, need to reset anchors!")
        initState(true)
    }    
    
    // MARK: Background upload session support
    
    func startUploadSession(with batchMetadataPostRequest: URLRequest, batchMetadataPostBodyURL: URL, batchSamplesPostRequest: URLRequest, batchSamplesPostBodyURL: URL) throws {
        DDLogVerbose("trace")
        
        guard self.uploadSession != nil else {
            let error = NSError(domain: "HealthKitDataUploader", code: -1, userInfo: [NSLocalizedDescriptionKey:"Unable to upload, session does not exist, it was probably invalidated, will try again next time we are notified of new samples"])
            throw error
        }

        let batchMetadataUploadTask = self.uploadSession!.uploadTask(with: batchMetadataPostRequest, fromFile: batchMetadataPostBodyURL)
        DDLogInfo("Created task: \(batchMetadataUploadTask.taskIdentifier)")
        let batchSamplesUploadTask = self.uploadSession!.uploadTask(with: batchSamplesPostRequest, fromFile: batchSamplesPostBodyURL)
        DDLogInfo("Created task: \(batchSamplesUploadTask.taskIdentifier)")
        
        DDLogInfo("Resuming task: \(batchMetadataUploadTask.taskIdentifier)")
        batchMetadataUploadTask.resume()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DDLogVerbose("trace")
        
        if error != nil {
            DDLogInfo("task completed: \(task.taskIdentifier), with error: \(error!)")
        } else {
            DDLogInfo("task completed: \(task.taskIdentifier)")
        }
        
        DispatchQueue.main.async {
            if error != nil {
                DDLogError("Background upload session failed: \(String(describing: error))")

                self.stopReadingSamples()
            } else {
                self.uploadSession!.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                    DispatchQueue.main.async {
                        if uploadTasks.count == 0 {
                            self.updateStats()
                            self.readMore()
                        } else {
                            DDLogInfo("Resuming task: \(uploadTasks[0].taskIdentifier)")
                            uploadTasks[0].resume()
                        }
                    }
                }
            }
        }
    }
    
    func handleEventsForBackgroundURLSession(with identifier: String, completionHandler: @escaping () -> Void) {
        DDLogVerbose("trace")
        
        DispatchQueue.main.async {
            if identifier == self.backgroundUploadSessionIdentifier {
                self.uploadSessionCompletionHandler = completionHandler
                
                self.uploadSession!.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                    if uploadTasks.count > 0 {
                        DDLogInfo("Resuming task: \(uploadTasks[0].taskIdentifier)")
                        uploadTasks[0].resume()
                    }
                }
            }
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DDLogVerbose("trace")
        
        if self.uploadSessionCompletionHandler != nil {
            self.uploadSessionCompletionHandler!()
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DDLogVerbose("trace")
    }

    func ensureUploadSession(background: Bool) {
        DDLogVerbose("trace")
        
        if self.uploadSession == nil {
            self.uploadSessionIsBackground = background
            
            // Create upload session
            var configuration: URLSessionConfiguration?
            if background {
                configuration = URLSessionConfiguration.background(withIdentifier: self.backgroundUploadSessionIdentifier)
            } else {
                configuration = URLSessionConfiguration.default
            }
            self.uploadSession = URLSession(configuration: configuration!, delegate: self, delegateQueue: nil)
            self.uploadSession!.delegateQueue.maxConcurrentOperationCount = 1
            DDLogVerbose("created upload session, background: \(background)")
        } else {
            if background != self.uploadSessionIsBackground {
                self.uploadSessionIsBackground = background
                
                // Invalidate upload session
                DDLogVerbose("invalidating upload session, background: \(background)")
                self.uploadSession!.invalidateAndCancel()
                self.uploadSession = nil

                // Make sure to setup session again after it becomes invalid
                ensureUploadSession(background: self.uploadSessionIsBackground)
                
                // Start reading samples again after ensuring upload session
                self.stopReadingSamples()
                if self.isUploading {
                    self.startReadingSamples()
                }
            }
        }
    }
    
    // MARK: Private - observation and results handlers

    fileprivate func bloodGlucoseObservationHandler(_ error: NSError?) {
        DDLogVerbose("trace")

        if error == nil {
            DispatchQueue.main.async(execute: {
                guard self.isUploading else {
                    DDLogInfo("Not currently uploading, ignoring")
                    return
                }

                HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()

                DDLogInfo("start reading samples - started observing blood glucose samples")
                self.startReadingSamples()
            })
        }
    }
    
    fileprivate func bloodGlucoseResultsHandler(_ error: NSError?, newSamples: [HKSample]?, newAnchor: HKQueryAnchor?) {
        DDLogVerbose("trace")
        
        guard self.isUploading else {
            DDLogInfo("Not currently uploading, ignoring")
            return
        }

        var samplesAvailableToUpload = false

        defer {
            if !samplesAvailableToUpload {
                self.handleNoResultsToUpload(error: error)
            }
        }
        
        guard error == nil else {
            return
        }
        
        guard let samples = newSamples, samples.count > 0 else {
            return
        }

        self.prepareSamplesForUpload(samples)
        if self.currentSamplesToUpload.count > 0 {
            samplesAvailableToUpload = true

            let queryAnchorData = newAnchor != nil ? NSKeyedArchiver.archivedData(withRootObject: newAnchor!) : nil
            UserDefaults.standard.set(queryAnchorData, forKey: "bloodGlucoseQueryAnchorTemp")
            UserDefaults.standard.set(currentSamplesToUpload.count, forKey: "bloodGlucoseCurrentSamplesToUploadCount")
            UserDefaults.standard.synchronize()

            DDLogInfo("Start next upload for \(self.currentSamplesToUpload.count) samples")
            startBatchUpload(samples: samples)
        }
    }
 
    // MARK: Private - upload

    fileprivate func startBatchUpload(samples: [HKSample]) {
        DDLogVerbose("trace")
        
        let firstSample = samples[0]
        let sourceRevision = firstSample.sourceRevision
        let source = sourceRevision.source
        let sourceBundleIdentifier = source.bundleIdentifier
        let deviceModel = deviceModelForSourceBundleIdentifier(sourceBundleIdentifier)
        let deviceId = "\(deviceModel)_\(UIDevice.current.identifierForVendor!.uuidString)"
        let timeZoneOffset = NSCalendar.current.timeZone.secondsFromGMT() / 60
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        let version = "\(appBundleIdentifier):\(appVersion)-\(appBuild)"
        let dateFormatter = DateFormatter()
        let now = Date()
        let time = DateFormatter().isoStringFromDate(now)
        let guid = UUID().uuidString
        let uploadIdSuffix = "\(deviceId)_\(time)_\(guid)"
        let uploadIdSuffixMd5Hash = uploadIdSuffix.md5()
        let uploadId = "upid_\(uploadIdSuffixMd5Hash)"
        
        self.currentBatchUploadDict = [String: AnyObject]()
        self.currentBatchUploadDict["type"] = "upload" as AnyObject?
        self.currentBatchUploadDict["uploadId"] = uploadId as AnyObject?
        self.currentBatchUploadDict["computerTime"] = dateFormatter.isoStringFromDate(now, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone) as AnyObject?
        self.currentBatchUploadDict["time"] = time as AnyObject?
        self.currentBatchUploadDict["timezoneOffset"] = timeZoneOffset as AnyObject?
        self.currentBatchUploadDict["timezone"] = TimeZone.autoupdatingCurrent.identifier as AnyObject?
        self.currentBatchUploadDict["timeProcessing"] = "none" as AnyObject?
        self.currentBatchUploadDict["version"] = version as AnyObject?
        self.currentBatchUploadDict["guid"] = guid as AnyObject?
        self.currentBatchUploadDict["byUser"] = currentUserId as AnyObject?
        self.currentBatchUploadDict["deviceTags"] = ["cgm"] as AnyObject?
        self.currentBatchUploadDict["deviceManufacturers"] = ["Dexcom"] as AnyObject?
        self.currentBatchUploadDict["deviceSerialNumber"] = "" as AnyObject?
        self.currentBatchUploadDict["deviceModel"] = deviceModel as AnyObject?
        self.currentBatchUploadDict["deviceId"] = deviceId as AnyObject?

        do {
            // Prepare batchMetadataPostBody
            let batchMetadataPostBody = try JSONSerialization.data(withJSONObject: self.currentBatchUploadDict, options: JSONSerialization.WritingOptions.prettyPrinted)
            if defaultDebugLevel != DDLogLevel.off {
                let postBodyString = NSString(data: batchMetadataPostBody, encoding: String.Encoding.utf8.rawValue)! as String
                DDLogVerbose("Start batch upload JSON: \(postBodyString)")
            }
            let batchMetadataPostBodyURL = try savePostBodyForUpload(body: batchMetadataPostBody, identifier: "uploadBatchMetadata.data")

            // Prepare post body for samples upload, which will be kicked off once batch metadata is sent
            let batchSamplesPostBodyURL = try preparePostBodyForBatchSamplesUpload(samples: samples)
            
            try self.uploadHandler(batchMetadataPostBodyURL, batchSamplesPostBodyURL)
        } catch {
            let error = NSError(domain: "HealthKitDataUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
            DDLogError("stop reading samples - error preparing upload for start of batch upload: \(error)")
            self.stopReadingSamples()
        }
    }
    
    fileprivate func preparePostBodyForBatchMetadataUpload(samples: [HKSample]) throws -> URL {
        let postBody = try JSONSerialization.data(withJSONObject: self.currentBatchUploadDict, options: JSONSerialization.WritingOptions.prettyPrinted)
        if defaultDebugLevel != DDLogLevel.off {
            let postBodyString = NSString(data: postBody, encoding: String.Encoding.utf8.rawValue)! as String
            DDLogVerbose("Start batch upload JSON: \(postBodyString)")
        }
        return try savePostBodyForUpload(body: postBody, identifier: "uploadBatchMetadata.data")
    }
    
    fileprivate func preparePostBodyForBatchSamplesUpload(samples: [HKSample]) throws -> URL {
        DDLogVerbose("trace")

        // Prepare upload post body
        let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in samples {
            var sampleToUploadDict = [String: AnyObject]()
            
            sampleToUploadDict["uploadId"] = self.currentBatchUploadDict["uploadId"]
            sampleToUploadDict["type"] = "cbg" as AnyObject?
            sampleToUploadDict["deviceId"] = self.currentBatchUploadDict["deviceId"]
            sampleToUploadDict["guid"] = sample.uuid.uuidString as AnyObject?
            sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
            
            if let quantitySample = sample as? HKQuantitySample {
                let units = "mg/dL"
                sampleToUploadDict["units"] = units as AnyObject?
                let unit = HKUnit(from: units)
                let value = quantitySample.quantity.doubleValue(for: unit)
                sampleToUploadDict["value"] = value as AnyObject?
                
                // Add out-of-range annotation if needed
                var annotationCode: String?
                var annotationValue: String?
                var annotationThreshold = 0
                if (value < 40) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "low"
                    annotationThreshold = 40
                } else if (value > 400) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "high"
                    annotationThreshold = 400
                }
                if let annotationCode = annotationCode,
                       let annotationValue = annotationValue {
                    let annotations = [
                        [
                            "code": annotationCode,
                            "value": annotationValue,
                            "threshold": annotationThreshold
                        ]
                    ]
                    sampleToUploadDict["annotations"] = annotations as AnyObject?
                }
            }
            
            // Add sample metadata payload props
            if var metadata = sample.metadata {
                for (key, value) in metadata {
                    if let dateValue = value as? Date {
                        if key == "Receiver Display Time" {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                            
                        } else {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                        }
                    }
                }
                
                // If "Receiver Display Time" exists, use that as deviceTime and remove from metadata payload
                if let receiverDisplayTime = metadata["Receiver Display Time"] {
                    sampleToUploadDict["deviceTime"] = receiverDisplayTime as AnyObject?
                    metadata.removeValue(forKey: "Receiver Display Time")
                }
                sampleToUploadDict["payload"] = metadata as AnyObject?
            }
            
            // Add sample
            samplesToUploadDictArray.append(sampleToUploadDict)
        }

        let postBody = try JSONSerialization.data(withJSONObject: samplesToUploadDictArray, options: JSONSerialization.WritingOptions.prettyPrinted)
        if defaultDebugLevel != DDLogLevel.off {
            let postBodyString = NSString(data: postBody, encoding: String.Encoding.utf8.rawValue)! as String
            DDLogVerbose("Samples to upload: \(postBodyString)")
        }
        
        return try savePostBodyForUpload(body: postBody, identifier: "uploadBatchSamples.data")
    }
    
    fileprivate func savePostBodyForUpload(body: Data, identifier: String) throws -> URL {
        let postBodyURL = getUploadURLForIdentifier(with: identifier)

        try body.write(to: postBodyURL, options: .atomic)
        
        return postBodyURL
    }
    
    fileprivate func getUploadURLForIdentifier(with identifier: String) -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let postBodyURL = cachesDirectory.appendingPathComponent(identifier)
        return postBodyURL
    }

    fileprivate func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        var deviceModel = ""
        
        if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.cgm") != nil {
            deviceModel = "DexG5"
        } else if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.share2") != nil {
            deviceModel = "DexG4"
        } else {
            DDLogError("Unknown Dexcom sourceBundleIdentifier: \(sourceBundleIdentifier)")
            deviceModel = "DexUnknown"
        }
        
        return "HealthKit_\(deviceModel)"
    }
    
    fileprivate func prepareSamplesForUpload(_ samples: [HKSample]) {
        DDLogVerbose("trace")

        // Sort by sample date
        let sortedSamples = samples.sorted(by: {x, y in
            return x.startDate.compare(y.startDate) == .orderedAscending
        })

        // Filter out non-Dexcom data and compute latest sample time for batch
        var filteredSamples = [HKSample]()
        var latestSampleTime = Date.distantPast
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            if source.name.lowercased().range(of: "dexcom") == nil {
                DDLogInfo("Ignoring non-Dexcom glucose data")
                continue
            }
            
            filteredSamples.append(sample)
            if sample.startDate.compare(latestSampleTime) == .orderedDescending {
                latestSampleTime = sample.startDate
            }
        }
        
        self.currentSamplesToUpload = filteredSamples
        self.currentSamplesToUploadLatestSampleTime = latestSampleTime
    }
    
    // MARK: Private - upload phases (most recent, historical, current)
    
    fileprivate func startReadingSamples() {
        DDLogVerbose("trace")

        DispatchQueue.main.async(execute: {
            guard self.uploadSession != nil else {
                DDLogVerbose("Ignoring request to start reading samples, no uploadSesion exists yet")
                return
            }

            self.uploadSession!.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                DispatchQueue.main.async {
                    guard uploadTasks.count == 0 else {
                        DDLogVerbose("Ignoring request to start reading samples, upload session has pending tasks")
                        return
                    }
                    
                    guard !self.isReadingMostRecentSamples && !self.isReadingSamplesFromAnchor else {
                        DDLogVerbose("Ignoring request to start reading samples, already reading samples")
                        return
                    }
                    
                    if self.uploadPhaseBloodGlucoseSamples == .mostRecentSamples {
                        self.startReadingMostRecentSamples()
                    } else {
                        self.startReadingSamplesFromAnchor()
                    }
                }
            }
        })
    }
    
    fileprivate func stopReadingSamples() {
        DDLogVerbose("trace")

        // Stop reading samples
        self.isReadingMostRecentSamples = false
        self.isReadingSamplesFromAnchor = false
        
        // Cancel any background upload session tasks
        if self.uploadSession != nil {
            self.uploadSession!.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                for uploadTask in uploadTasks {
                    DDLogInfo("Canceling task: \(uploadTask.taskIdentifier)")
                    uploadTask.cancel()
                }
            }
        }
    }
    
    fileprivate func handleNoResultsToUpload(error: NSError?) {
        DDLogVerbose("trace")

        DispatchQueue.main.async(execute: {
            if self.isReadingMostRecentSamples {
                if error == nil {
                    self.readMore()
                } else {
                    DDLogInfo("stop reading most recent samples due to error: \(String(describing: error))")
                    self.stopReadingSamples()
                }
            } else if self.isReadingSamplesFromAnchor {
                if error == nil {
                    DDLogInfo("stop reading samples from anchor - no new samples available to upload")
                    self.stopReadingSamples()
                    self.transitionToPhase(.currentSamples)
                } else {
                    DDLogInfo("stop reading samples from anchor due to error: \(String(describing: error))")
                    self.stopReadingSamples()
                }
            }
        })
    }
    
    fileprivate func readMore() {
        DDLogVerbose("trace")
        
        DispatchQueue.main.async(execute: {
            if self.isReadingMostRecentSamples {
                self.stopReadingSamples()
                let bloodGlucoseUploadRecentEndDate = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDate") as! Date
                let bloodGlucoseUploadRecentStartDate = bloodGlucoseUploadRecentEndDate.addingTimeInterval(-60 * 60 * 8)
                let bloodGlucoseUploadRecentStartDateFinal = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDateFinal") as! Date
                if bloodGlucoseUploadRecentEndDate.compare(bloodGlucoseUploadRecentStartDateFinal) == .orderedAscending {
                    DDLogInfo("finished reading most recent samples")
                    self.transitionToPhase(.historicalSamples)
                }
                else {
                    UserDefaults.standard.set(bloodGlucoseUploadRecentStartDate, forKey: "bloodGlucoseUploadRecentStartDate")
                    UserDefaults.standard.set(bloodGlucoseUploadRecentEndDate, forKey: "bloodGlucoseUploadRecentEndDate")
                    UserDefaults.standard.synchronize()
                }
            } else if self.isReadingSamplesFromAnchor {
                self.stopReadingSamples()
                let newAnchor = UserDefaults.standard.object(forKey: "bloodGlucoseQueryAnchorTemp")
                if newAnchor != nil {
                    UserDefaults.standard.set(newAnchor, forKey: "bloodGlucoseQueryAnchor")
                    UserDefaults.standard.synchronize()
                }
            }
            self.startReadingSamples()
        })
    }

    fileprivate func startReadingSamplesFromAnchor() {
        DDLogVerbose("trace")

        self.isReadingSamplesFromAnchor = true
        
        // Update historical samples date range every time we start reading samples from anchor so
        // that we can have most up-to-date date range, in case there are writers to HealthKit during
        // the historical data upload phase.
        updateHistoricalSamplesDateRangeAsync()
        
        let limit = 288 // 1 day of samples if 5 minute intervals
        HealthKitManager.sharedInstance.readBloodGlucoseSamplesFromAnchor(limit: limit, resultsHandler: self.bloodGlucoseResultsHandler)
    }
    
    fileprivate func startReadingMostRecentSamples() {
        DDLogVerbose("trace")
        
        self.isReadingMostRecentSamples = true
        
        let now = Date()
        let eightHoursAgo = now.addingTimeInterval(-60 * 60 * 8)
        let twoWeeksAgo = now.addingTimeInterval(-60 * 60 * 24 * 14)
        var bloodGlucoseUploadRecentEndDate = now
        var bloodGlucoseUploadRecentStartDate = eightHoursAgo
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
        
        // Do this here so we have are more likely to have the days range ready for progress UI when 
        // we enter the historical samples phase
        updateHistoricalSamplesDateRangeAsync()

        let limit = 288 // 1 day of samples if 5 minute intervals
        HealthKitManager.sharedInstance.readBloodGlucoseSamples(startDate: bloodGlucoseUploadRecentStartDate, endDate: bloodGlucoseUploadRecentEndDate, limit: limit, resultsHandler: self.bloodGlucoseResultsHandler)
    }
    
    fileprivate func transitionToPhase(_ phase: Phases) {
        DDLogInfo("transitioning to \(phase)")
        self.uploadPhaseBloodGlucoseSamples = phase
        UserDefaults.standard.set(phase.rawValue, forKey: "uploadPhaseBloodGlucoseSamples")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Notifications.Updated), object: nil))
    }
    
    // MARK: Private - stats
    
    fileprivate func updateHistoricalSamplesDateRangeAsync() {
        DDLogVerbose("trace")
        
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {            
            (error: NSError?, startDate: Date?, endDate: Date?) in
            guard self.isUploading else {
                DDLogInfo("Not currently uploading, ignoring")
                return
            }

            if error == nil && startDate != nil && endDate != nil {
                DDLogInfo("Updated historical samples date range")
                
                self.startDateHistoricalBloodGlucoseSamples = startDate!
                UserDefaults.standard.set(startDate, forKey: "startDateHistoricalBloodGlucoseSamples")
                
                self.endDateHistoricalBloodGlucoseSamples = endDate!
                UserDefaults.standard.set(endDate, forKey: "endDateHistoricalBloodGlucoseSamples")
                
                UserDefaults.standard.synchronize()
            }
        }
    }

    fileprivate func updateStats() {
        DDLogVerbose("trace")

        guard currentBatchUploadDict.count > 0 else {
            DDLogVerbose("No need to update stats, no batch upload available")
            return
        }
        
        let sampleCount = UserDefaults.standard.integer(forKey: "bloodGlucoseCurrentSamplesToUploadCount")
        totalUploadCountBloodGlucoseSamples += sampleCount
        
        DDLogInfo("Successfully uploaded \(sampleCount) samples.\n")

        lastUploadTimeBloodGlucoseSamples = DateFormatter().dateFromISOString(currentBatchUploadDict["time"] as! String)!
        
        if uploadPhaseBloodGlucoseSamples == .historicalSamples {
            if self.lastUploadSampleTimeBloodGlucoseSamples.compare(currentSamplesToUploadLatestSampleTime) == .orderedAscending {
                self.lastUploadSampleTimeBloodGlucoseSamples = currentSamplesToUploadLatestSampleTime
            }
            if startDateHistoricalBloodGlucoseSamples.compare(endDateHistoricalBloodGlucoseSamples) == .orderedAscending {
                totalDaysHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples.differenceInDays(endDateHistoricalBloodGlucoseSamples) + 1
                currentDayHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples.differenceInDays(lastUploadSampleTimeBloodGlucoseSamples) + 1
                DDLogInfo(
                    "Uploaded \(currentDayHistoricalBloodGlucoseSamples) of \(totalDaysHistoricalBloodGlucoseSamples) days of historical data");
            }
            
        }
        
        UserDefaults.standard.set(lastUploadTimeBloodGlucoseSamples, forKey: "lastUploadTimeBloodGlucoseSamples")
        UserDefaults.standard.set(lastUploadSampleTimeBloodGlucoseSamples, forKey: "lastUploadSampleTimeBloodGlucoseSamples")
        UserDefaults.standard.set(currentDayHistoricalBloodGlucoseSamples, forKey: "currentDayHistoricalBloodGlucoseSamples")
        UserDefaults.standard.set(totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Notifications.Updated), object: nil))
        }
    }

    // MARK: Private - properties
    
    fileprivate let backgroundUploadSessionIdentifier = "uploadBloodGlucose"
    
    fileprivate var uploadSessionCompletionHandler: (() -> Void)?
    fileprivate var uploadSession: URLSession?
    fileprivate var uploadSessionIsBackground = false
    
    fileprivate var isReadingMostRecentSamples = false
    fileprivate var isReadingSamplesFromAnchor = false

    fileprivate var currentUserId: String?
    fileprivate var currentSamplesToUpload = [HKSample]()
    fileprivate var currentSamplesToUploadLatestSampleTime = Date.distantPast
    fileprivate var currentBatchUploadDict = [String: AnyObject]()
    
    fileprivate var lastUploadSampleTimeBloodGlucoseSamples = Date.distantPast
    fileprivate var startDateHistoricalBloodGlucoseSamples = Date.distantPast
    fileprivate var endDateHistoricalBloodGlucoseSamples = Date.distantPast
    
    fileprivate var totalUploadCountMostRecentBloodGlucoseSamples = 0
}
