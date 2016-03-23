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
        if latestUploaderVersion != lastExecutedUploaderVersion {
            DDLogInfo("Migrating uploader to \(latestUploaderVersion)")
            
            NSUserDefaults.standardUserDefaults().removeObjectForKey("bloodGlucoseQueryAnchor")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountBloodGlucoseSamples")

            NSUserDefaults.standardUserDefaults().setInteger(latestUploaderVersion, forKey: "lastExecutedUploaderVersion")
            NSUserDefaults.standardUserDefaults().synchronize()

            DDLogInfo("Reset upload stats and HealthKit query anchor during migration")
        }

        let lastUploadTime = NSUserDefaults.standardUserDefaults().objectForKey("lastUploadTimeBloodGlucoseSamples")
        if lastUploadTime != nil {
            self.lastUploadTimeBloodGlucoseSamples = lastUploadTime as! NSDate
            self.lastUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastUploadCountBloodGlucoseSamples")
            self.totalUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamples")
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
            shouldAuthorizeBloodGlucoseSampleReads: true,
            shouldAuthorizeBloodGlucoseSampleWrites: false,
            shouldAuthorizeWorkoutSamples: false) {
                success, error -> Void in
                
                if error == nil {
                    self.startUploading(currentUserId: currentUserId)
                } else {
                    DDLogError("Error authorizing health data \(error), \(error!.userInfo)")
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
        
        // If already observing / uploading and we are asked to start uploading, then start reading samples. This
        // will handle the situation where after initially declining read permissions, then going to Health app to
        // enable read permissions, then switching back to app, should start reading and uploading available 
        // glucose data
        if self.isUploading {
            DDLogInfo("start reading samples - start uploading")
            self.startReadingBloodGlucoseSamples()
        }
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

    // MARK: Private
    
    private func startReadingBloodGlucoseSamples() {
        dispatch_async(dispatch_get_main_queue(), {
            if !self.isReadingBloodGlucoseSamples {
                self.isReadingBloodGlucoseSamples = true
                HealthKitManager.sharedInstance.readBloodGlucoseSamples(self.bloodGlucoseResultHandler)
            } else {
                DDLogVerbose("Already reading blood glucose samples, ignoring subsequent request to read")
            }
        })
    }

    private func stopReadingBloodGlucoseSamples(completion completion: (NSError?) -> (Void), error: NSError?) {
        dispatch_async(dispatch_get_main_queue(), {
            completion(error)
            self.isReadingBloodGlucoseSamples = false
        })
    }
    

    private func bloodGlucoseObservationHandler(error: NSError?) {
        if error == nil {
            self.isUploading = true
            HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()
            DDLogInfo("start reading samples - observe samples")
            self.startReadingBloodGlucoseSamples()
        }
    }
    
    private func bloodGlucoseResultHandler(newSamples: [HKSample]?, completion: (NSError?) -> (Void)) {
        DDLogInfo("trace")
        
        var samplesAvailableToUpload = false
        
        defer {
            if !samplesAvailableToUpload {
                DDLogInfo("stop reading samples - no new samples available to upload")
                self.stopReadingBloodGlucoseSamples(completion: completion, error: nil)
            }
        }
        
        guard let samples = newSamples where samples.count > 0 else {
            return
        }
        
        // Group by source
        self.currentSamplesToUploadBySource = self.filteredSamplesGroupedBySource(samples)
        if let (_, samples) = self.currentSamplesToUploadBySource.popFirst() {
            samplesAvailableToUpload = true
            
            // Start first batch upload for groups
            startBatchUpload(samples: samples, completion: completion)
        }
    }
 
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
        var uploadIdSuffixMd5Hash = uploadIdSuffix.md5()
        uploadIdSuffixMd5Hash = uploadIdSuffixMd5Hash.substringToIndex(uploadIdSuffixMd5Hash.startIndex.advancedBy(12))
        let uploadId = "upid_HealthKit_\(uploadIdSuffixMd5Hash)"
        
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
                    self.stopReadingBloodGlucoseSamples(completion: completion, error: error)
                }
            }
        } catch let error as NSError! {
            DDLogError("stop reading samples - error creating post body for start of batch upload: \(error)")
            self.stopReadingBloodGlucoseSamples(completion: completion, error: error)
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
                    
                    if let (_, samples) = self.currentSamplesToUploadBySource.popFirst() {
                        // Start next batch upload for groups
                        self.startBatchUpload(samples: samples, completion: completion)
                    } else {
                        // Stop reading
                        DDLogInfo("stop reading samples - finished uploading batch")
                        self.stopReadingBloodGlucoseSamples(completion: completion, error: error)

                        // Try to read more samples    
                        DDLogInfo("start reading samples - finished uploading batch - check for more samples")
                        self.startReadingBloodGlucoseSamples()
                    }
                } else {
                    DDLogError("stop reading samples - error uploading samples: \(error)")
                    self.stopReadingBloodGlucoseSamples(completion: completion, error: error)
                }
            }
        } catch let error as NSError! {
            DDLogError("stop reading samples - error creating post body for start of batch upload: \(error)")
            self.stopReadingBloodGlucoseSamples(completion: completion, error: error)
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
    private var isReadingBloodGlucoseSamples = false
}
