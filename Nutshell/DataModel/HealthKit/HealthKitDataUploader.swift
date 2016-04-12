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

class HealthKitDataUploader {
    // MARK: Access, authorization
    
    static let sharedInstance = HealthKitDataUploader()
    private init() {
        DDLogVerbose("trace")
        
        let latestUploaderVersion = 1
        
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
            NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("workoutQueryAnchor")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            DDLogInfo("Reset upload stats and HealthKit query anchor during migration")
        }
        
        let lastUploadTime = NSUserDefaults.standardUserDefaults().objectForKey("lastUploadTimeBloodGlucoseSamples")
        if lastUploadTime != nil {
            self.lastUploadTimeBloodGlucoseSamples = lastUploadTime as! NSDate
            self.lastUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastUploadCountBloodGlucoseSamples")
            self.totalUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamples")
        } else {
            self.lastUploadTimeBloodGlucoseSamples = NSDate.distantPast()
            self.lastUploadCountBloodGlucoseSamples = 0
            self.totalUploadCountBloodGlucoseSamples = 0
        }
        
        if resetUser {
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.UploadedBloodGlucoseSamples, object: nil))
            }
        }
        
        if NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseQueryAnchor") == nil {
            DDLogInfo("Anchor does not exist, we'll upload most recent samples first")
            self.shouldUploadMostRecentFirst = true
        } else {
            DDLogInfo("Anchor exists, we'll upload samples from anchor query")
        }
    }

    enum Notifications {
        static let UploadedBloodGlucoseSamples = "HealthKitDataUpload-uploaded-\(HKQuantityTypeIdentifierBloodGlucose)"
    }
    
    private(set) var isUploading = false
    
    private(set) var lastUploadTimeBloodGlucoseSamples = NSDate.distantPast()
    private(set) var lastUploadCountBloodGlucoseSamples = 0
    private(set) var totalUploadCountBloodGlucoseSamples = 0
    
    var uploadHandler: ((postBody: NSData, completion: (NSError?) -> (Void)) -> (Void)) = {(postBody, completion) in }

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

        // Remember the user id for the uploads
        self.currentUserId = currentUserId
        
        // Start observing samples. We don't really start uploading until we've successsfully started observing
        HealthKitManager.sharedInstance.startObservingBloodGlucoseSamples(self.bloodGlucoseObservationHandler)

        DDLogInfo("start reading samples - start uploading")
        self.startReadingSamples()
        
        isUploading = true
    }
    
    func stopUploading() {
        DDLogVerbose("trace")
        
        guard isUploading else {
            DDLogInfo("Not currently uploading, ignoring request to stop uploading")
            return
        }
        
        self.isUploading = false
        self.currentUserId = nil
        HealthKitManager.sharedInstance.disableBackgroundDeliveryWorkoutSamples()
        HealthKitManager.sharedInstance.stopObservingBloodGlucoseSamples()
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
                HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()

                DDLogInfo("start reading samples - started observing blood glucose samples")
                self.startReadingSamples()
            })
        }
    }
    
    private func bloodGlucoseResultHandler(error: NSError?, newSamples: [HKSample]?, completion: (NSError?) -> (Void)) {
        DDLogVerbose("trace")
        
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
        
        // Group by source
        self.currentSamplesToUploadBySource = self.filteredSamplesGroupedBySource(samples)
        let groupCount = currentSamplesToUploadBySource.count
        if let (_, samples) = self.currentSamplesToUploadBySource.popFirst() {
            samplesAvailableToUpload = true
            
            // Start first batch upload for groups
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
        let dateFormatter = NSDateFormatter()
        let timeZoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT / 60
        let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        let appBuild = NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as! String
        let appBundleIdentifier = NSBundle.mainBundle().bundleIdentifier!
        let version = "\(appBundleIdentifier):\(appVersion):\(appBuild)"
        let time = dateFormatter.isoStringFromDate(now)
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
                (error: NSError?) in
                if error == nil {
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
                (error: NSError?) in
                if error == nil {
                    self.updateStats(samples.count)
                    
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
    
    private func filteredSamplesGroupedBySource(samples: [HKSample]) -> [String: [HKSample]] {
        DDLogVerbose("trace")

        var filteredSamplesBySource = [String: [HKSample]]()
        
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

            if filteredSamplesBySource[sourceBundleIdentifier] == nil {
                filteredSamplesBySource[sourceBundleIdentifier] = [HKSample]()
            }
            filteredSamplesBySource[sourceBundleIdentifier]?.append(sample)
        }
    
        return filteredSamplesBySource
    }
    
    // MARK: Private - upload phases (more recent, or anchor)
    
    private func startReadingSamples() {
        DDLogVerbose("trace")
        
        dispatch_async(dispatch_get_main_queue(), {
            if self.shouldUploadMostRecentFirst {
                self.startReadingMostRecentSamples()
            } else {
                self.startReadingSamplesFromAnchor()
            }
        })
    }
    
    private func stopReadingSamples(completion completion: (NSError?) -> (Void), error: NSError?) {
        DDLogVerbose("trace")

        dispatch_async(dispatch_get_main_queue(), {
            if self.isReadingMostRecentSamples {
                self.stopReadingMostRecentSamples(completion: completion, error: error)
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
                    DDLogInfo("stop reading most recent - transitioning to reading samples from anchor")
                    self.stopReadingMostRecentSamples(completion: completion, error: error)
                    self.shouldUploadMostRecentFirst = false
                    self.startReadingSamplesFromAnchor()
                } else {
                    DDLogInfo("stop reading most recent due to error: \(error)")
                    self.stopReadingMostRecentSamples(completion: completion, error: error)
                }
            } else if self.isReadingSamplesFromAnchor {
                if error == nil {
                    DDLogInfo("stop reading samples from anchor - no new samples available to upload")
                    self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
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
                DDLogInfo("finished reading most recent samples - transitioning to reading samples from anchor")
                self.stopReadingMostRecentSamples(completion: completion, error: nil)
                self.shouldUploadMostRecentFirst = false
            } else if self.isReadingSamplesFromAnchor {
                self.stopReadingSamplesFromAnchor(completion: completion, error: nil)
            }

            self.startReadingSamplesFromAnchor()
        })
    }
    
    // MARK: Private - anchor phase

    private func startReadingSamplesFromAnchor() {
        DDLogVerbose("trace")
        
        if !self.isReadingSamplesFromAnchor {
            self.isReadingSamplesFromAnchor = true
            HealthKitManager.sharedInstance.readBloodGlucoseSamplesFromAnchor(self.bloodGlucoseResultHandler)
        } else {
            DDLogVerbose("Already reading blood glucose samples from anchor, ignoring subsequent request to read")
        }
    }
    
    private func stopReadingSamplesFromAnchor(completion completion: (NSError?) -> (Void), error: NSError?) {
        DDLogVerbose("trace")

        if self.isReadingSamplesFromAnchor {
            completion(error)
            self.isReadingSamplesFromAnchor = false
        } else {
            DDLogVerbose("Unexpected call to stopReadingSamplesFromAnchor when not reading samples")
        }
    }
    
    // MARK: Private - most recent samples phase
    
    private func startReadingMostRecentSamples() {
        DDLogVerbose("trace")
        
        if !self.isReadingMostRecentSamples {
            self.isReadingMostRecentSamples = true
            HealthKitManager.sharedInstance.readMostRecentBloodGlucoseSamples(self.bloodGlucoseResultHandler)
        } else {
            DDLogVerbose("Already reading most recent blood glucose samples, ignoring subsequent request to read")
        }
    }
    
    private func stopReadingMostRecentSamples(completion completion: (NSError?) -> (Void), error: NSError?) {
        DDLogVerbose("trace")
        
        if self.isReadingMostRecentSamples {
            completion(error)
            self.isReadingMostRecentSamples = false
        } else {
            DDLogVerbose("Unexpected call to stopReadingMostRecentSamples when not reading samples")
        }
    }
    
    // MARK: Private - stats
    
    private func updateStats(samplesUploadedCount: Int) {
        DDLogVerbose("trace")
        
        if samplesUploadedCount > 0 {
            DDLogInfo("Successfully uploaded \(samplesUploadedCount) samples")
            
            self.lastUploadTimeBloodGlucoseSamples = NSDate()
            self.lastUploadCountBloodGlucoseSamples = samplesUploadedCount
            self.totalUploadCountBloodGlucoseSamples += samplesUploadedCount
            
            NSUserDefaults.standardUserDefaults().setObject(lastUploadTimeBloodGlucoseSamples, forKey: "lastUploadTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastUploadCountBloodGlucoseSamples, forKey: "lastUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.UploadedBloodGlucoseSamples, object: nil))
            }
        }
    }
    
    private var currentUserId: String?
    private var currentSamplesToUploadBySource = [String: [HKSample]]()
    private var currentBatchUploadDict = [String: AnyObject]()
    private var isReadingSamplesFromAnchor = false
    private var isReadingMostRecentSamples = false
    private var shouldUploadMostRecentFirst = false
}
