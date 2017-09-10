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
class HealthKitBloodGlucosePusher: NSObject {

    static let sharedInstance = HealthKitBloodGlucosePusher()

    fileprivate override init() {
        DDLogVerbose("")
    }

    // MARK: - Config

    /// Sync last 10 days of data
    let kTimeIntervalOfDataToSyncToHK: TimeInterval = 60*60*24*10
    /// Check at most every 4 hours...
    let kMinTimeIntervalBetweenSyncs: TimeInterval = 60*60*4
    /// But ask for background time every 6 hours...
    let kTimeIntervalForBackgroundFetch: TimeInterval = 60*60*4
    
    /// Last time we checked for and pushed data to HealthKit or nil if never pushed
    var lastPushToHK: Date? {
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: kLastPushOfDataToHKKey)
            UserDefaults.standard.synchronize()
            _lastPushToHK = nil
        }
        get {
            if _lastPushToHK == nil {
                let curValue = UserDefaults.standard.object(forKey: kLastPushOfDataToHKKey)
                if let date = curValue as? Date {
                    _lastPushToHK = date
                }
            }
            return _lastPushToHK
        }
    }
    
    fileprivate(set) var enabled = false

    fileprivate var _lastPushToHK: Date?
    fileprivate let kLastPushOfDataToHKKey = "kLastPushOfDataToHKKey"
   
    /// Called by background fetch code in app delegate, and will kick off a sync if enough time has elapsed and currently HealthKit user is logged in.
    func backgroundFetch(_ completion: @escaping (UIBackgroundFetchResult) -> Void) {
        if self.enabled {
            downloadNewItemsForHealthKit() { (itemsDownloaded) -> Void in
                var msg = "TidepoolMobile added \(itemsDownloaded) blood glucose readings from Tidepool to the Health app."
                if itemsDownloaded == 1 {
                    msg = "TidepoolMobile added a blood glucose reading from Tidepool to the Health app."
                }
                DDLogVerbose(msg)
                if AppDelegate.testMode {
                    let debugMsg = UILocalNotification()
                    debugMsg.alertBody = msg
                    UIApplication.shared.presentLocalNotificationNow(debugMsg)
                }
                completion(itemsDownloaded == 0 ? .noData : .newData)
            }
        } else{
            completion(.noData)
        }
    }

    /// Enable/disable push process; can be called multiple times. 
    ///
    /// On enable, process will proceed immediately if this is the first enable, otherwise only if kMinTimeIntervalBetweenSyncs has passed since the last sync.
    ///
    /// On disable, the last time variable will be cleared, so disable followed by enable will kick off a new sync.
    ///
    /// TODO: this will not disable a push in progress.
    func enablePushToHealthKit(_ enable: Bool) {
        DDLogVerbose("")
        if enable {
            UIApplication.shared.setMinimumBackgroundFetchInterval(
                kTimeIntervalForBackgroundFetch)
            NSLog("Background fetch interval is \(kTimeIntervalForBackgroundFetch)")

            // Use local notifications to test background activity...
            if AppDelegate.testMode {
                let notifySettings = UIUserNotificationSettings(types: .alert, categories: nil)
                UIApplication.shared.registerUserNotificationSettings(notifySettings)
            }
            
            // kick off a download now if we are in the foreground...
            let state = UIApplication.shared.applicationState
            if state != .background {
                downloadNewItemsForHealthKit() { (itemsDownloaded) -> Void in
                    DDLogVerbose("Non-background fetch push completed with itemcount = \(itemsDownloaded)")
                    return
                }
            } else {
                DDLogVerbose("app in background, download happens later")
            }
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(
                UIApplicationBackgroundFetchIntervalNever)
            // reset our last push date so that it happens immediately upon reenable
            lastPushToHK = nil
            itemsLastPushedCount = 0
            self.itemsToPush = [HKQuantitySample]()
        }
        
        self.enabled = enable
    }
    
    //
    // Private Vars
    //
    
    // increment each time we turn off the interface in order to kill off async processes
    fileprivate var currentSyncGeneration = 0
    // temp cache of items from service (via our Tidepool DB) to push to HK, for the last 7 days
    fileprivate var itemsToPush = [HKQuantitySample]()
    // response from HK of items already in HK for the last 7 days, used to prevent push of duplicate items to HK
    fileprivate var itemsAlreadyInHK = [HKSample]()
    // set after a push, cleared by background fetch handler
    fileprivate var itemsLastPushedCount: Int = 0
    // set during a sync to prevent another sync being kicked off...
    fileprivate var syncInProgress = false
    
    //
    // Private Methods
    //

    /// Step 1. Kick off a sync if current HealthKit user is logged in, a sync process is not already running, and enough time has elapsed since the last sync.
    ///
    /// Starts an async load of data from the Tidepool service, and on completion continues the sync process by calling fetchLatestCachedData. Note that all Tidepool data is downloaded, not just the blood glucose samples, so this also serves to refresh the local database cache of Tidepool items for the application.
    ///
    /// Completion is called with: -1 on errors, 0 if no data was pushed, or positive count of new items sent to HealthKit.
    fileprivate func downloadNewItemsForHealthKit(_ completion: @escaping (Int) -> Void) {
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

        let currentTime = Date()
        var minTimeIntervalBetweenSyncs = kMinTimeIntervalBetweenSyncs
        if AppDelegate.testMode {
            // for testing, knock this down to every minute!
            minTimeIntervalBetweenSyncs = 60
        }
        if let lastPushToHK = lastPushToHK {
            let timeIntervalSinceLastSync = currentTime.timeIntervalSince(lastPushToHK)
            if timeIntervalSinceLastSync < minTimeIntervalBetweenSyncs {
                DDLogVerbose("skipping sync, time interval since last sync is only \(timeIntervalSinceLastSync)")
                completion(0)
                return
            }
        }
        
        // Start sync - from this point forward use finishSync to turn off syncInProgress when finished!
        syncInProgress = true
        let startTime = currentTime.addingTimeInterval(-kTimeIntervalOfDataToSyncToHK)
        self.itemsToPush = [HKQuantitySample]()
        let generationForThisSync = self.currentSyncGeneration
        
        // first load up data from Tidepool service for this timeframe
        APIConnector.connector().getReadOnlyUserData(startTime, endDate: currentTime, objectTypes: "smbg", completion: { (result) -> (Void) in
                if result.isSuccess {
                    DatabaseUtils.sharedInstance.updateEventsForTimeRange(startTime, endTime: currentTime, objectTypes: ["smbg"], moc: TidepoolMobileDataController.sharedInstance.mocForTidepoolEvents()!, eventsJSON: result.value!) { (success) -> (Void) in
                        
                        DDLogVerbose("Completed updateEventsForTimeRange, success = \(success) for \(startTime) to \(currentTime)")
                        
                        // Note: even if no net new items were loaded, they may have already been in the Tidepool item database, so we still want to do the HealthKit sync...
                        if generationForThisSync == self.currentSyncGeneration {
                            self.fetchLatestCachedData(generationForThisSync, fromTime: startTime, thruTime: currentTime, completion: completion)
                        } else {
                            DDLogVerbose("assuming current sync was aborted!")
                            self.finishSync(generationForThisSync, itemsSynced: 0, completion: completion)
                        }
                    }
                }
            })
        // The background fetch continues next, in fetchLatestCachedData
    }

    fileprivate func finishSync(_ syncGen: Int, itemsSynced: Int, completion: (Int) -> Void) {
        if syncGen == currentSyncGeneration {
            syncInProgress = false
        }
        completion(itemsSynced)
    }

    /// Step 2. Fetch the latest blood glucose samples from the local Tidepool item database cache (now that it has been refreshed), and turn them into an array of HKQuantitySample items for HealthKit.
    ///
    /// Kick off an async HealthKit query to get current samples already in HealthKit to compare so we don't push duplicates.
    fileprivate func fetchLatestCachedData(_ syncGen: Int, fromTime: Date, thruTime: Date, completion: @escaping (Int) -> Void) {
        DDLogVerbose("")
        do {
            let events = try DatabaseUtils.sharedInstance.getTidepoolEvents(fromTime, thruTime: thruTime, objectTypes: ["smbg"], skipCheckLoad: true)
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
                DispatchQueue.main.async(execute: { () -> Void in
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
    fileprivate func pushNewItemsToHealthKit(_ syncGen: Int, processStartTime: Date, completion: @escaping (Int) -> Void) {
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
                    let unit = HKUnit(from: "mg/dL")
                    value = item.quantity.doubleValue(for: unit)
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
            HealthKitManager.sharedInstance.healthStore!.save(itemsToPush, withCompletion: { (success, error) -> Void in
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
            }) 
        } else {
            DDLogVerbose("no new items to push to HealthKit!")
            self.finishSync(syncGen, itemsSynced: 0, completion: completion)
        }
    }
    
    /// Do an async read of current blood glucose samples from HealthKit for a date range, passing along results to the completion method.
    fileprivate func readBGSamplesFromHealthKit(_ fromTime: Date, thruTime: Date, completion: @escaping ([HKSample]?, NSError?) -> Void)
    {
        DDLogVerbose("")
        
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
    
    /// Turns a Tidepool event into an HKQuantitySample event for HealthKit, adding it to the itemsToPush array.
    fileprivate func nextItemForHealthKit(_ event: CommonData) {
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
        
        if let itemId = event.id, let time = event.time, let type = event.type {
            let bgType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
            let bgQuantity = HKQuantity(unit: HKUnit(from: "mg/dL"), doubleValue: bgValue!)
            let deviceId = event.deviceId ?? ""
            // TODO: add guid to metadata as well, need to rev data model to add this...
            var metadata: [String: AnyObject] = ["tidepoolId": itemId as AnyObject, "deviceId": deviceId as AnyObject, "type": type as AnyObject]
            if let userEntered = userEntered {
                metadata[HKMetadataKeyWasUserEntered] = userEntered
            }
            let bgSample = HKQuantitySample(type: bgType!, quantity: bgQuantity, start: time as Date, end: time as Date, metadata: metadata)
            DDLogVerbose("candidate Tidepool item at time: \(time), value: \(bgQuantity)")
            itemsToPush.append(bgSample)
        } else {
            DDLogError("item missing id, type, or time!")
        }
    }

}
