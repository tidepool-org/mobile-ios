//
//  HealthKitBGInterface.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

/*
 * Copyright (c) 2017, Tidepool Project
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

import UIKit
import CoreData
import SwiftyJSON
import HealthKit
import CocoaLumberjack

/// Downloads Tidepool blood glucose data samples and pushes them to HealthKit, with compare only-option.
///
/// Notes:
///
/// HealthKit data is first fetched to compare to the Tidepool data, and data already in HealthKit is not pushed. If the user has only enabled write to HealthKit but not read, duplicate data may be pushed.
class HealthKitBGInterface: NSObject {
    
    static let sharedInstance = HealthKitBGInterface()
    
    fileprivate override init() {
        //NSLog("")
    }
    
    func checkInterfaceEnabled() -> Bool {
        let hkManager = HealthKitManager.sharedInstance
        let hkCurrentEnable = hkManager.isHealthDataAvailable &&
        hkManager.authorizationRequestedForBloodGlucoseSamples() && hkManager.authorizationRequestedForBloodGlucoseSampleWrites()
        if !hkCurrentEnable {
            // first time download is attempted, need user authorization
            HealthKitManager.sharedInstance.authorize(shouldAuthorizeBloodGlucoseSampleReads: true, shouldAuthorizeBloodGlucoseSampleWrites: true, shouldAuthorizeWorkoutSamples: false) {
                success, error -> Void in
                
                if (error == nil) {
                    self.enabled = true
                } else {
                    NSLog("Error authorizing health data \(String(describing: error)), \(error!.userInfo)")
                }
            }
            return false
        } else {
            self.enabled = true
            return true
        }
    }
    
    // MARK: - Config
    
    fileprivate(set) var enabled = false
    
    /// Call if abandoning current sync...
    func abortSyncInProgress() {
        syncInProgress = false
        currentSyncGeneration += 1
    }
    
    /// Called to start the download
    func syncTidepoolData(from: Date, to: Date, verifyOnly: Bool = false, _ completion: @escaping (Int) -> Void) {
        if self.enabled {
            NSLog("")
            NSLog("Download/verify date range from \(from) to \(to)")
            downloadNewItemsForHealthKit(fromDate: from, toDate: to, verifyOnly: verifyOnly) { (itemsDownloaded) -> Void in
                if verifyOnly {
                    NSLog("BGTool found that \(itemsDownloaded) HK blood glucose reading(s) are missing from Tidepool.")
                } else {
                    NSLog("BGTool added \(itemsDownloaded) blood glucose reading(s) from Tidepool to the Health app.")
                }
                DispatchQueue.main.async {
                    completion(itemsDownloaded)
                }
            }
        } else{
            completion(0)
        }
    }
    

    //
    // Private Vars
    //
    
    // increment each time we turn off the interface in order to kill off async processes
    private var currentSyncGeneration = 0
    // set during a sync to prevent another sync being kicked off...
    private var syncInProgress = false
    
    //
    // Private Methods
    //
    
    /// Step 1. Kick off a sync if current HealthKit user is logged in, a sync process is not already running, and enough time has elapsed since the last sync.
    ///
    /// Starts an async load of data from the Tidepool service, and on completion continues the sync process by calling fetchLatestCachedData. Note that all Tidepool data is downloaded, not just the blood glucose samples, so this also serves to refresh the local database cache of Tidepool items for the application.
    ///
    /// Completion is called with: -1 on errors, 0 if no data was pushed, or positive count of new items sent to HealthKit.
    fileprivate func downloadNewItemsForHealthKit(fromDate: Date, toDate: Date, verifyOnly: Bool = false, _ completion: @escaping (Int) -> Void) {
        
        if !self.enabled {
            NSLog("ignoring call, HealthKit is not enabled!")
            completion(-1)
            return
        }
        
        if syncInProgress {
            NSLog("ignoring call, already syncing!")
            completion(-1)
            return
        }
        
        if !APIConnector.connector().serviceAvailable() {
            NSLog("skipping sync, no service available!")
            completion(-1)
            return
        }
        
        // Start sync - from this point forward use finishSync to turn off syncInProgress when finished!
        syncInProgress = true
        self.currentSyncGeneration += 1
        let syncGen = self.currentSyncGeneration
        
        // TODO: shortcut by zeroing datebase before starting any syncing, so compares aren't necessary; ideally skip the database entirely, but right now leverage the code to constitute bg sample objects from json.
        // first load up data from Tidepool service for this timeframe
        APIConnector.connector().getReadOnlyUserData(fromDate, endDate: toDate, objectTypes: "cbg") { (result) -> (Void) in
            if result.isSuccess {
                let json = result.value!
                //NSLog("getReadOnlyUserData success!")
                if syncGen == self.currentSyncGeneration {
                    //NSLog("Events from \(fromDate) to \(toDate): \(json)")
                    let itemsToPush = self.processJsonToItemsForHealthKit(json)
                         // Before pushing to HK, read what HK already has to avoid pushing duplicates
                    self.fetchCurrentHKData(syncGen, fromTime: fromDate, thruTime: toDate, itemsToPush: itemsToPush, verifyOnly: verifyOnly) { (itemsDownloaded) -> Void in
                        self.finishSync(syncGen, itemsSynced: itemsDownloaded, completion: completion)
                    }
                } else {
                    NSLog("assuming current sync was aborted!")
                    self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                }
            } else {
                    NSLog("getReadOnlyUserData failed!")
                    self.finishSync(syncGen, itemsSynced: 0, completion: completion)
            }
        }
        // This process continues next in fetchCurrentHKData
    }
    
    fileprivate func finishSync(_ syncGen: Int, itemsSynced: Int, completion: (Int) -> Void) {
        if syncGen == currentSyncGeneration {
            syncInProgress = false
            completion(itemsSynced)
        }
    }
    
    /// Step 2. Fetch the latest blood glucose samples from the local Tidepool item database cache (now that it has been refreshed), and turn them into an array of HKQuantitySample items for HealthKit.
    ///
    /// Kick off an async HealthKit query to get current samples already in HealthKit to compare so we don't push duplicates.
    fileprivate func fetchCurrentHKData(_ syncGen: Int, fromTime: Date, thruTime: Date, itemsToPush: [HKSample], verifyOnly: Bool = false, completion: @escaping (Int) -> Void) {
        //NSLog("")
        
        if !itemsToPush.isEmpty || verifyOnly {
            // Before pushing to HK, read what HK already has to avoid pushing duplicates
            readBGSamplesFromHealthKit(fromTime, thruTime: thruTime) { (samples, error) -> Void in
                DispatchQueue.main.async(execute: { () -> Void in
                    if syncGen != self.currentSyncGeneration {
                        NSLog("assuming current sync was aborted!")
                        self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                        return
                    }
                    // Note: bail on errors so we avoid pushing duplicate data to HealthKit!
                    if let error = error {
                        NSLog("Error reading bg samples from HealthKit Store: \(error.localizedDescription)")
                        self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                        return
                    }
                    var itemsAlreadyInHK = [HKSample]()
                    if let samples = samples {
                        itemsAlreadyInHK = samples
                        //NSLog("successfully read \(itemsAlreadyInHK.count) HealthKit items to compare")
                    }
                    if verifyOnly {
                        let notInTidepoolCount = self.verifyHKItemsAreInTidepool(itemsInTidepool: itemsToPush, itemsAlreadyInHK: itemsAlreadyInHK)
                        completion(notInTidepoolCount)
                        return
                    } else {
                        self.pushNewItemsToHealthKit(syncGen, itemsToPush: itemsToPush, itemsAlreadyInHK: itemsAlreadyInHK, completion: completion)
                    }
                })
            }
        } else {
            // No items found in Tidepool...
            completion(0)
        }
        // The saga completes in the next function...
    }
    
    /// Returns the count of any items in itemsAlreadyInHK that don't match an item with the same date and value in itemsInTidepool.
    private func verifyHKItemsAreInTidepool(itemsInTidepool: [HKSample], itemsAlreadyInHK: [HKSample]) -> Int {
        // Remove samples in itemsToPush that match items in itemsAlreadyInHK
        NSLog("verify \(itemsAlreadyInHK.count) healthkit items against \(itemsInTidepool.count) Tidepool items...")
        var hkItemsMissingInTidepool: [HKSample] = []
        
        // set of Tidepool item dates, use these as id's for now, assume values will match...
        var tidepoolItemsByDate = Set<Date>()
        
        // use date for unique id...
        for item in itemsInTidepool {
            tidepoolItemsByDate.insert(item.startDate)
        }
        
        // first add id's of these HealthKit items to our exclusion list
        for item in itemsAlreadyInHK {
            var value: Double = -1
            if let item = item as? HKQuantitySample {
                let unit = HKUnit(from: "mg/dL")
                value = item.quantity.doubleValue(for: unit)
            }
            //NSLog("verifying HK item at date: \(item.startDate) with value: \(value)")
            if !tidepoolItemsByDate.contains(item.startDate) {
                hkItemsMissingInTidepool.append(item)
                NSLog("MISSING: HK item with no corresponding Tidepool item at: time \(item.startDate) and value: \(value)")
            }
        }
        
        return hkItemsMissingInTidepool.count
    }

    /// Filter out any duplicates in HealthKit, then push any remaining new samples to HealthKit, completing the process with a call to the original completion routine that kicked it off.
    private func pushNewItemsToHealthKit(_ syncGen: Int, itemsToPush: [HKSample], itemsAlreadyInHK: [HKSample], completion: @escaping (Int) -> Void) {
        // Remove samples in itemsToPush that match items in itemsAlreadyInHK
        NSLog("check existing healthkit items for matches...")
        var tidepoolItemsInHKCount = 0
        
        // set of Tidepool id's successfully pushed
        var tidepoolIdsPushedToHealthKit = Set<String>()
        var newItemsToPush = itemsToPush

        if !itemsAlreadyInHK.isEmpty {
            // first add id's of these HealthKit items to our exclusion list
            for item in itemsAlreadyInHK {
                var value: Double = -1
                if let item = item as? HKQuantitySample {
                    let unit = HKUnit(from: "mg/dL")
                    value = item.quantity.doubleValue(for: unit)
                }
                if let metaDataDict = item.metadata {
                    if let tidepoolId = metaDataDict["tidepoolId"] {
                        tidepoolIdsPushedToHealthKit.insert(tidepoolId as! String)
                        tidepoolItemsInHKCount += 1
                        //NSLog("existing HK item at time \(item.startDate), value: \(value)")
                    } else {
                        NSLog("ignoring HK item with no tidepoolId metadata: time \(item.startDate) and value: \(value)")
                    }
                } else {
                    NSLog("ignoring HK item with no metaDataDict: time \(item.startDate) and value: \(value)")
                }
            }
            
            // next filter out any items in our push array that match items in the exclusion list
            if tidepoolItemsInHKCount > 0 {
                newItemsToPush = itemsToPush.filter() {item in
                    if let metaDataDict = item.metadata {
                        if let tidepoolId = metaDataDict["tidepoolId"] {
                            if tidepoolIdsPushedToHealthKit.contains(tidepoolId as! String) {
                                //NSLog("filtered out item with tidepool id: \(tidepoolId)")
                                return false
                            }
                        }
                    }
                    return true
                }
            }
        }

        // Finally, if there are any new items, push them to HealthKit now...
        if !newItemsToPush.isEmpty {
            
            HealthKitManager.sharedInstance.healthStore!.save(newItemsToPush, withCompletion: { (success, error) -> Void in
                if syncGen != self.currentSyncGeneration {
                    NSLog("assuming current sync was aborted!")
                    self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                    return
                }
                if error != nil {
                    NSLog("Error pushing \(newItemsToPush.count) glucose samples to HealthKit: \(error!.localizedDescription)")
                    self.finishSync(syncGen, itemsSynced: -1, completion: completion)
                } else {
                    NSLog("\(newItemsToPush.count) Blood glucose samples pushed to HealthKit successfully!")
                    self.finishSync(syncGen, itemsSynced: newItemsToPush.count, completion: completion)
                }
            })
        } else {
            NSLog("no new items to push to HealthKit!")
            self.finishSync(syncGen, itemsSynced: 0, completion: completion)
        }
    }
    
    /// Do an async read of current blood glucose samples from HealthKit for a date range, passing along results to the completion method.
    fileprivate func readBGSamplesFromHealthKit(_ fromTime: Date, thruTime: Date, completion: @escaping ([HKSample]?, NSError?) -> Void)
    {
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        let timeRangePredicate = HKQuery.predicateForSamples(withStart: fromTime, end: thruTime, options: HKQueryOptions())
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: true)
        let limit = Int(HKObjectQueryNoLimit)
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: timeRangePredicate, limit: limit, sortDescriptors: [sortDescriptor])
        { (sampleQuery, results, error ) -> Void in
            completion(results, error as NSError?)
        }
        HealthKitManager.sharedInstance.healthStore!.execute(sampleQuery)
    }
    
    class TidepoolValue {
        var id: String?
        var type: String?
        var time: Date?
        var deviceId: String?
        var value: Double?
        var userEntered: NSNumber?
    }

    /// Processes a JSON string, adding smbg items into the itemsToPush array  as HKQuantitySample events for HealthKit.
    private func processJsonToItemsForHealthKit(_ eventsJSON: JSON) -> [HKQuantitySample] {
        
        var itemsToPush = [HKQuantitySample]()
        let kGlucoseConversionToMgDl: Double = 18.0
        for (_, json) in eventsJSON {
            //NSLog("next json: \(json)")
            let event = TidepoolValue()
            event.type = json["type"].string
            if let type = event.type {
                if /*type == "smbg" ||*/ type == "cbg" {
                    event.id = json["id"].string
                    event.time = TidepoolMobileUtils.dateFromJSON(json["time"].string)
                    event.deviceId = json["deviceId"].string
                    if let value = json["value"].number {
                        event.value = round(Double(value.floatValue) * kGlucoseConversionToMgDl)
                    }
                    if let subType = json["subType"].string {
                        if subType == "manual" {
                            event.userEntered = 1
                        }
                    }
                    if let nextSample = processNextEvent(event) {
                        itemsToPush.append(nextSample)
                    }
                }
            }
        }
        
        return itemsToPush
    }

    private func processNextEvent(_ event: TidepoolValue) -> HKQuantitySample? {
        if let value = event.value, let itemId = event.id, let time = event.time, let type = event.type {
            let bgType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
            let bgQuantity = HKQuantity(unit: HKUnit(from: "mg/dL"), doubleValue: value)
            let deviceId = event.deviceId ?? ""
            // TODO: add guid to metadata as well, need to rev data model to add this...
            var metadata: [String: AnyObject] = ["tidepoolId": itemId as AnyObject, "deviceId": deviceId as AnyObject, "type": type as AnyObject]
            if let userEntered = event.userEntered {
                metadata[HKMetadataKeyWasUserEntered] = userEntered
            }
            let bgSample = HKQuantitySample(type: bgType!, quantity: bgQuantity, start: time as Date, end: time as Date, metadata: metadata)
            //NSLog("candidate Tidepool item at time: \(time), value: \(bgQuantity)")
            return bgSample
        } else {
            NSLog("item not a valid blood glucose event!")
            return nil
        }
    }
    
}


