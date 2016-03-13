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
        let totalUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamples")
        if totalUploadCountBloodGlucoseSamples > 0 {
            self.totalUploadCountBloodGlucoseSamples = totalUploadCountBloodGlucoseSamples
            self.lastUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastUploadCountBloodGlucoseSamples")
            let lastUploadTimeBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().objectForKey("lastUploadTimeBloodGlucoseSamples")
            if (lastUploadTimeBloodGlucoseSamples != nil) {
                self.lastUploadTimeBloodGlucoseSamples = lastUploadTimeBloodGlucoseSamples as! NSDate
            }
        }
    }
    
    private(set) var totalUploadCountBloodGlucoseSamples = -1
    private(set) var lastUploadCountBloodGlucoseSamples = -1
    private(set) var lastUploadTimeBloodGlucoseSamples = NSDate.distantPast()
    
    var totalUploadCount: Int {
        get {
            var count = 0
            if (lastUploadCountBloodGlucoseSamples > 0) {
                count += lastUploadCountBloodGlucoseSamples
            }
            return count
        }
    }
    
    var lastUploadCount: Int {
        get {
            let time = lastUploadTime
            var count = 0
            if (lastUploadCountBloodGlucoseSamples > 0 && fabs(lastUploadTimeBloodGlucoseSamples.timeIntervalSinceDate(time)) < 60) {
                count += lastUploadCountBloodGlucoseSamples
            }
            return count
        }
    }
    
    var lastUploadTime: NSDate {
        get {
            var time = NSDate.distantPast()
            if (lastUploadCountBloodGlucoseSamples > 0 && time.compare(lastUploadTimeBloodGlucoseSamples) == .OrderedAscending) {
                time = lastUploadTimeBloodGlucoseSamples
            }
            return time
        }
    }
    
    enum Notifications {
        static let UploadedBloodGlucoseSamples = "HealthKitDataUpload-uploaded-\(HKQuantityTypeIdentifierBloodGlucose)"
    }
    
    // MARK: Upload    
    
    var hasSamplesToUpload: Bool {
        get {
            var hasSamplesToUpload = false

            if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
                do {
                    let realm = try Realm()
                    
                    let samples = realm.objects(HealthKitData).filter("healthKitTypeIdentifier = '\(HKQuantityTypeIdentifierBloodGlucose)'").sorted("createdAt")
                    hasSamplesToUpload = samples.count > 0
                } catch let error as NSError! {
                    DDLogError("Error gathering samples to upload \(error), \(error.userInfo)")
                }
            }
            
            if !hasSamplesToUpload {
                DDLogInfo("No samples to upload")
            }
            
            return hasSamplesToUpload
        }
    }
    
    func startBatchUpload(userId userId: String, startBatchUploadHandler: (postBody: NSData, remainingSampleCount: Int) -> (Void)) {
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            do {
                let realm = try Realm()
                
                let samples = realm.objects(HealthKitData).filter("healthKitTypeIdentifier = '\(HKQuantityTypeIdentifierBloodGlucose)'").sorted("createdAt")
                let samplesCount = samples.count
                guard samplesCount > 0 else {
                    DDLogError("Unexpected call to startBatchUpload, no samples to upload")
                    return
                }
                
                let now = NSDate()
                let dateFormatter = NSDateFormatter()
                let timeZoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT / 60
                let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
                let appBuild = NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as! String
                let appBundleIdentifier = NSBundle.mainBundle().bundleIdentifier!
                let version = "\(appBundleIdentifier):\(appVersion):\(appBuild)"
                let time = dateFormatter.isoStringFromDate(now)
                let uploadId = "upid_HealthKit_\(version)_\(time)"
                
                lastBatchUploadDict = [String: AnyObject]()
                lastBatchUploadDict["type"] = "upload"
                lastBatchUploadDict["computerTime"] = dateFormatter.isoStringFromDate(now, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                lastBatchUploadDict["time"] = time
                lastBatchUploadDict["timezoneOffset"] = timeZoneOffset
                lastBatchUploadDict["timezone"] = NSTimeZone.localTimeZone().name
                lastBatchUploadDict["timeProcessing"] = "none"
                lastBatchUploadDict["version"] = version
                lastBatchUploadDict["guid"] = NSUUID().UUIDString
                lastBatchUploadDict["uploadId"] = uploadId
                lastBatchUploadDict["byUser"] = userId
                lastBatchUploadDict["deviceTags"] = ["cgm"]
                lastBatchUploadDict["deviceManufacturers"] = ["Dexcom"]
                lastBatchUploadDict["deviceSerialNumber"] = ""
                                
                let firstSample = samples[0]
                let deviceId = "DexHealthKit_\(firstSample.sourceName):\(firstSample.sourceBundleIdentifier):\(firstSample.sourceVersion)"
                lastBatchUploadDict["deviceId"] = deviceId // TODO: my - 0 - If we are using a deviceId with source name/bundle/version, then we probably needed to be batching uploads from the same source/device, as chrome-uploader does.
                lastBatchUploadDict["deviceModel"] = deviceId
                
                let postBody: NSData?
                do {
                    postBody = try NSJSONSerialization.dataWithJSONObject(lastBatchUploadDict, options: NSJSONWritingOptions.PrettyPrinted)
                } catch let error as NSError! {
                    DDLogError("Error creating post body for start of batch upload \(error), \(error.userInfo)")
                    postBody = nil
                }
                
                // Delegate the upload
                if postBody != nil {
                    if defaultDebugLevel != DDLogLevel.Off {
                        let postBodyString = NSString(data: postBody!, encoding: NSUTF8StringEncoding)! as String
                        DDLogInfo("Start batch upload JSON: \(postBodyString)")
                    }

                    startBatchUploadHandler(postBody: postBody!, remainingSampleCount: samplesCount)
                }
            } catch let error as NSError! {
                DDLogError("Error gathering samples to upload \(error), \(error.userInfo)")
            }
        }
    }

    func uploadNextForBatch(uploadHandler: (postBody: NSData, sampleCount: Int, remainingSampleCount: Int, completion: (NSError?) -> (Void)) -> Void) {
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            do {
                let realm = try Realm()

                // Determine which samples to upload
                let samples = realm.objects(HealthKitData).filter("healthKitTypeIdentifier = '\(HKQuantityTypeIdentifierBloodGlucose)'").sorted("createdAt")
                let samplesCount = samples.count
                let samplesToUploadCount = min(100, samples.count)
                let remainingSamplesToUploadCount = samples.count - samplesToUploadCount
                var samplesToUpload = [HealthKitData]()
                for i in 0..<samplesToUploadCount {
                    samplesToUpload.append(samples[i])
                }
                DDLogInfo("Attempting to upload \(samplesToUploadCount) of \(samplesCount) samples")

                // Set up completion
                let completion = { (error: NSError?) -> Void in
                    if error == nil {
                        DDLogInfo("Successfully uploaded \(samplesToUploadCount) of \(samplesCount) samples")
                        do {
                            let realm = try Realm()

                            // If successful, delete from realm
                            try realm.write {
                                for sample in samplesToUpload {
                                    realm.delete(sample)
                                }
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
                let postBody: NSData?
                var samplesToUploadDictArray = [[String: AnyObject]]()
                for sample in samplesToUpload {
                    let deviceId = "DexHealthKit_\(sample.sourceName):\(sample.sourceBundleIdentifier):\(sample.sourceVersion)"

                    var sampleToUploadDict = [String: AnyObject]()
                    sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: NSTimeZone(forSecondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                    // sampleToUploadDict["timezoneOffset"] = sample.timeZoneOffset // Don't include this since really sourced from local time of phone at time sample is cached
                    // sampleToUploadDict["deviceTime"] = dateFormatter.isoStringFromDate(sample.startDate, zone: NSTimeZone.localTimeZone(), dateFormat: iso8601dateNoTimeZone) // TODO: my - consider adding this back if we have "receiver display time" metadata (e.g. from Dexcom Share / G4)
                    sampleToUploadDict["deviceId"] = deviceId
                    sampleToUploadDict["type"] = "cbg"
                    sampleToUploadDict["value"] = sample.value
                    sampleToUploadDict["units"] = sample.units
                    sampleToUploadDict["uploadId"] = self.lastBatchUploadDict["uploadId"]
                    sampleToUploadDict["guid"] = sample.id
                    sampleToUploadDict["payload"] = sample.metadataDict
                    
                    samplesToUploadDictArray.append(sampleToUploadDict)
                }
                
                do {
                    postBody = try NSJSONSerialization.dataWithJSONObject(samplesToUploadDictArray, options: NSJSONWritingOptions.PrettyPrinted)
                } catch let error as NSError! {
                    DDLogError("Error creating post body for upload \(error), \(error.userInfo)")
                    postBody = nil
                }
                
                // Delegate the upload
                if postBody != nil {
                    if defaultDebugLevel != DDLogLevel.Off {
                        let postBodyString = NSString(data: postBody!, encoding: NSUTF8StringEncoding)! as String
                        DDLogInfo("Samples to upload JSON: \(postBodyString)")
                    }

                    uploadHandler(postBody: postBody!, sampleCount: samplesToUploadCount, remainingSampleCount: remainingSamplesToUploadCount, completion: completion)
                }
            } catch let error as NSError! {
                DDLogError("Error gathering samples to upload \(error), \(error.userInfo)")
            }
        }
    }
    
    // MARK: Private

    private var lastBatchUploadDict = [String: AnyObject]()
    
    private func updateLastUploadBloodGlucoseSamples(samplesUploadedCount: Int) {
        if (samplesUploadedCount > 0) {
            lastUploadCountBloodGlucoseSamples = samplesUploadedCount
            lastUploadTimeBloodGlucoseSamples = NSDate()
            NSUserDefaults.standardUserDefaults().setObject(lastUploadTimeBloodGlucoseSamples, forKey: "lastUploadTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastUploadCountBloodGlucoseSamples, forKey: "lastUploadCountBloodGlucoseSamples")
            let totalUploadCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalUploadCountBloodGlucoseSamples") + lastUploadCountBloodGlucoseSamples
            NSUserDefaults.standardUserDefaults().setObject(totalUploadCountBloodGlucoseSamples, forKey: "totalUploadCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.UploadedBloodGlucoseSamples, object: nil))
            }
        }
    }
}
