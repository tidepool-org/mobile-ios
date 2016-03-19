/*
* Copyright (c) 2015, Tidepool Project
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

// TODO: my - Need to set up a periodic task to perodically drain the Realm db and upload those events to service, this should be able to be done as background task even when app is not active, and periodically when active

class HealthKitDataCache {
    // MARK: Access, authorization
    
    static let sharedInstance = HealthKitDataCache()
    private init() {
        DDLogVerbose("trace")
        
        var config = Realm.Configuration(
            schemaVersion: 7,

            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 7 {
                    DDLogInfo("Migrating Realm to schema version 7")
                    
                    migration.deleteData("HealthKitData")
                    DDLogInfo("Deleted all realm objects during migration")
                    
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadTimeBloodGlucoseSamples")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("lastUploadCountBloodGlucoseSamples")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("totalUploadCountBloodGlucoseSamples")
                
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("bloodGlucoseQueryAnchor")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("lastCacheTimeBloodGlucoseSamples")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("lastCacheCountBloodGlucoseSamples")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("totalCacheCountBloodGlucoseSamples")

                    NSUserDefaults.standardUserDefaults().removeObjectForKey("workoutQueryAnchor")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("lastCacheTimeWorkoutSamples")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("lastCacheCountWorkoutSamples")
                    NSUserDefaults.standardUserDefaults().removeObjectForKey("totalCacheCountWorkoutSamples")

                    DDLogInfo("Reset cache and upload stats and HealthKit query anchors during migration")
                }
            }
        )
        
        // Append nosync to avoid iCloud backup of realm db
        config.path = NSURL.fileURLWithPath(config.path!)
            .URLByAppendingPathExtension("nosync")
            .path
        
        DDLogInfo("Realm path: \(config.path)")
        
        // Set this as the configuration used for the default Realm
        Realm.Configuration.defaultConfiguration = config

        // Force early migration (if needed)
        do {
            let _ = try Realm()
        } catch let error as NSError {
            DDLogError("Failed initializing realm: \(error)")
        }

        var cacheTime = NSUserDefaults.standardUserDefaults().objectForKey("lastCacheTimeBloodGlucoseSamples")
        if cacheTime != nil {
            lastCacheTimeBloodGlucoseSamples = cacheTime as! NSDate
            lastCacheCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastCacheCountBloodGlucoseSamples")
            totalCacheCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalCacheCountBloodGlucoseSamples")
        }
        
        cacheTime = NSUserDefaults.standardUserDefaults().objectForKey("lastCacheTimeWorkoutSamples")
        if cacheTime != nil {
            lastCacheTimeWorkoutSamples = cacheTime as! NSDate
            lastCacheCountWorkoutSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastCacheCountWorkoutSamples")
            totalCacheCountWorkoutSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalCacheCountWorkoutSamples")
        }
        
        // Set up results handlers
        bloodGlucoseResultHandler = {
            (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in
            
            let newSamplesCount = newSamples?.count ?? 0
            if newSamplesCount > 0 {
                DDLogInfo("********* PROCESSING \(newSamplesCount) new blood glucose samples ********* ")
            }
            
            var deletedSamplesCount = deletedSamples?.count ?? 0
            if deletedSamplesCount > 0 {
                deletedSamplesCount = 0
                DDLogInfo("********* IGNORING \(deletedSamplesCount) deleted blood glucose samples ********* ")
            }
            
            if newSamplesCount > 0 {
                self.writeSamplesToDb(typeIdentifier: HKQuantityTypeIdentifierBloodGlucose, samples: newSamples, deletedSamples: nil, error: error)
                self.updateLastCacheBloodGlucoseSamples(newSamplesCount: newSamplesCount, deletedSamplesCount: deletedSamplesCount)
                if !self.isInitialBloodGlucoseCacheComplete {
                    self.readAndCacheInitialBloodGlucoseSamples()
                }
            } else {
                if !self.isInitialBloodGlucoseCacheComplete {
                    self.isInitialBloodGlucoseCacheComplete = true
                    self.startObservingBloodGlucoseSamples()
                }
            }
        }
        workoutResultHandler = {
            (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in

            let newSamplesCount = newSamples?.count ?? 0
            if newSamplesCount > 0 {
                DDLogInfo("********* PROCESSING \(newSamplesCount) new workout samples ********* ")
            }

            var deletedSamplesCount = deletedSamples?.count ?? 0
            if deletedSamplesCount > 0 {
                deletedSamplesCount = 0
                DDLogInfo("********* IGNORING \(deletedSamplesCount) deleted workout samples ********* ")
            }
            
            if newSamplesCount > 0 {
                self.writeSamplesToDb(typeIdentifier: HKWorkoutTypeIdentifier, samples: newSamples, deletedSamples: nil, error: error)
                self.updateLastCacheWorkoutSamples(newSamplesCount: newSamplesCount, deletedSamplesCount: deletedSamplesCount)                
                if !self.isInitialWorkoutCacheComplete {
                    self.readAndCacheInitialWorkoutSamples()
                }
            } else {
                if !self.isInitialWorkoutCacheComplete {
                    self.isInitialWorkoutCacheComplete = true
                    self.startObservingWorkoutSamples()
                }
            }
        }
    }
    
    private(set) var lastCacheTimeBloodGlucoseSamples = NSDate.distantPast()
    private(set) var lastCacheCountBloodGlucoseSamples = 0
    private(set) var totalCacheCountBloodGlucoseSamples = 0

    private(set) var lastCacheTimeWorkoutSamples = NSDate.distantPast()
    private(set) var lastCacheCountWorkoutSamples = 0
    private(set) var totalCacheCountWorkoutSamples = 0
    
    var totalCacheCount: Int {
        get {
            DDLogVerbose("trace")

            return totalCacheCountBloodGlucoseSamples + totalCacheCountWorkoutSamples
        }
    }
    
    var lastCacheCount: Int {
        get {
            DDLogVerbose("trace")

            return lastCacheCountBloodGlucoseSamples + lastCacheCountWorkoutSamples
        }
    }
    
    var lastCacheTime: NSDate {
        get {
            DDLogVerbose("trace")
            
            var time = lastCacheTimeBloodGlucoseSamples
            if time.compare(lastCacheTimeWorkoutSamples) == .OrderedAscending {
                time = lastCacheTimeWorkoutSamples
            }
            return time
        }
    }
    
    enum Notifications {
        static let CachedBloodGlucoseSamples = "HealthKitDataCache-observed-\(HKQuantityTypeIdentifierBloodGlucose)"
        static let CachedWorkoutSamples = "HealthKitDataCache-observed-\(HKWorkoutTypeIdentifier)"
    }

    func authorizeAndStartCaching(
            shouldCacheBloodGlucoseSamples shouldCacheBloodGlucoseSamples: Bool,
            shouldCacheWorkoutSamples: Bool)
    {
        DDLogVerbose("trace")

        HealthKitManager.sharedInstance.authorize(
            shouldAuthorizeBloodGlucoseSamples: shouldCacheBloodGlucoseSamples,
            shouldAuthorizeWorkoutSamples: shouldCacheWorkoutSamples) {
            success, error -> Void in
                
            if error == nil {
                self.startCaching(
                    shouldCacheBloodGlucoseSamples: shouldCacheBloodGlucoseSamples,
                    shouldCacheWorkoutSamples: shouldCacheWorkoutSamples)
            } else {
                DDLogError("Error authorizing health data \(error), \(error!.userInfo)")
            }
        }
    }
    
    // MARK: Cache control
    
    func startCaching(shouldCacheBloodGlucoseSamples shouldCacheBloodGlucoseSamples: Bool, shouldCacheWorkoutSamples: Bool)
    {
        DDLogVerbose("trace")

        guard HealthKitManager.sharedInstance.isHealthDataAvailable else {
            DDLogError("Health data not available, ignoring request to start caching")
            return
        }
        
        if HealthKitManager.sharedInstance.authorizationRequestedForBloodGlucoseSamples() {
            if shouldCacheBloodGlucoseSamples && !self.isCachingBloodGlucoseSamples {
                self.isCachingBloodGlucoseSamples = true
                
                if self.isInitialBloodGlucoseCacheComplete {
                    self.startObservingBloodGlucoseSamples()
                } else {
                    self.readAndCacheInitialBloodGlucoseSamples()
                }
                
                HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()
            }
        }
        
        if HealthKitManager.sharedInstance.authorizationRequestedForWorkoutSamples() {
            if shouldCacheWorkoutSamples && !self.isCachingWorkoutSamples {
                self.isCachingWorkoutSamples = true
                
                if self.isInitialWorkoutCacheComplete {
                    self.startObservingWorkoutSamples()
                } else {
                    self.readAndCacheInitialWorkoutSamples()
                }
                
                HealthKitManager.sharedInstance.enableBackgroundDeliveryWorkoutSamples()
            }
            
        }
    }
    
    func stopCaching(shouldStopCachingBloodGlucoseSamples shouldStopCachingBloodGlucoseSamples: Bool, shouldStopCachingWorkoutSamples: Bool) {
        DDLogVerbose("trace")

        if HealthKitManager.sharedInstance.isHealthDataAvailable {
            if shouldStopCachingBloodGlucoseSamples && self.isCachingBloodGlucoseSamples {
                if self.isObservingBloodGlucoseSamples {
                    HealthKitManager.sharedInstance.stopObservingBloodGlucoseSamples()
                    self.isObservingBloodGlucoseSamples = false
                }
                HealthKitManager.sharedInstance.disableBackgroundDeliveryBloodGlucoseSamples()
                self.isCachingBloodGlucoseSamples = false
            }
            
            if shouldStopCachingWorkoutSamples && self.isCachingWorkoutSamples {
                if self.isObservingWorkoutSamples {
                    HealthKitManager.sharedInstance.stopObservingWorkoutSamples()
                    self.isObservingWorkoutSamples = false
                }
                HealthKitManager.sharedInstance.disableBackgroundDeliveryWorkoutSamples()
                self.isCachingWorkoutSamples = false
            }
        }
    }
    
    // MARK: Private

    private func startObservingBloodGlucoseSamples() {
        if !self.isObservingBloodGlucoseSamples {
            HealthKitManager.sharedInstance.startObservingBloodGlucoseSamples(self.bloodGlucoseResultHandler)
            self.isObservingBloodGlucoseSamples = true
        }
    }

    private func readAndCacheInitialBloodGlucoseSamples() {
        HealthKitManager.sharedInstance.readBloodGlucoseSamples(self.bloodGlucoseResultHandler)
    }

    private func startObservingWorkoutSamples() {
        if !self.isObservingWorkoutSamples {
            HealthKitManager.sharedInstance.startObservingWorkoutSamples(self.workoutResultHandler)
            self.isObservingWorkoutSamples = true
        }
    }

    private func readAndCacheInitialWorkoutSamples() {
        HealthKitManager.sharedInstance.readBloodGlucoseSamples(self.workoutResultHandler)
    }

    private func writeSamplesToDb(typeIdentifier typeIdentifier: String, samples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) {
        DDLogVerbose("trace")

        guard error == nil else {
            DDLogError("Error processing samples \(error), \(error!.userInfo)")
            return
        }
        
        if samples != nil {
            writeNewSamplesToDb(typeIdentifier: typeIdentifier, samples: samples!)
        }
        
        if deletedSamples != nil {
            writeDeletedSamplesToDb(deletedSamples!)
        }
    }
    
    private func writeNewSamplesToDb(typeIdentifier typeIdentifier: String, samples: [HKSample]) {
        DDLogVerbose("trace")

        do {
            let realm = try Realm()

            realm.beginWrite()
            
            for sample in samples {
                let sourceRevision = sample.sourceRevision
                let source = sourceRevision.source
                let sourceName = source.name
                let sourceBundleIdentifier = source.bundleIdentifier
                let sourceVersion = sourceRevision.version
                
                let device = sample.device
                let deviceName = device?.name
                let deviceManufacturer = device?.manufacturer
                let deviceModel = device?.model
                let deviceHardwareVersion = device?.hardwareVersion
                let deviceFirmwareVersion = device?.firmwareVersion
                let deviceSoftwareVersion = device?.softwareVersion
                let deviceLocalIdentifier = device?.localIdentifier
                let deviceUDIDeviceIdentifier = device?.UDIDeviceIdentifier
                
                let healthKitData = HealthKitData()

                switch typeIdentifier {
                case HKQuantityTypeIdentifierBloodGlucose:
                    if sourceName.lowercaseString.rangeOfString("dexcom") == nil {
                        DDLogInfo("Ignoring non-Dexcom glucose data")
                        continue
                        //Debug/Test: uncomment the following and turn into var's from let's above to allow posting manually entered HealthKit blood glucose samples to be sent to service as Dexcom values. (Dangerous!).
                        //sourceName = "Dexcom"
                        //sourceBundleIdentifier = "com.dexcom.CGM.OUS.MMOL.R01"
                        //sourceVersion = "1"
                    }
                    
                    if let quantitySample = sample as? HKQuantitySample {
                        healthKitData.units = "mg/dL"
                        let unit = HKUnit(fromString: healthKitData.units)
                        healthKitData.value = quantitySample.quantity.doubleValueForUnit(unit)
                    }
                case HKWorkoutTypeIdentifier:
                    DDLogError("TODO: HKWorkoutTypeIdentifier not yet fully implemented, need to add some workout data to the cache if we're going to support uploading workout data to service")
                    continue
                default:
                    DDLogError("Unsupported HealthKit type: \(typeIdentifier)")
                    continue
                }
                
                healthKitData.id = sample.UUID.UUIDString
                healthKitData.healthKitTypeIdentifier = typeIdentifier
                healthKitData.action = HealthKitData.Action.Added.rawValue
                healthKitData.sourceName = sourceName
                healthKitData.sourceBundleIdentifier = sourceBundleIdentifier
                healthKitData.sourceVersion = sourceVersion ?? ""
                healthKitData.startDate = sample.startDate
                healthKitData.endDate = sample.endDate
                healthKitData.metadataDict = sample.metadata

                DDLogInfo("Writing new sample to cache:")
                
                DDLogInfo("\tSource:")
                DDLogInfo("\t\tName: \(sourceName)")
                DDLogInfo("\t\tBundleIdentifier: \(sourceBundleIdentifier)")
                DDLogInfo("\t\tVersion: \(sourceVersion)")
                
                DDLogInfo("\tDevice:")
                DDLogInfo("\t\tName: \(deviceName)")
                DDLogInfo("\t\tManufacturer: \(deviceManufacturer)")
                DDLogInfo("\t\tModel: \(deviceModel)")
                DDLogInfo("\t\tHardwareVersion: \(deviceHardwareVersion)")
                DDLogInfo("\t\tFirmwareVersion: \(deviceFirmwareVersion)")
                DDLogInfo("\t\tSoftwareVersion: \(deviceSoftwareVersion)")
                DDLogInfo("\t\tLocalIdentifier: \(deviceLocalIdentifier)")
                DDLogInfo("\t\tUDIDeviceIdentifier: \(deviceUDIDeviceIdentifier)")

                DDLogInfo("\tHealthKitData:")
                DDLogInfo("\t\t\(healthKitData)")
                DDLogInfo("\tHealthKitData metadata:")
                DDLogInfo("\t\t\(healthKitData.metadataDict)")
                
                // TODO: my - Confirm that composite key of id + action does not exist before attempting to add to avoid dups?
                realm.add(healthKitData)
            }
            
            try realm.commitWrite()
        } catch let error as NSError! {
            DDLogError("Error writing new samples \(error), \(error!.userInfo)")
        }
    }
    
    private func writeDeletedSamplesToDb(deletedSamples: [HKDeletedObject]) {
        DDLogVerbose("trace")

        do {
            let realm = try Realm()
            
            try realm.write() {
                for sample in deletedSamples {
                    let healthKitData = HealthKitData()
                    healthKitData.id = sample.UUID.UUIDString
                    healthKitData.action = HealthKitData.Action.Deleted.rawValue

                    DDLogInfo("Deleted sample: \(healthKitData.id)");

                    // TODO: my - Confirm that composite key of id + action does not exist before attempting to add to avoid dups?
                    realm.add(healthKitData)
                }
            }
        } catch let error as NSError! {
            DDLogError("Error writing deleted samples \(error), \(error.userInfo)")
        }
    }
    
    private func updateLastCacheBloodGlucoseSamples(newSamplesCount newSamplesCount: Int, deletedSamplesCount: Int) {
        DDLogVerbose("trace")

        let totalUpdateCount = newSamplesCount + deletedSamplesCount
        if totalUpdateCount > 0 {
            self.lastCacheTimeBloodGlucoseSamples = NSDate()
            self.lastCacheCountBloodGlucoseSamples = totalUpdateCount
            self.totalCacheCountBloodGlucoseSamples += totalUpdateCount
            
            NSUserDefaults.standardUserDefaults().setObject(lastCacheTimeBloodGlucoseSamples, forKey: "lastCacheTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastCacheCountBloodGlucoseSamples, forKey: "lastCacheCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(totalCacheCountBloodGlucoseSamples, forKey: "totalCacheCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.CachedBloodGlucoseSamples, object: nil))
            }
        }
    }
    
    private func updateLastCacheWorkoutSamples(newSamplesCount newSamplesCount: Int, deletedSamplesCount: Int) {
        DDLogVerbose("trace")

        let totalUpdateCount = newSamplesCount + deletedSamplesCount
        if totalUpdateCount > 0 {
            self.lastCacheTimeWorkoutSamples = NSDate()
            self.lastCacheCountWorkoutSamples = totalUpdateCount
            self.totalCacheCountWorkoutSamples += totalUpdateCount
            
            NSUserDefaults.standardUserDefaults().setObject(lastCacheTimeWorkoutSamples, forKey: "lastCacheTimeWorkoutSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastCacheCountWorkoutSamples, forKey: "lastCacheCountWorkoutSamples")
            NSUserDefaults.standardUserDefaults().setObject(totalCacheCountWorkoutSamples, forKey: "totalCacheCountWorkoutSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.CachedWorkoutSamples, object: nil))
            }
        }
    }
    
    private var isCachingBloodGlucoseSamples = false
    private var isCachingWorkoutSamples = false
    private var isInitialBloodGlucoseCacheComplete = false
    private var isInitialWorkoutCacheComplete = false
    private var isObservingBloodGlucoseSamples = false
    private var isObservingWorkoutSamples = false
    private var bloodGlucoseResultHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)! = nil
    private var workoutResultHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)! = nil
}
