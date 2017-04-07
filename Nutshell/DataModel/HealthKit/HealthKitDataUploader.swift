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

class HealthKitDataUploader {
    // MARK: Access, authorization
    
    static let sharedInstance = HealthKitDataUploader()
    fileprivate init() {
        DDLogVerbose("trace")
        
        let latestUploaderVersion = 4
        
        let lastExecutedUploaderVersion = UserDefaults.standard.integer(forKey: "lastExecutedUploaderVersion")
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            UserDefaults.standard.set(latestUploaderVersion, forKey: "lastExecutedUploaderVersion")
            resetPersistentData = true
        }
        
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
            
            UserDefaults.standard.removeObject(forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountHistoricalBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountCurrentBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountBloodGlucoseSamples")
            UserDefaults.standard.removeObject(forKey: "totalUploadCountBloodGlucoseSamplesWithoutDuplicates")
            
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
            
            self.totalUploadCountMostRecentBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
            self.totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates = UserDefaults.standard.integer(forKey: "totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates")
            self.totalUploadCountHistoricalBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalUploadCountHistoricalBloodGlucoseSamples")
            self.totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates = UserDefaults.standard.integer(forKey: "totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates")
            self.totalUploadCountCurrentBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalUploadCountCurrentBloodGlucoseSamples")
            self.totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates = UserDefaults.standard.integer(forKey: "totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates")
            self.totalUploadCountBloodGlucoseSamples = UserDefaults.standard.integer(forKey: "totalUploadCountBloodGlucoseSamples")
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates = UserDefaults.standard.integer(forKey: "totalUploadCountBloodGlucoseSamplesWithoutDuplicates")
        } else {
            self.lastUploadTimeBloodGlucoseSamples = Date.distantPast
            self.lastUploadSampleTimeBloodGlucoseSamples = Date.distantPast
            
            self.startDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.endDateHistoricalBloodGlucoseSamples = Date.distantPast
            self.totalDaysHistoricalBloodGlucoseSamples = 0
            self.currentDayHistoricalBloodGlucoseSamples = 0
            
            self.totalUploadCountMostRecentBloodGlucoseSamples = 0
            self.totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates = 0
            self.totalUploadCountHistoricalBloodGlucoseSamples = 0
            self.totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates = 0
            self.totalUploadCountCurrentBloodGlucoseSamples = 0
            self.totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates = 0
            self.totalUploadCountBloodGlucoseSamples = 0
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates = 0
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
    
    var uploadHandler: ((_ postBody: Data, _ completion: @escaping (_ error: NSError?, _ duplicateSampleCount: Int) -> (Void)) -> (Void)) = {(postBody, completion) in }

    // Unused...
    func authorizeAndStartUploading(currentUserId: String)
    {
        DDLogVerbose("trace")
        
        HealthKitManager.sharedInstance.authorize(
            shouldAuthorizeBloodGlucoseSampleReads: true, shouldAuthorizeBloodGlucoseSampleWrites: false,
            shouldAuthorizeWorkoutSamples: false) {
                success, error -> Void in
                
                if error == nil {
                    DDLogInfo("Authorization did not have an error (though we don't know whether permission was given), start uploading if possible")
                    self.startUploading(currentUserId: currentUserId)
                } else {
                    DDLogError("Error authorizing health data, success: \(success), \(error))")
                }
        }
    }
    
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

        self.stopReadingSamples(completion: nil, error: nil)
        self.currentUserId = nil
        self.currentSamplesToUploadBySource = [String: [HKSample]]()
        self.currentSamplesToUploadLatestSampleTimeBySource = [String: Date]()
        self.currentBatchUploadDict = [String: AnyObject]()
        
        self.isUploading = false

        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Notifications.Updated), object: nil))
    }

    // TODO: review; should only be called when a non-current HK user is logged in!
    func resetHealthKitUploaderForNewUser() {
        DDLogVerbose("Switching healthkit user, need to reset anchors!")
        initState(true)
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
    
    fileprivate func bloodGlucoseResultHandler(_ error: NSError?, newSamples: [HKSample]?, completion: @escaping (NSError?) -> (Void)) {
        DDLogVerbose("trace")
        
        guard self.isUploading else {
            DDLogInfo("Not currently uploading, ignoring")
            return
        }

        var samplesAvailableToUpload = false

        defer {
            if !samplesAvailableToUpload {
                self.handleNoResultsToUpload(error: error, completion: completion)
            }
        }
        
        guard error == nil else {
            return
        }
        
        guard let samples = newSamples, samples.count > 0 else {
            return
        }
        
        self.filterSortAndGroupSamplesForUpload(samples)
        let groupCount = currentSamplesToUploadBySource.count
        if let (_, samples) = self.currentSamplesToUploadBySource.popFirst() {
            samplesAvailableToUpload = true
            
            // Start first batch upload for available groups
            DDLogInfo("Start batch upload for \(groupCount) remaining distinct-source-app-groups of samples")
            startBatchUpload(samples: samples, completion: completion)
        }
    }
 
    // MARK: Private - upload

    fileprivate func startBatchUpload(samples: [HKSample], completion: @escaping (NSError?) -> (Void)) {
        DDLogVerbose("trace")
        
        let firstSample = samples[0]
        let sourceRevision = firstSample.sourceRevision
        let source = sourceRevision.source
        let sourceBundleIdentifier = source.bundleIdentifier
        let deviceModel = deviceModelForSourceBundleIdentifier(sourceBundleIdentifier)
        let deviceId = "\(deviceModel)_\(UIDevice.current.identifierForVendor!.uuidString)"
        let now = Date()
        let timeZoneOffset = NSCalendar.current.timeZone.secondsFromGMT() / 60
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        let version = "\(appBundleIdentifier):\(appVersion):\(appBuild)"
        let dateFormatter = DateFormatter()
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
            let postBody = try JSONSerialization.data(withJSONObject: self.currentBatchUploadDict, options: JSONSerialization.WritingOptions.prettyPrinted)
            if defaultDebugLevel != DDLogLevel.off {
                let postBodyString = NSString(data: postBody, encoding: String.Encoding.utf8.rawValue)! as String
                DDLogVerbose("Start batch upload JSON: \(postBodyString)")
            }
            
            self.uploadHandler(postBody) {
                (error: NSError?, duplicateSampleCount: Int) in
                if error == nil {
                    guard self.isUploading else {
                        DDLogInfo("Not currently uploading, ignoring")
                        return
                    }

                    self.uploadSamplesForBatch(samples: samples, completion: completion)
                } else {
                    DDLogError("stop reading samples - error starting batch upload of samples: \(error)")
                    self.stopReadingSamples(completion: completion, error: error)
                }
            }
        } catch let error as NSError! {
            DDLogError("stop reading samples - error creating post body for start of batch upload: \(error)")
            self.stopReadingSamples(completion: completion, error: error)
        }
    }
    
    fileprivate func uploadSamplesForBatch(samples: [HKSample], completion: @escaping (NSError?) -> (Void)) {
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

        do {
            let postBody = try JSONSerialization.data(withJSONObject: samplesToUploadDictArray, options: JSONSerialization.WritingOptions.prettyPrinted)
            if defaultDebugLevel != DDLogLevel.off {
                let postBodyString = NSString(data: postBody, encoding: String.Encoding.utf8.rawValue)! as String
                DDLogVerbose("Samples to upload: \(postBodyString)")
            }
            
            self.uploadHandler(postBody) {
                (error: NSError?, duplicateSampleCount: Int) in
                if error == nil {
                    guard self.isUploading else {
                        DDLogInfo("Not currently uploading, ignoring")
                        return
                    }
                    
                    self.updateStats(sampleCount: samples.count, duplicateSampleCount: duplicateSampleCount)
                    
                    let groupCount = self.currentSamplesToUploadBySource.count
                    if let (_, samples) = self.currentSamplesToUploadBySource.popFirst() {
                        // Start next batch upload for groups
                        DDLogInfo("Start next upload for \(groupCount) remaining distinct-source-app-groups of samples")
                        self.startBatchUpload(samples: samples, completion: completion)
                    } else {
                        DDLogInfo("stop reading samples - finished uploading groups from last read")
                        self.readMore(completion: completion)
                    }
                } else {
                    DDLogError("stop reading samples - error uploading samples: \(error)")
                    self.stopReadingSamples(completion: completion, error: error)
                }
            }
        } catch let error as NSError! {
            DDLogError("stop reading samples - error creating post body for start of batch upload: \(error)")
            self.stopReadingSamples(completion: completion, error: error)
        }
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
    
    fileprivate func filterSortAndGroupSamplesForUpload(_ samples: [HKSample]) {
        DDLogVerbose("trace")

        var samplesBySource = [String: [HKSample]]()
        var samplesLatestSampleTimeBySource = [String: Date]()
        
        let sortedSamples = samples.sorted(by: {x, y in
            return x.startDate.compare(y.startDate) == .orderedAscending
        })
        
        // Group by source
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            let sourceBundleIdentifier = source.bundleIdentifier

            if source.name.lowercased().range(of: "dexcom") == nil {
                DDLogInfo("Ignoring non-Dexcom glucose data")
                continue
            }

            if samplesBySource[sourceBundleIdentifier] == nil {
                samplesBySource[sourceBundleIdentifier] = [HKSample]()
                samplesLatestSampleTimeBySource[sourceBundleIdentifier] = Date.distantPast
            }
            samplesBySource[sourceBundleIdentifier]?.append(sample)
            if sample.startDate.compare(samplesLatestSampleTimeBySource[sourceBundleIdentifier]!) == .orderedDescending {
                samplesLatestSampleTimeBySource[sourceBundleIdentifier] = sample.startDate
            }
        }
    
        self.currentSamplesToUploadBySource = samplesBySource
        self.currentSamplesToUploadLatestSampleTimeBySource = samplesLatestSampleTimeBySource
    }
    
    // MARK: Private - upload phases (most recent, historical, current)
    
    fileprivate func startReadingSamples() {
        DDLogVerbose("trace")

        DispatchQueue.main.async(execute: {
            if self.uploadPhaseBloodGlucoseSamples == .mostRecentSamples {
                self.startReadingMostRecentSamples()
            } else {
                self.startReadingSamplesFromAnchor()
            }
        })
    }
    
    fileprivate func stopReadingSamples(completion: ((NSError?) -> (Void))?, error: NSError?) {
        DDLogVerbose("trace")

        DispatchQueue.main.async(execute: {
            if self.isReadingMostRecentSamples {
                self.stopReadingMostRecentSamples()
            } else if self.isReadingSamplesFromAnchor {
                self.stopReadingSamplesFromAnchor(completion: completion, error: error)
            }
        })
    }
    
    fileprivate func handleNoResultsToUpload(error: NSError?, completion: @escaping (NSError?) -> (Void)) {
        DDLogVerbose("trace")

        DispatchQueue.main.async(execute: {
            if self.isReadingMostRecentSamples {
                if error == nil {
                    self.readMore(completion: completion)
                } else {
                    DDLogInfo("stop reading most recent samples due to error: \(error)")
                    self.stopReadingMostRecentSamples()
                }
            } else if self.isReadingSamplesFromAnchor {
                if error == nil {
                    DDLogInfo("stop reading samples from anchor - no new samples available to upload")
                    self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
                    self.transitionToPhase(.currentSamples)
                } else {
                    DDLogInfo("stop reading samples from anchor due to error: \(error)")
                    self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
                }
            }
        })
    }
    
    fileprivate func readMore(completion: @escaping (NSError?) -> (Void)) {
        DDLogVerbose("trace")
        
        DispatchQueue.main.async(execute: {
            if self.isReadingMostRecentSamples {
                self.stopReadingMostRecentSamples()

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
                }
            } else if self.isReadingSamplesFromAnchor {
                self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
            }
            self.startReadingSamples()
        })
    }

    fileprivate func startReadingSamplesFromAnchor() {
        DDLogVerbose("trace")
        
        if !self.isReadingSamplesFromAnchor {
            self.isReadingSamplesFromAnchor = true
            
            // Update historical samples date range every time we start reading samples from anchor so
            // that we can have most up-to-date date range, in case there are writers to HealthKit during
            // the historical data upload phase.
            updateHistoricalSamplesDateRangeAsync()
            
            HealthKitManager.sharedInstance.readBloodGlucoseSamplesFromAnchor(self.bloodGlucoseResultHandler)
        } else {
            DDLogVerbose("Already reading blood glucose samples from anchor, ignoring subsequent request to read")
        }
    }
    
    fileprivate func stopReadingSamplesFromAnchor(completion: ((NSError?) -> (Void))?, error: NSError?) {
        DDLogVerbose("trace")

        if self.isReadingSamplesFromAnchor {
            completion?(error)
            self.isReadingSamplesFromAnchor = false
        } else {
            DDLogVerbose("Unexpected call to stopReadingSamplesFromAnchor when not reading samples")
        }
    }
    
    fileprivate func startReadingMostRecentSamples() {
        DDLogVerbose("trace")
        
        if !self.isReadingMostRecentSamples {
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
                DDLogInfo("final date for most upload of most recent samples: \(bloodGlucoseUploadRecentStartDateFinal)")
            } else {
                bloodGlucoseUploadRecentEndDate = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentEndDate") as! Date
                bloodGlucoseUploadRecentStartDate = UserDefaults.standard.object(forKey: "bloodGlucoseUploadRecentStartDate") as! Date
                bloodGlucoseUploadRecentStartDateFinal = bloodGlucoseUploadRecentStartDateFinalSetting as! Date
            }
            
            // Do this here so we have are more likely to have the days range ready for progress UI when 
            // we enter the historical samples phase
            updateHistoricalSamplesDateRangeAsync()

            HealthKitManager.sharedInstance.readBloodGlucoseSamples(startDate: bloodGlucoseUploadRecentStartDate, endDate: bloodGlucoseUploadRecentEndDate, limit: 288, resultsHandler: self.bloodGlucoseResultHandler)
        } else {
            DDLogVerbose("Already reading most recent blood glucose samples, ignoring subsequent request to read")
        }
    }
    
    fileprivate func stopReadingMostRecentSamples() {
        DDLogVerbose("trace")
        
        if self.isReadingMostRecentSamples {
            self.isReadingMostRecentSamples = false
        } else {
            DDLogVerbose("Unexpected call to stopReadingMostRecentSamples when not reading samples")
        }
    }
    
    fileprivate func transitionToPhase(_ phase: Phases) {
        DDLogInfo("transitioning to \(phase)")
        self.uploadPhaseBloodGlucoseSamples = phase
        UserDefaults.standard.set(phase.rawValue, forKey: "uploadPhaseBloodGlucoseSamples")
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
            }
        }
    }
    
    fileprivate func updateStats(sampleCount: Int, duplicateSampleCount: Int) {
        DDLogVerbose("trace")
        
        let lastUploadSampleTimeBloodGlucoseSamples = currentSamplesToUploadLatestSampleTimeBySource.popFirst()!.1
        
        switch self.uploadPhaseBloodGlucoseSamples {
        case .mostRecentSamples:
            self.totalUploadCountMostRecentBloodGlucoseSamples += sampleCount
            self.totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
        case .historicalSamples:
            self.totalUploadCountBloodGlucoseSamples += sampleCount
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.totalUploadCountHistoricalBloodGlucoseSamples += sampleCount
            self.totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.lastUploadTimeBloodGlucoseSamples = DateFormatter().dateFromISOString(self.currentBatchUploadDict["time"] as! String)
            if self.lastUploadSampleTimeBloodGlucoseSamples.compare(lastUploadSampleTimeBloodGlucoseSamples) == .orderedAscending {
                self.lastUploadSampleTimeBloodGlucoseSamples = lastUploadSampleTimeBloodGlucoseSamples
            }
            if startDateHistoricalBloodGlucoseSamples.compare(endDateHistoricalBloodGlucoseSamples) == .orderedAscending {
                totalDaysHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples.differenceInDays(endDateHistoricalBloodGlucoseSamples) + 1
                currentDayHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples.differenceInDays(lastUploadSampleTimeBloodGlucoseSamples) + 1
                DDLogInfo(
                    "Uploaded \(currentDayHistoricalBloodGlucoseSamples) of \(totalDaysHistoricalBloodGlucoseSamples) days of historical data");
            }
        case .currentSamples:
            self.totalUploadCountBloodGlucoseSamples += sampleCount
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.totalUploadCountCurrentBloodGlucoseSamples += sampleCount
            self.totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.lastUploadTimeBloodGlucoseSamples = DateFormatter().dateFromISOString(self.currentBatchUploadDict["time"] as! String)
            if self.lastUploadSampleTimeBloodGlucoseSamples.compare(lastUploadSampleTimeBloodGlucoseSamples) == .orderedAscending {
                self.lastUploadSampleTimeBloodGlucoseSamples = lastUploadSampleTimeBloodGlucoseSamples
            }
        }
        
        DDLogInfo(
            "Successfully uploaded \(sampleCount) samples of which \(duplicateSampleCount) were duplicates.\n" +
            "\ttotalUploadCountMostRecentBloodGlucoseSamples: \(totalUploadCountMostRecentBloodGlucoseSamples)\n" +
            "\ttotalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates: \(totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates)\n" +
            "\ttotalUploadCountHistoricalBloodGlucoseSamples: \(totalUploadCountHistoricalBloodGlucoseSamples)\n" +
            "\ttotalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates: \(totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates)\n" +
            "\ttotalUploadCountCurrentBloodGlucoseSamples: \(totalUploadCountCurrentBloodGlucoseSamples)\n" +
            "\ttotalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates: \(totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates)\n" +
            "\ttotalUploadCountBloodGlucoseSamples: \(totalUploadCountBloodGlucoseSamples)\n" +
            "\ttotalUploadCountBloodGlucoseSamplesWithoutDuplicates: \(totalUploadCountBloodGlucoseSamplesWithoutDuplicates)");
        
        UserDefaults.standard.set(lastUploadTimeBloodGlucoseSamples, forKey: "lastUploadTimeBloodGlucoseSamples")
        UserDefaults.standard.set(lastUploadSampleTimeBloodGlucoseSamples, forKey: "lastUploadSampleTimeBloodGlucoseSamples")
        
        UserDefaults.standard.set(totalDaysHistoricalBloodGlucoseSamples, forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
        UserDefaults.standard.set(currentDayHistoricalBloodGlucoseSamples, forKey: "currentDayHistoricalBloodGlucoseSamples")
        
        UserDefaults.standard.set(totalUploadCountMostRecentBloodGlucoseSamples, forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
        UserDefaults.standard.set(totalUploadCountMostRecentBloodGlucoseSamples, forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
        UserDefaults.standard.set(totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates")
        UserDefaults.standard.set(totalUploadCountHistoricalBloodGlucoseSamples, forKey: "totalUploadCountHistoricalBloodGlucoseSamples")
        UserDefaults.standard.set(totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates")
        UserDefaults.standard.set(totalUploadCountCurrentBloodGlucoseSamples, forKey: "totalUploadCountCurrentBloodGlucoseSamples")
        UserDefaults.standard.set(totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates")
        UserDefaults.standard.set(totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
        UserDefaults.standard.set(totalUploadCountBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountBloodGlucoseSamplesWithoutDuplicates")
        
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Notifications.Updated), object: nil))
        }
    }

    // MARK: Private - properties

    fileprivate var isReadingMostRecentSamples = false
    fileprivate var isReadingSamplesFromAnchor = false

    fileprivate var currentUserId: String?
    fileprivate var currentSamplesToUploadBySource = [String: [HKSample]]()
    fileprivate var currentSamplesToUploadLatestSampleTimeBySource = [String: Date]()
    fileprivate var currentBatchUploadDict = [String: AnyObject]()
    
    fileprivate var lastUploadSampleTimeBloodGlucoseSamples = Date.distantPast
    fileprivate var startDateHistoricalBloodGlucoseSamples = Date.distantPast
    fileprivate var endDateHistoricalBloodGlucoseSamples = Date.distantPast
    
    fileprivate var totalUploadCountMostRecentBloodGlucoseSamples = 0
    fileprivate var totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates = 0
    fileprivate var totalUploadCountHistoricalBloodGlucoseSamples = 0
    fileprivate var totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates = 0
    fileprivate var totalUploadCountCurrentBloodGlucoseSamples = 0
    fileprivate var totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates = 0
    fileprivate var totalUploadCountBloodGlucoseSamplesWithoutDuplicates = 0
}
