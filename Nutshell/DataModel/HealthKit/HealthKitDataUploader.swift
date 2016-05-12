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
    private init() {
        DDLogVerbose("trace")
        
        let latestUploaderVersion = 4
        
        let lastExecutedUploaderVersion = NSUserDefaults.standardUserDefaults().integerForKey("lastExecutedUploaderVersion")
        var resetPersistentData = false
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            NSUserDefaults.standardUserDefaults().setInteger(latestUploaderVersion, forKey: "lastExecutedUploaderVersion")
            resetPersistentData = true
        }
        
        initState(resetPersistentData)
     }
    
    private func initState(resetUser: Bool = false) {
        if resetUser {
            NSUserDefaults.standardUserDefaults().removeObjectForKey("bloodGlucoseQueryAnchor")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("bloodGlucoseUploadRecentEndDate")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("bloodGlucoseUploadRecentStartDate")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("bloodGlucoseUploadRecentStartDateFinal")

            NSUserDefaults.standardUserDefaults().removeObjectForKey("uploadPhaseBloodGlucoseSamples")
            
            NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadSampleTimeBloodGlucoseSamples")

            NSUserDefaults.standardUserDefaults().removeObjectForKey("startDateHistoricalBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("endDateHistoricalBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalDaysHistoricalBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("currentDayHistoricalBloodGlucoseSamples")
            
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountMostRecentBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountHistoricalBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountCurrentBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountBloodGlucoseSamplesWithoutDuplicates")
            
            NSUserDefaults.standardUserDefaults().removeObjectForKey("workoutQueryAnchor")
            
            NSUserDefaults.standardUserDefaults().synchronize()
            
            DDLogInfo("Upload settings have been reset anchor during migration")
        }
        
        var phase = Phases.MostRecentSamples
        let persistedPhase = NSUserDefaults.standardUserDefaults().objectForKey("uploadPhaseBloodGlucoseSamples")
        if persistedPhase != nil {
            phase = HealthKitDataUploader.Phases(rawValue: persistedPhase!.integerValue)!

            let lastUploadTimeBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().objectForKey("lastUploadTimeBloodGlucoseSamples") as? NSDate
            let lastUploadSampleTimeBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().objectForKey("lastUploadSampleTimeBloodGlucoseSamples") as? NSDate
            self.lastUploadTimeBloodGlucoseSamples = lastUploadTimeBloodGlucoseSamples ?? NSDate.distantPast()
            self.lastUploadSampleTimeBloodGlucoseSamples = lastUploadSampleTimeBloodGlucoseSamples ?? NSDate.distantPast()

            let startDateHistoricalBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().objectForKey("startDateHistoricalBloodGlucoseSamples") as? NSDate
            let endDateHistoricalBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().objectForKey("endDateHistoricalBloodGlucoseSamples") as? NSDate
            self.startDateHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples ?? NSDate.distantPast()
            self.endDateHistoricalBloodGlucoseSamples = endDateHistoricalBloodGlucoseSamples ?? NSDate.distantPast()
            self.totalDaysHistoricalBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalDaysHistoricalBloodGlucoseSamples")
            self.currentDayHistoricalBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("currentDayHistoricalBloodGlucoseSamples")
            
            self.totalUploadCountMostRecentBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountMostRecentBloodGlucoseSamples")
            self.totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates")
            self.totalUploadCountHistoricalBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountHistoricalBloodGlucoseSamples")
            self.totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates")
            self.totalUploadCountCurrentBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountCurrentBloodGlucoseSamples")
            self.totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates")
            self.totalUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamples")
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamplesWithoutDuplicates")
        } else {
            self.lastUploadTimeBloodGlucoseSamples = NSDate.distantPast()
            self.lastUploadSampleTimeBloodGlucoseSamples = NSDate.distantPast()
            
            self.startDateHistoricalBloodGlucoseSamples = NSDate.distantPast()
            self.endDateHistoricalBloodGlucoseSamples = NSDate.distantPast()
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
        case MostRecentSamples
        case HistoricalSamples
        case CurrentSamples
    }
    
    private(set) var isUploading = false
    private(set) var uploadPhaseBloodGlucoseSamples = Phases.MostRecentSamples
    private(set) var lastUploadTimeBloodGlucoseSamples = NSDate.distantPast()
    private(set) var totalDaysHistoricalBloodGlucoseSamples = 0
    private(set) var currentDayHistoricalBloodGlucoseSamples = 0
    private(set) var totalUploadCountBloodGlucoseSamples = 0
    
    var uploadHandler: ((postBody: NSData, completion: (error: NSError?, duplicateSampleCount: Int) -> (Void)) -> (Void)) = {(postBody, completion) in }

    func authorizeAndStartUploading(currentUserId currentUserId: String)
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
    
    func startUploading(currentUserId currentUserId: String?) {
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

        NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.Updated, object: nil))
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
        self.currentSamplesToUploadLatestSampleTimeBySource = [String: NSDate]()
        self.currentBatchUploadDict = [String: AnyObject]()
        
        self.isUploading = false

        NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.Updated, object: nil))
    }

    // TODO: review; should only be called when a non-current HK user is logged in!
    func resetHealthKitUploaderForNewUser() {
        DDLogVerbose("Switching healthkit user, need to reset anchors!")
        initState(true)
    }    

    // MARK: Private - observation and results handlers

    private func bloodGlucoseObservationHandler(error: NSError?) {
        DDLogVerbose("trace")

        if error == nil {
            dispatch_async(dispatch_get_main_queue(), {
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
    
    private func bloodGlucoseResultHandler(error: NSError?, newSamples: [HKSample]?, completion: (NSError?) -> (Void)) {
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
        
        guard let samples = newSamples where samples.count > 0 else {
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

    private func startBatchUpload(samples samples: [HKSample], completion: (NSError?) -> (Void)) {
        DDLogVerbose("trace")
        
        let firstSample = samples[0]
        let sourceRevision = firstSample.sourceRevision
        let source = sourceRevision.source
        let sourceBundleIdentifier = source.bundleIdentifier
        let deviceModel = deviceModelForSourceBundleIdentifier(sourceBundleIdentifier)
        let deviceId = "\(deviceModel)_\(UIDevice.currentDevice().identifierForVendor!.UUIDString)"
        let now = NSDate()
        let timeZoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT / 60
        let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        let appBuild = NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as! String
        let appBundleIdentifier = NSBundle.mainBundle().bundleIdentifier!
        let version = "\(appBundleIdentifier):\(appVersion):\(appBuild)"
        let dateFormatter = NSDateFormatter()
        let time = NSDateFormatter().isoStringFromDate(now)
        let guid = NSUUID().UUIDString
        let uploadIdSuffix = "\(deviceId)_\(time)_\(guid)"
        let uploadIdSuffixMd5Hash = uploadIdSuffix.md5()
        let uploadId = "upid_\(uploadIdSuffixMd5Hash)"
        
        self.currentBatchUploadDict = [String: AnyObject]()
        self.currentBatchUploadDict["type"] = "upload"
        self.currentBatchUploadDict["uploadId"] = uploadId
        self.currentBatchUploadDict["computerTime"] = dateFormatter.isoStringFromDate(now, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
        self.currentBatchUploadDict["time"] = time
        self.currentBatchUploadDict["timezoneOffset"] = timeZoneOffset
        self.currentBatchUploadDict["timezone"] = NSTimeZone.localTimeZone().name
        self.currentBatchUploadDict["timeProcessing"] = "none"
        self.currentBatchUploadDict["version"] = version
        self.currentBatchUploadDict["guid"] = guid
        self.currentBatchUploadDict["byUser"] = currentUserId
        self.currentBatchUploadDict["deviceTags"] = ["cgm"]
        self.currentBatchUploadDict["deviceManufacturers"] = ["Dexcom"]
        self.currentBatchUploadDict["deviceSerialNumber"] = ""
        self.currentBatchUploadDict["deviceModel"] = deviceModel
        self.currentBatchUploadDict["deviceId"] = deviceId

        do {
            let postBody = try NSJSONSerialization.dataWithJSONObject(self.currentBatchUploadDict, options: NSJSONWritingOptions.PrettyPrinted)
            if defaultDebugLevel != DDLogLevel.Off {
                let postBodyString = NSString(data: postBody, encoding: NSUTF8StringEncoding)! as String
                DDLogVerbose("Start batch upload JSON: \(postBodyString)")
            }
            
            self.uploadHandler(postBody: postBody) {
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
    
    private func uploadSamplesForBatch(samples samples: [HKSample], completion: (NSError?) -> (Void)) {
        DDLogVerbose("trace")

        // Prepare upload post body
        let dateFormatter = NSDateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in samples {
            var sampleToUploadDict = [String: AnyObject]()
            
            sampleToUploadDict["uploadId"] = self.currentBatchUploadDict["uploadId"]
            sampleToUploadDict["type"] = "cbg"
            sampleToUploadDict["deviceId"] = self.currentBatchUploadDict["deviceId"]
            sampleToUploadDict["guid"] = sample.UUID.UUIDString
            sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
            
            if let quantitySample = sample as? HKQuantitySample {
                let units = "mg/dL"
                sampleToUploadDict["units"] = units
                let unit = HKUnit(fromString: units)
                let value = quantitySample.quantity.doubleValueForUnit(unit)
                sampleToUploadDict["value"] = value
                
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
                       annotationValue = annotationValue {
                    let annotations = [
                        [
                            "code": annotationCode,
                            "value": annotationValue,
                            "threshold": annotationThreshold
                        ]
                    ]
                    sampleToUploadDict["annotations"] = annotations
                }
            }
            
            // Add sample metadata payload props
            if var metadata = sample.metadata {
                for (key, value) in metadata {
                    if let dateValue = value as? NSDate {
                        if key == "Receiver Display Time" {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                            
                        } else {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                        }
                    }
                }
                
                // If "Receiver Display Time" exists, use that as deviceTime and remove from metadata payload
                if let receiverDisplayTime = metadata["Receiver Display Time"] {
                    sampleToUploadDict["deviceTime"] = receiverDisplayTime
                    metadata.removeValueForKey("Receiver Display Time")
                }
                sampleToUploadDict["payload"] = metadata
            }
            
            // Add sample
            samplesToUploadDictArray.append(sampleToUploadDict)
        }

        do {
            let postBody = try NSJSONSerialization.dataWithJSONObject(samplesToUploadDictArray, options: NSJSONWritingOptions.PrettyPrinted)
            if defaultDebugLevel != DDLogLevel.Off {
                let postBodyString = NSString(data: postBody, encoding: NSUTF8StringEncoding)! as String
                DDLogVerbose("Samples to upload: \(postBodyString)")
            }
            
            self.uploadHandler(postBody: postBody) {
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
    
    private func deviceModelForSourceBundleIdentifier(sourceBundleIdentifier: String) -> String {
        var deviceModel = ""
        
        if sourceBundleIdentifier.lowercaseString.rangeOfString("com.dexcom.cgm") != nil {
            deviceModel = "DexG5"
        } else if sourceBundleIdentifier.lowercaseString.rangeOfString("com.dexcom.share2") != nil {
            deviceModel = "DexG4"
        } else {
            DDLogError("Unknown Dexcom sourceBundleIdentifier: \(sourceBundleIdentifier)")
            deviceModel = "DexUnknown"
        }
        
        return "HealthKit_\(deviceModel)"
    }
    
    private func filterSortAndGroupSamplesForUpload(samples: [HKSample]) {
        DDLogVerbose("trace")

        var samplesBySource = [String: [HKSample]]()
        var samplesLatestSampleTimeBySource = [String: NSDate]()
        
        let sortedSamples = samples.sort({x, y in
            return x.startDate.compare(y.startDate) == .OrderedAscending
        })
        
        // Group by source
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            let sourceBundleIdentifier = source.bundleIdentifier

            if source.name.lowercaseString.rangeOfString("dexcom") == nil {
                DDLogInfo("Ignoring non-Dexcom glucose data")
                continue
            }

            if samplesBySource[sourceBundleIdentifier] == nil {
                samplesBySource[sourceBundleIdentifier] = [HKSample]()
                samplesLatestSampleTimeBySource[sourceBundleIdentifier] = NSDate.distantPast()
            }
            samplesBySource[sourceBundleIdentifier]?.append(sample)
            if sample.startDate.compare(samplesLatestSampleTimeBySource[sourceBundleIdentifier]!) == .OrderedDescending {
                samplesLatestSampleTimeBySource[sourceBundleIdentifier] = sample.startDate
            }
        }
    
        self.currentSamplesToUploadBySource = samplesBySource
        self.currentSamplesToUploadLatestSampleTimeBySource = samplesLatestSampleTimeBySource
    }
    
    // MARK: Private - upload phases (most recent, historical, current)
    
    private func startReadingSamples() {
        DDLogVerbose("trace")

        dispatch_async(dispatch_get_main_queue(), {
            if self.uploadPhaseBloodGlucoseSamples == .MostRecentSamples {
                self.startReadingMostRecentSamples()
            } else {
                self.startReadingSamplesFromAnchor()
            }
        })
    }
    
    private func stopReadingSamples(completion completion: ((NSError?) -> (Void))?, error: NSError?) {
        DDLogVerbose("trace")

        dispatch_async(dispatch_get_main_queue(), {
            if self.isReadingMostRecentSamples {
                self.stopReadingMostRecentSamples()
            } else if self.isReadingSamplesFromAnchor {
                self.stopReadingSamplesFromAnchor(completion: completion, error: error)
            }
        })
    }
    
    private func handleNoResultsToUpload(error error: NSError?, completion: (NSError?) -> (Void)) {
        DDLogVerbose("trace")

        dispatch_async(dispatch_get_main_queue(), {
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
                    self.transitionToPhase(.CurrentSamples)
                } else {
                    DDLogInfo("stop reading samples from anchor due to error: \(error)")
                    self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
                }
            }
        })
    }
    
    private func readMore(completion completion: (NSError?) -> (Void)) {
        DDLogVerbose("trace")
        
        dispatch_async(dispatch_get_main_queue(), {
            if self.isReadingMostRecentSamples {
                self.stopReadingMostRecentSamples()

                let bloodGlucoseUploadRecentEndDate = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseUploadRecentStartDate") as! NSDate
                let bloodGlucoseUploadRecentStartDate = bloodGlucoseUploadRecentEndDate.dateByAddingTimeInterval(-60 * 60 * 8)
                let bloodGlucoseUploadRecentStartDateFinal = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseUploadRecentStartDateFinal") as! NSDate
                if bloodGlucoseUploadRecentEndDate.compare(bloodGlucoseUploadRecentStartDateFinal) == .OrderedAscending {
                    DDLogInfo("finished reading most recent samples")
                    self.transitionToPhase(.HistoricalSamples)
                }
                else {
                    NSUserDefaults.standardUserDefaults().setObject(bloodGlucoseUploadRecentStartDate, forKey: "bloodGlucoseUploadRecentStartDate")
                    NSUserDefaults.standardUserDefaults().setObject(bloodGlucoseUploadRecentEndDate, forKey: "bloodGlucoseUploadRecentEndDate")
                }
            } else if self.isReadingSamplesFromAnchor {
                self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
            }
            self.startReadingSamples()
        })
    }

    private func startReadingSamplesFromAnchor() {
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
    
    private func stopReadingSamplesFromAnchor(completion completion: ((NSError?) -> (Void))?, error: NSError?) {
        DDLogVerbose("trace")

        if self.isReadingSamplesFromAnchor {
            completion?(error)
            self.isReadingSamplesFromAnchor = false
        } else {
            DDLogVerbose("Unexpected call to stopReadingSamplesFromAnchor when not reading samples")
        }
    }
    
    private func startReadingMostRecentSamples() {
        DDLogVerbose("trace")
        
        if !self.isReadingMostRecentSamples {
            self.isReadingMostRecentSamples = true
            
            let now = NSDate()
            let eightHoursAgo = now.dateByAddingTimeInterval(-60 * 60 * 8)
            let twoWeeksAgo = now.dateByAddingTimeInterval(-60 * 60 * 24 * 14)
            var bloodGlucoseUploadRecentEndDate = now
            var bloodGlucoseUploadRecentStartDate = eightHoursAgo
            var bloodGlucoseUploadRecentStartDateFinal = twoWeeksAgo
            
            let bloodGlucoseUploadRecentStartDateFinalSetting = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseUploadRecentStartDateFinal")
            if bloodGlucoseUploadRecentStartDateFinalSetting == nil {
                NSUserDefaults.standardUserDefaults().setObject(bloodGlucoseUploadRecentEndDate, forKey: "bloodGlucoseUploadRecentEndDate")
                NSUserDefaults.standardUserDefaults().setObject(bloodGlucoseUploadRecentStartDate, forKey: "bloodGlucoseUploadRecentStartDate")
                NSUserDefaults.standardUserDefaults().setObject(bloodGlucoseUploadRecentStartDateFinal, forKey: "bloodGlucoseUploadRecentStartDateFinal")
                DDLogInfo("final date for most upload of most recent samples: \(bloodGlucoseUploadRecentStartDateFinal)")
            } else {
                bloodGlucoseUploadRecentEndDate = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseUploadRecentEndDate") as! NSDate
                bloodGlucoseUploadRecentStartDate = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseUploadRecentStartDate") as! NSDate
                bloodGlucoseUploadRecentStartDateFinal = bloodGlucoseUploadRecentStartDateFinalSetting as! NSDate
            }
            
            // Do this here so we have are more likely to have the days range ready for progress UI when 
            // we enter the historical samples phase
            updateHistoricalSamplesDateRangeAsync()

            HealthKitManager.sharedInstance.readBloodGlucoseSamples(startDate: bloodGlucoseUploadRecentStartDate, endDate: bloodGlucoseUploadRecentEndDate, limit: 288, resultsHandler: self.bloodGlucoseResultHandler)
        } else {
            DDLogVerbose("Already reading most recent blood glucose samples, ignoring subsequent request to read")
        }
    }
    
    private func stopReadingMostRecentSamples() {
        DDLogVerbose("trace")
        
        if self.isReadingMostRecentSamples {
            self.isReadingMostRecentSamples = false
        } else {
            DDLogVerbose("Unexpected call to stopReadingMostRecentSamples when not reading samples")
        }
    }
    
    private func transitionToPhase(phase: Phases) {
        DDLogInfo("transitioning to \(phase)")
        self.uploadPhaseBloodGlucoseSamples = phase
        NSUserDefaults.standardUserDefaults().setInteger(phase.rawValue, forKey: "uploadPhaseBloodGlucoseSamples")
        NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.Updated, object: nil))
    }
    
    // MARK: Private - stats
    
    private func updateHistoricalSamplesDateRangeAsync() {
        DDLogVerbose("trace")
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {            
            (error: NSError?, startDate: NSDate?, endDate: NSDate?) in
            guard self.isUploading else {
                DDLogInfo("Not currently uploading, ignoring")
                return
            }

            if error == nil && startDate != nil && endDate != nil {
                DDLogInfo("Updated historical samples date range")
                
                self.startDateHistoricalBloodGlucoseSamples = startDate!
                NSUserDefaults.standardUserDefaults().setObject(startDate, forKey: "startDateHistoricalBloodGlucoseSamples")
                
                self.endDateHistoricalBloodGlucoseSamples = endDate!
                NSUserDefaults.standardUserDefaults().setObject(endDate, forKey: "endDateHistoricalBloodGlucoseSamples")
            }
        }
    }
    
    private func updateStats(sampleCount sampleCount: Int, duplicateSampleCount: Int) {
        DDLogVerbose("trace")
        
        let lastUploadSampleTimeBloodGlucoseSamples = currentSamplesToUploadLatestSampleTimeBySource.popFirst()!.1
        
        switch self.uploadPhaseBloodGlucoseSamples {
        case .MostRecentSamples:
            self.totalUploadCountMostRecentBloodGlucoseSamples += sampleCount
            self.totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
        case .HistoricalSamples:
            self.totalUploadCountBloodGlucoseSamples += sampleCount
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.totalUploadCountHistoricalBloodGlucoseSamples += sampleCount
            self.totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.lastUploadTimeBloodGlucoseSamples = NSDateFormatter().dateFromISOString(self.currentBatchUploadDict["time"] as! String)
            if self.lastUploadSampleTimeBloodGlucoseSamples.compare(lastUploadSampleTimeBloodGlucoseSamples) == .OrderedAscending {
                self.lastUploadSampleTimeBloodGlucoseSamples = lastUploadSampleTimeBloodGlucoseSamples
            }
            if startDateHistoricalBloodGlucoseSamples.compare(endDateHistoricalBloodGlucoseSamples) == .OrderedAscending {
                totalDaysHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples.differenceInDays(endDateHistoricalBloodGlucoseSamples) + 1
                currentDayHistoricalBloodGlucoseSamples = startDateHistoricalBloodGlucoseSamples.differenceInDays(lastUploadSampleTimeBloodGlucoseSamples) + 1
                DDLogInfo(
                    "Uploaded \(currentDayHistoricalBloodGlucoseSamples) of \(totalDaysHistoricalBloodGlucoseSamples) days of historical data");
            }
        case .CurrentSamples:
            self.totalUploadCountBloodGlucoseSamples += sampleCount
            self.totalUploadCountBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.totalUploadCountCurrentBloodGlucoseSamples += sampleCount
            self.totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates += (sampleCount - duplicateSampleCount)
            self.lastUploadTimeBloodGlucoseSamples = NSDateFormatter().dateFromISOString(self.currentBatchUploadDict["time"] as! String)
            if self.lastUploadSampleTimeBloodGlucoseSamples.compare(lastUploadSampleTimeBloodGlucoseSamples) == .OrderedAscending {
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
        
        NSUserDefaults.standardUserDefaults().setObject(lastUploadTimeBloodGlucoseSamples, forKey: "lastUploadTimeBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setObject(lastUploadSampleTimeBloodGlucoseSamples, forKey: "lastUploadSampleTimeBloodGlucoseSamples")
        
        NSUserDefaults.standardUserDefaults().setInteger(totalDaysHistoricalBloodGlucoseSamples, forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setInteger(currentDayHistoricalBloodGlucoseSamples, forKey: "currentDayHistoricalBloodGlucoseSamples")
        
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountMostRecentBloodGlucoseSamples, forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountMostRecentBloodGlucoseSamples, forKey: "totalUploadCountMostRecentBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountHistoricalBloodGlucoseSamples, forKey: "totalUploadCountHistoricalBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountCurrentBloodGlucoseSamples, forKey: "totalUploadCountCurrentBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
        NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountBloodGlucoseSamplesWithoutDuplicates, forKey: "totalUploadCountBloodGlucoseSamplesWithoutDuplicates")
        
        NSUserDefaults.standardUserDefaults().synchronize()
        
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.Updated, object: nil))
        }
    }

    // MARK: Private - properties

    private var isReadingMostRecentSamples = false
    private var isReadingSamplesFromAnchor = false

    private var currentUserId: String?
    private var currentSamplesToUploadBySource = [String: [HKSample]]()
    private var currentSamplesToUploadLatestSampleTimeBySource = [String: NSDate]()
    private var currentBatchUploadDict = [String: AnyObject]()
    
    private var lastUploadSampleTimeBloodGlucoseSamples = NSDate.distantPast()
    private var startDateHistoricalBloodGlucoseSamples = NSDate.distantPast()
    private var endDateHistoricalBloodGlucoseSamples = NSDate.distantPast()
    
    private var totalUploadCountMostRecentBloodGlucoseSamples = 0
    private var totalUploadCountMostRecentBloodGlucoseSamplesWithoutDuplicates = 0
    private var totalUploadCountHistoricalBloodGlucoseSamples = 0
    private var totalUploadCountHistoricalBloodGlucoseSamplesWithoutDuplicates = 0
    private var totalUploadCountCurrentBloodGlucoseSamples = 0
    private var totalUploadCountCurrentBloodGlucoseSamplesWithoutDuplicates = 0
    private var totalUploadCountBloodGlucoseSamplesWithoutDuplicates = 0
}
