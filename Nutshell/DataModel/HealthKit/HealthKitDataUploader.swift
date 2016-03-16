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
import RealmSwift
import CocoaLumberjack

class HealthKitDataUploader {
    // MARK: Access, authorization
    
    static let sharedInstance = HealthKitDataUploader()
    private init() {
        DDLogVerbose("trace")

        let lastUploadTime = NSUserDefaults.standardUserDefaults().objectForKey("lastUploadTimeBloodGlucoseSamples")
        if lastUploadTime != nil {
            self.lastUploadTimeBloodGlucoseSamples = lastUploadTime as! NSDate
            self.lastUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastUploadCountBloodGlucoseSamples")
            self.totalUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamples")
        }
    }
    
    private(set) var lastUploadTimeBloodGlucoseSamples = NSDate.distantPast()
    private(set) var lastUploadCountBloodGlucoseSamples = 0
    private(set) var totalUploadCountBloodGlucoseSamples = 0
    
    private(set) var isUploading = false
    
    enum Notifications {
        static let UploadedBloodGlucoseSamples = "HealthKitDataUpload-uploaded-\(HKQuantityTypeIdentifierBloodGlucose)"
    }
    
    // MARK: Upload    
    
    var hasSamplesToUpload: Bool {
        get {
            var hasSamplesToUpload = false

            if HealthKitManager.sharedInstance.isHealthDataAvailable {
                do {
                    let realm = try Realm()
                    
                    let samples = realm.objects(HealthKitData).filter("healthKitTypeIdentifier = '\(HKQuantityTypeIdentifierBloodGlucose)'")
                    let sampleCount = samples.count
                    hasSamplesToUpload = sampleCount > 0
                    if hasSamplesToUpload {
                        DDLogInfo("There are \(sampleCount) samples available to upload")
                    }
                } catch let error as NSError! {
                    DDLogError("Error gathering samples to upload \(error), \(error.userInfo)")
                }
            }
            
            return hasSamplesToUpload
        }
    }
    
    func finishBatchUpload() {
        DDLogVerbose("trace")

        guard isUploading else {
            DDLogInfo("Not currently uploading, ignoring request to stop uploading")
            return
        }

        isUploading = false
    }
    
    func startBatchUpload(userId userId: String, startBatchUploadHandler: (postBody: NSData, availableSamplesCount: Int) -> (Void)) {
        DDLogVerbose("trace")
        
        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, ignoring request to upload")
            return
        }

        guard !isUploading else {
            DDLogError("Already uploading, ignoring subsequent request to upload")
            return
        }
        
        do {
            let realm = try Realm()
            
            let samples = realm.objects(HealthKitData).filter("healthKitTypeIdentifier = '\(HKQuantityTypeIdentifierBloodGlucose)'").sorted("createdAt")
            let samplesCount = samples.count
            guard samplesCount > 0 else {
                DDLogError("Unexpected call to startBatchUpload, no samples available to upload")
                return
            }
            let firstSample = samples[0]
            
            let now = NSDate()
            let dateFormatter = NSDateFormatter()
            let timeZoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT / 60
            let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
            let appBuild = NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as! String
            let appBundleIdentifier = NSBundle.mainBundle().bundleIdentifier!
            let version = "\(appBundleIdentifier):\(appVersion):\(appBuild)"
            let time = dateFormatter.isoStringFromDate(now)
            let uploadId = "upid_HealthKit_\(version)_\(time)"
            
            self.batchUploadDict = [String: AnyObject]()
            self.batchUploadDict["type"] = "upload"
            self.batchUploadDict["computerTime"] = dateFormatter.isoStringFromDate(now, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
            self.batchUploadDict["time"] = time
            self.batchUploadDict["timezoneOffset"] = timeZoneOffset
            self.batchUploadDict["timezone"] = NSTimeZone.localTimeZone().name
            self.batchUploadDict["timeProcessing"] = "none"
            self.batchUploadDict["version"] = version
            self.batchUploadDict["guid"] = NSUUID().UUIDString
            self.batchUploadDict["uploadId"] = uploadId
            self.batchUploadDict["byUser"] = userId
            self.batchUploadDict["deviceTags"] = ["cgm"]
            self.batchUploadDict["deviceManufacturers"] = ["Dexcom"]
            self.batchUploadDict["deviceSerialNumber"] = ""
            self.batchUploadDict["deviceId"] = UIDevice.currentDevice().identifierForVendor!.UUIDString
            self.batchUploadDict["deviceModel"] = "DexHealthKit_\(firstSample.sourceName):\(firstSample.sourceBundleIdentifier):\(firstSample.sourceVersion)" // TODO: my - 0 - If we are using a deviceModel with source name/bundle/version, then we probably need to be batching uploads from the same deviceModel, as chrome-uploader does.
            
            let postBody: NSData?
            do {
                postBody = try NSJSONSerialization.dataWithJSONObject(self.batchUploadDict, options: NSJSONWritingOptions.PrettyPrinted)
                if defaultDebugLevel != DDLogLevel.Off {
                    let postBodyString = NSString(data: postBody!, encoding: NSUTF8StringEncoding)! as String
                    DDLogVerbose("Start batch upload JSON: \(postBodyString)")
                }
                
                // Delegate the upload
                self.isUploading = true
                startBatchUploadHandler(postBody: postBody!, availableSamplesCount: samplesCount)
            } catch let error as NSError! {
                DDLogError("Error creating post body for start of batch upload: \(error.userInfo)")
            }
        } catch let error as NSError! {
            DDLogError("Error gathering samples to upload \(error), \(error.userInfo)")
        }
    }

