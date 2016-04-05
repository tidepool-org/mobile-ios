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

import UIKit
import CoreData
import SwiftyJSON
import HealthKit
import CocoaLumberjack

/// Downloads Tidepool blood glucose data samples and pushes them to HealthKit.
///
/// Notes:
///
/// This syncs a past time interval of Tidepool data on a regular basic with the local HealthKit store. The past time interval is set nominally to the last 7 days, and is done when the HealthKit interface is turned on and about once a day after that - either when the app is run or in the background.
///
/// The latest Tidepool data is downloaded to the store cache (refreshing all Tidepool data for the last week). This has the added feature of keeping that cache up to date on a daily basis, so the user can refer to their recent data if they have no connectivity (except during the sync of course).
///
/// HealthKit data is first fetched to compare to the Tidepool data, and data already in HealthKit is not pushed. If the user has only enabled write to HealthKit but not read,
class HealthKitDataPusher: NSObject {

    static let sharedInstance = HealthKitDataPusher()

    private override init() {
        DDLogVerbose("")
    }

    // MARK: - Config

    /// Sync last 10 days of data
    let kTimeIntervalOfDataToSyncToHK: NSTimeInterval = 60*60*24*10
    /// Check at most every 4 hours...
    let kMinTimeIntervalBetweenSyncs: NSTimeInterval = 60*60*4
    /// But ask for background time every 6 hours...
    let kTimeIntervalForBackgroundFetch: NSTimeInterval = 60*60*4
    
    /// Last time we checked for and pushed data to HealthKit or nil if never pushed
    var lastPushToHK: NSDate? {
        set(newValue) {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: kLastPushOfDataToHKKey)
            NSUserDefaults.standardUserDefaults().synchronize()
            _lastPushToHK = nil
        }
        get {
            if _lastPushToHK == nil {
                let curValue = NSUserDefaults.standardUserDefaults().objectForKey(kLastPushOfDataToHKKey)
                if let date = curValue as? NSDate {
                    _lastPushToHK = date
                }
            }
            return _lastPushToHK
        }
    }
    private var _lastPushToHK: NSDate?
    private let kLastPushOfDataToHKKey = "kLastPushOfDataToHKKey"
   
    /// Called by background fetch code in app delegate, and will kick off a sync if enough time has elapsed and currently HealthKit user is logged in.
    func backgroundFetch(completion: (UIBackgroundFetchResult) -> Void) {
        downloadNewItemsForHealthKit() { (itemsDownloaded) -> Void in
            var msg = "Nutshell added \(itemsDownloaded) blood glucose readings from Tidepool to the Health app."
            if itemsDownloaded == 1 {
                msg = "Nutshell added a blood glucose reading from Tidepool to the Health app."
            }
            DDLogVerbose(msg)
            if itemsDownloaded > 0 {
                // TODO: determine whether local notification feed back is appropriate here!
                let debugMsg = UILocalNotification()
                debugMsg.alertBody = msg
                UIApplication.sharedApplication().presentLocalNotificationNow(debugMsg)
            }
            completion(itemsDownloaded == 0 ? .NoData : .NewData)
        }
    }

    /// Enable/disable push process; can be called multiple times. 
    ///
    /// On enable, process will proceed immediately if this is the first enable, otherwise only if kMinTimeIntervalBetweenSyncs has passed since the last sync.
    ///
    /// On disable, the last time variable will be cleared, so disable followed by enable will kick off a new sync.
    ///
    /// TODO: this will not disable a push in progress.
    func enablePushToHealthKit(enable: Bool) {
        DDLogVerbose("")
        if enable {
            UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(
                kTimeIntervalForBackgroundFetch)
            NSLog("Background fetch interval is \(kTimeIntervalForBackgroundFetch)")

            // TODO: register to send local notifications is for debug only!
            let notifySettings = UIUserNotificationSettings(forTypes: .Alert, categories: nil)
            UIApplication.sharedApplication().registerUserNotificationSettings(notifySettings)
            
            // kick off a download now if we are in the foreground...
            let state = UIApplication.sharedApplication().applicationState
            if state != .Background {
                downloadNewItemsForHealthKit() { (itemsDownloaded) -> Void in
                    DDLogVerbose("Non-background fetch push completed with itemcount = \(itemsDownloaded)")
                    return
                }
            } else {
                DDLogVerbose("app in background, download happens later")
            }
        } else {
            UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(
                UIApplicationBackgroundFetchIntervalNever)
            // reset our last push date so that it happens immediately upon reenable
            lastPushToHK = nil
            itemsLastPushedCount = 0
            self.itemsToPush = [HKQuantitySample]()
        }
    }
    
    //
    // Private Vars
    //
    
    // increment each time we turn off the interface in order to kill off async processes
    private var currentSyncGeneration = 0
    // temp cache of items from service (via our Tidepool DB) to push to HK, for the last 7 days
    private var itemsToPush = [HKQuantitySample]()
    // response from HK of items already in HK for the last 7 days, used to prevent push of duplicate items to HK
    private var itemsAlreadyInHK = [HKSample]()
    // set after a push, cleared by background fetch handler
    private var itemsLastPushedCount: Int = 0
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
    private func downloadNewItemsForHealthKit(completion: (Int) -> Void) {
        DDLogVerbose("")
        itemsLastPushedCount = 0
        
        if !appHealthKitConfiguration.healthKitInterfaceEnabledForCurrentUser() {
            completion(0)
            return
        }
        
        if syncInProgress {
            DDLogVerbose("ignoring call, already syncing!")
            completion(0)
            return
        }

        if !APIConnector.connector().serviceAvailable() {
            DDLogVerbose("skipping sync, no service available!")
            completion(-1)
            return
        }

        let currentTime = NSDate()
        if let lastPushToHK = lastPushToHK {
            let timeIntervalSinceLastSync = currentTime.timeIntervalSinceDate(lastPushToHK)
            if timeIntervalSinceLastSync < kMinTimeIntervalBetweenSyncs {
                DDLogVerbose("skipping sync, time interval since last sync is only \(timeIntervalSinceLastSync)")
                completion(0)
                return
            }
        }
        
        // Start sync - from this point forward use finishSync to turn off syncInProgress when finished!
        syncInProgress = true
        let startTime = currentTime.dateByAddingTimeInterval(-kTimeIntervalOfDataToSyncToHK)
        self.itemsToPush = [HKQuantitySample]()
        let generationForThisSync = self.currentSyncGeneration
        
        // first load up data from Tidepool service for this timeframe
        APIConnector.connector().getReadOnlyUserData(startTime, endDate: currentTime, objectTypes: "smbg", completion: { (result) -> (Void) in
                if result.isSuccess {
                    let (adds, deletes) = DatabaseUtils.updateEventsForTimeRange(startTime, endTime: currentTime, objectTypes: ["smbg"], moc: NutDataController.controller().mocForTidepoolEvents()!, eventsJSON: result.value!)
                    DDLogVerbose("Adds: \(adds), deletes: \(deletes) in range \(startTime) to \(currentTime)")
                } else {
                    DDLogVerbose("No events in range \(startTime) to \(currentTime)")
                }
                
                // Note: even if no net new items were loaded, they may have already been in the Tidepool item database, so we still want to do the HealthKit sync...
                if generationForThisSync == self.currentSyncGeneration {
                    self.fetchLatestCachedData(generationForThisSync, fromTime: startTime, thruTime: currentTime, completion: completion)
                } else {
                    DDLogVerbose("assuming current sync was aborted!")
                    self.finishSync(generationForThisSync, itemsSynced: 0, completion: completion)
                }

            })
        // The background fetch continues next, in fetchLatestCachedData
    }

    private func finishSync(syncGen: Int, itemsSynced: Int, completion: (Int) -> Void) {
        if syncGen == currentSyncGeneration {
            syncInProgress = false
        }
        completion(itemsSynced)
    }

    /// Step 2. Fetch the latest blood glucose samples from the local Tidepool item database cache (now that it has been refreshed), and turn them into an array of HKQuantitySample items for HealthKit.
    ///
    /// Kick off an async HealthKit query to get current samples already in HealthKit to compare so we don't push duplicates.
    private func fetchLatestCachedData(syncGen: Int, fromTime: NSDate, thruTime: NSDate, completion: (Int) -> Void) {
        DDLogVerbose("")
        do {
            let events = try DatabaseUtils.getTidepoolEvents(fromTime, thruTime: thruTime, objectTypes: ["smbg"], skipCheckLoad: true)
            for event in events {
                if let event = event as? CommonData {
                    if let _ = event.time {
                        nextItemForHealthKit(event)
                    }
                }
            }
        } catch let error as NSError {
            NSLog("loadItemsForHealthKit error: \(error)")
        }
        
        if !itemsToPush.isEmpty {
            // Before pushing to HK, read what HK already has to avoid pushing duplicates
            itemsAlreadyInHK = [HKSample]()
            readBGSamplesFromHealthKit(fromTime, thruTime: thruTime) { (samples, error) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if syncGen != self.currentSyncGeneration {
                        DDLogVerbose("assuming current sync was aborted!")
                        self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                        return
                    }
                    // Note: bail on errors so we avoid pushing duplicate data to HealthKit!
                    if let error = error {
                        DDLogError("Error reading bg samples from HealthKit Store: \(error.localizedDescription)")
                        self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                        return
                    }
                    if let samples = samples {
                        self.itemsAlreadyInHK = samples
                        DDLogVerbose("successfully read \(self.itemsAlreadyInHK.count) HealthKit items to compare")
                    }
                    self.pushNewItemsToHealthKit(syncGen, processStartTime: thruTime, completion: completion)
                })
            }
        } else {
            // No items found in Tidepool...
            self.finishSync(syncGen, itemsSynced: 0, completion: completion)
        }
        // The saga completes in the next function...
    }
    
    /// Filter out any duplicates in HealthKit, then push any remaining new samples to HealthKit, completing the process with a call to the original completion routine that kicked it off.
    private func pushNewItemsToHealthKit(syncGen: Int, processStartTime: NSDate, completion: (Int) -> Void) {
        // Remove samples in itemsToPush that match items in itemsAlreadyInHK
        DDLogVerbose("check existing healthkit items for matches...")
        var tidepoolItemsInHKCount = 0
        // set of Tidepool id's successfully pushed
        var tidepoolIdsPushedToHealthKit = Set<String>()
        if !itemsAlreadyInHK.isEmpty {
            // first add id's of these HealthKit items to our exclusion list
            for item in itemsAlreadyInHK {
                var value: Double = -1
                if let item = item as? HKQuantitySample {
                    let unit = HKUnit(fromString: "mg/dL")
                    value = item.quantity.doubleValueForUnit(unit)
                }
                if let metaDataDict = item.metadata {
                    if let tidepoolId = metaDataDict["tidepoolId"] {
                        tidepoolIdsPushedToHealthKit.insert(tidepoolId as! String)
                        tidepoolItemsInHKCount += 1
                        DDLogVerbose("existing HK item at time \(item.startDate), value: \(value)")
                    } else {
                        DDLogVerbose("ignoring HK item with no tidepoolId metadata: time \(item.startDate) and value: \(value)")
                    }
                } else {
                    DDLogVerbose("ignoring HK item with no metaDataDict: time \(item.startDate) and value: \(value)")
                }
            }
            // next filter out any items in our push array that match items in the exclusion list
            if tidepoolItemsInHKCount > 0 {
                self.itemsToPush = self.itemsToPush.filter() {item in
                    if let metaDataDict = item.metadata {
                        if let tidepoolId = metaDataDict["tidepoolId"] {
                            if tidepoolIdsPushedToHealthKit.contains(tidepoolId as! String) {
                                DDLogVerbose("filtered out item with tidepool id: \(tidepoolId)")
                                return false
                            }
                        }
                    }
                    return true
                }
            }
        }
        
        // Finally, if there are any new items, push them to HealthKit now...
        if !itemsToPush.isEmpty {
            HealthKitManager.sharedInstance.healthStore!.saveObjects(itemsToPush) { (success, error) -> Void in
                if syncGen != self.currentSyncGeneration {
                    DDLogVerbose("assuming current sync was aborted!")
                    self.finishSync(syncGen, itemsSynced: 0, completion: completion)
                    return
                }
                if( error != nil ) {
                    DDLogError("Error pushing \(self.itemsToPush.count) glucose samples to HealthKit: \(error!.localizedDescription)")
                    self.finishSync(syncGen, itemsSynced: -1, completion: completion)
                } else {
                    DDLogVerbose("\(self.itemsToPush.count) Blood glucose samples pushed to HealthKit successfully!")
                    self.lastPushToHK = processStartTime
                    self.itemsLastPushedCount = self.itemsToPush.count
                    self.finishSync(syncGen, itemsSynced: self.itemsLastPushedCount, completion: completion)
                }
            }
        } else {
            DDLogVerbose("no new items to push to HealthKit!")
            self.finishSync(syncGen, itemsSynced: 0, completion: completion)
        }
    }
    
    /// Do an async read of current blood glucose samples from HealthKit for a date range, passing along results to the completion method.
    private func readBGSamplesFromHealthKit(fromTime: NSDate, thruTime: NSDate, completion: ([HKSample]?, NSError?) -> Void)
    {
        DDLogVerbose("")
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let timeRangePredicate = HKQuery.predicateForSamplesWithStartDate(fromTime, endDate: thruTime, options: .None)
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: true)
        let limit = Int(HKObjectQueryNoLimit)
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: timeRangePredicate, limit: limit, sortDescriptors: [sortDescriptor])
            { (sampleQuery, results, error ) -> Void in
                completion(results, error)
        }
        HealthKitManager.sharedInstance.healthStore!.executeQuery(sampleQuery)
    }
    
    /// Turns a Tidepool event into an HKQuantitySample event for HealthKit, adding it to the itemsToPush array.
    private func nextItemForHealthKit(event: CommonData) {
        let kGlucoseConversionToMgDl: Double = 18.0
        var bgValue: Double?
        var userEntered: NSNumber?
        
        if let cbgEvent = event as? ContinuousGlucose {
            if let cbgValue = cbgEvent.value {
                bgValue = round(Double(cbgValue.floatValue) * kGlucoseConversionToMgDl)
            }
        } else if let smbgEvent = event as? SelfMonitoringGlucose {
            if let smbgValue = smbgEvent.value {
                bgValue = round(Double(smbgValue.floatValue) * kGlucoseConversionToMgDl)
            }
            if let subType = smbgEvent.subType {
                if subType == "manual" {
                    userEntered = 1
                }
            }
        }
        
        if bgValue == nil {
            DDLogError("item not a valid blood glucose event!")
            return
        }
        
        if let itemId = event.id as? String, let time = event.time, let type = event.type as? String {
            let bgType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)
            let bgQuantity = HKQuantity(unit: HKUnit(fromString: "mg/dL"), doubleValue: bgValue!)
            let deviceId = event.deviceId ?? ""
            // TODO: add guid to metadata as well, need to rev data model to add this...
            var metadata: [String: AnyObject] = ["tidepoolId": itemId, "deviceId": deviceId, "type": type]
            if let userEntered = userEntered {
                metadata[HKMetadataKeyWasUserEntered] = userEntered
            }
            let bgSample = HKQuantitySample(type: bgType!, quantity: bgQuantity, startDate: time, endDate: time, metadata: metadata)
            DDLogVerbose("candidate Tidepool item at time: \(time), value: \(bgQuantity)")
            itemsToPush.append(bgSample)
        } else {
            DDLogError("item missing id, type, or time!")
        }
    }

}