    func uploadNextForBatch(uploadHandler: (error: NSError?, postBody: NSData?, samplesCount: Int, remainingSamplesCount: Int, completion: (NSError?) -> (Void)) -> Void) {
        DDLogVerbose("trace")
        
        var error: NSError?
        var postBody: NSData?
        var samplesToUploadCount = 0
        var remainingSamplesToUploadCount = 0
        var completion = { (error: NSError?) -> Void in }
        
        defer {
            if error != nil {
                DDLogError("Error preparing to upload: \(error), \(error?.userInfo)")
            } else {
                if defaultDebugLevel != DDLogLevel.Off {
                    let postBodyString = NSString(data: postBody!, encoding: NSUTF8StringEncoding)! as String
                    DDLogVerbose("Samples to upload JSON: \(postBodyString)")
                }
            }
            uploadHandler(error: error, postBody: postBody, samplesCount: samplesToUploadCount, remainingSamplesCount: remainingSamplesToUploadCount, completion: completion)
        }
        
        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            error = NSError(domain: "HealthKitDataUploader", code: -1, userInfo: [NSLocalizedDescriptionKey:"Health data not available, ignoring request to upload"])
            return
        }

        guard isUploading else {
            error = NSError(domain: "HealthKitDataUploader", code: -2, userInfo: [NSLocalizedDescriptionKey:"Unexpected call to uploadNextForBatch without initial call to startBatchUpload"])
            return
        }

        do {
            let realm = try Realm()

            // Determine which samples to upload
            let samples = realm.objects(HealthKitData).filter("healthKitTypeIdentifier = '\(HKQuantityTypeIdentifierBloodGlucose)'").sorted("createdAt")
            let samplesCount = samples.count
            samplesToUploadCount = min(100, samples.count)
            remainingSamplesToUploadCount = samples.count - samplesToUploadCount
            var samplesToUpload = [HealthKitData]()
            for i in 0..<samplesToUploadCount {
                samplesToUpload.append(samples[i])
            }
            DDLogInfo("Attempting to upload \(samplesToUploadCount) of \(samplesCount) samples")

            // Set up completion
            completion = { (error: NSError?) -> Void in
                if error == nil {
                    DDLogInfo("Successfully uploaded \(samplesToUploadCount) of \(samplesCount) samples")
                    do {
                        let realm = try Realm()

                        // If successful, delete from realm
                        try realm.write {
                            for sample in samplesToUpload {
                                realm.delete(sample)
                            }
                            DDLogInfo("Deleted \(samplesToUpload.count) samples from db after uploading to server")
                        }
                        
                        self.updateLastUploadBloodGlucoseSamples(samplesToUploadCount)
                    } catch let error as NSError! {
                        DDLogError("Error removing samples from cache after successful upload: \(error), \(error.userInfo)")
                    }
                } else {
                    DDLogError("Error uploading samples: \(error), \(error?.userInfo)")
                }
            }
            
            // Prepare upload post body
            let dateFormatter = NSDateFormatter()
            var samplesToUploadDictArray = [[String: AnyObject]]()
            for sample in samplesToUpload {
                var sampleToUploadDict = [String: AnyObject]()
                sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                // sampleToUploadDict["timezoneOffset"] = sample.timeZoneOffset // Don't include this since really sourced from local time of phone at time sample is cached
                // sampleToUploadDict["deviceTime"] = dateFormatter.isoStringFromDate(sample.startDate, zone: NSTimeZone.localTimeZone(), dateFormat: iso8601dateNoTimeZone) // TODO: my - consider adding this back if we have "receiver display time" metadata (e.g. from Dexcom Share / G4)
                sampleToUploadDict["deviceId"] = self.batchUploadDict["deviceId"]
                sampleToUploadDict["type"] = "cbg"
                sampleToUploadDict["value"] = sample.value
                sampleToUploadDict["units"] = sample.units
                sampleToUploadDict["uploadId"] = self.batchUploadDict["uploadId"]
                sampleToUploadDict["guid"] = sample.id
                sampleToUploadDict["payload"] = sample.metadataDict
                
                samplesToUploadDictArray.append(sampleToUploadDict)
            }
            
            postBody = try NSJSONSerialization.dataWithJSONObject(samplesToUploadDictArray, options: NSJSONWritingOptions.PrettyPrinted)
        } catch let internalError as NSError? {
            error = internalError
        }
    }
    
    // MARK: Private

    private var batchUploadDict = [String: AnyObject]()
    
    private func updateLastUploadBloodGlucoseSamples(samplesUploadedCount: Int) {
        DDLogVerbose("trace")

        if samplesUploadedCount > 0 {
            self.lastUploadTimeBloodGlucoseSamples = NSDate()
            self.lastUploadCountBloodGlucoseSamples = samplesUploadedCount
            self.totalUploadCountBloodGlucoseSamples += samplesUploadedCount

            NSUserDefaults.standardUserDefaults().setObject(lastUploadTimeBloodGlucoseSamples, forKey: "lastUploadTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastUploadCountBloodGlucoseSamples, forKey: "lastUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setObject(totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.UploadedBloodGlucoseSamples, object: nil))
            }
        }
    }
}
