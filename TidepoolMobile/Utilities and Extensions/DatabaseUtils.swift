//
//  DatabaseUtils.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/16/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON
import CocoaLumberjack

public let NewBlockRangeLoadedNotification = "NewBlockRangeLoadedNotification"

class DatabaseUtils {

    /// Supports a singleton controller for the application.
    static let sharedInstance = DatabaseUtils()

    class func databaseSave(_ moc: NSManagedObjectContext) -> Bool {
        // Save the database
        do {
            try moc.save()
            DDLogInfo("DatabaseUtils: Database saved!")
            return true
        } catch let error as NSError {
            // TO DO: error message!
            DDLogInfo("Failed to save MOC: \(error)")
            return false
        }
    }

    // MARK: - Methods to cache read-only data from service

    // A sorted cache of server blocks we have fetched during the current application lifetime, along with the date of fetch...
    private var serverBlocks = [Int : Date]()

    // TODO: look at moving this to TidepoolMobileDataController...
    func resetTidepoolEventLoader() {
        serverBlocks = [Int : Date]()
    }
    
    private func dateToBucketNumber(_ date: Date) -> Int {
        let refSeconds = Int(date.timeIntervalSinceReferenceDate)
        let kBucketSeconds = 60*60*20 // 20 hour chunks
        let result = refSeconds/kBucketSeconds
        //DDLogInfo("Date: \(date), bucket number: \(result)")
        return result
    }

    private func bucketNumberToDate(_ bucket: Int) -> Date {
        let date = Date(timeIntervalSinceReferenceDate: TimeInterval(bucket*60*60*20))
        //DDLogInfo("Bucket number: \(bucket), date: \(date)")
        return date
    }

    private func checkLoadDataForDateRange(_ startDate: Date, endDate: Date) {
        let now = Date()
        let startBucket = dateToBucketNumber(startDate)
        let endBucket = dateToBucketNumber(endDate)
        for bucket in startBucket...endBucket {
            
            if let lastFetchDate = serverBlocks[bucket] {
                if now.timeIntervalSince(lastFetchDate) < 60 {
                    // don't check more often than every minute...
                    DDLogInfo("\(#function): skip load of bucket \(bucket)")
                    continue
                }
            }
            DDLogInfo("\(#function): fetch server data for bucket \(bucket)")
            // kick off a fetch if we are online...
            if APIConnector.connector().serviceAvailable() {
                // TODO: if fetch fails, should we wait less time before retrying? 
                serverBlocks[bucket] = now
                let startTime = bucketNumberToDate(bucket)
                let endTime = bucketNumberToDate(bucket+1)
                startTidepoolLoad()
                APIConnector.connector().getReadOnlyUserData(startTime, endDate:endTime, completion: { (result) -> (Void) in
                    if result.isSuccess {
                        if let moc = TidepoolMobileDataController.sharedInstance.mocForTidepoolEvents() {
                            self.updateEventsForTimeRange(startTime, endTime: endTime, moc: moc, eventsJSON: result.value!) {
                                success -> Void in
                                self.endTidepoolLoad()
                            }
                        } else {
                            DDLogInfo("checkLoadDataForDateRange bailing due to nil MOC")
                            self.endTidepoolLoad()
                        }
                    } else {
                        DDLogInfo("Failed to fetch events in range \(startTime) to \(endTime)")
                        self.endTidepoolLoad()
                    }
                })
            } else {
                DDLogInfo("skipping: serviceAvailable is false")
            }
        }
    }
    
    func updateEventsForTimeRange(_ startTime: Date, endTime: Date, objectTypes: [String] = ["smbg","bolus","cbg","wizard","basal"], moc: NSManagedObjectContext, eventsJSON: JSON, completion: @escaping ((Bool) -> Void)) {
        DDLogInfo("\(#function) from \(startTime) to \(endTime) for types \(objectTypes)")
        //DDLogInfo("Events from \(startTime) to \(endTime): \(eventsJSON)")
        DispatchQueue.global(qos: .background).async {
    
            var deleteEventCounter = 0
            let bgMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            bgMOC.persistentStoreCoordinator = moc.persistentStoreCoordinator
            
            // Delete all tidepool items in range before adding the new ones...
            do {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonData")
                // Return all objects in the requested range, exclusive of start time and inclusive of end time, to match server fetch
                // NOTE: This would include Meal and Workout items if they were part of this database!
                request.predicate = NSPredicate(format: "(type IN %@) AND (time > %@) AND (time <= %@)", objectTypes, startTime as CVarArg, endTime as CVarArg)
                request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                let events = try bgMOC.fetch(request) as! [NSManagedObject]
                for obj: NSManagedObject in events {
                    //                if let tObj = obj as? CommonData {
                    //                    DDLogInfo("deleting event id: \(tObj.id) with time: \(tObj.time)")
                    //                }
                    bgMOC.delete(obj)
                    deleteEventCounter += 1
                }
            } catch let error as NSError {
                DDLogError("Error in \(#function) deleting objects: \(error)")
            }
            //DDLogInfo("\(#function) deleted \(deleteEventCounter) items")
            
            var insertEventCounter = 0
            for (_, subJson) in eventsJSON {
                //DDLogInfo("updateEvents next subJson: \(subJson)")
                if let obj = CommonData.fromJSON(subJson, moc: bgMOC) {
                    // add objects
                    if let _=obj.id {
                        insertEventCounter += 1
                        bgMOC.insert(obj)
                        //DDLogInfo("inserting event id: \(obj.id) with time: \(obj.time)")
                    } else {
                        DDLogInfo("updateEvents: no ID found for object: \(obj), not inserting!")
                    }
                }
            }
            //DDLogInfo("\(#function) updated \(insertEventCounter) items")
            if deleteEventCounter != 0 && insertEventCounter != deleteEventCounter {
                DDLogInfo("NOTE: deletes were non-zero and did not match inserts!!!")
            }
            
            // Save the database
            do {
                try bgMOC.save()
                //DDLogInfo("\(#function) \(startTime) to \(endTime): Database saved!")
                DispatchQueue.main.async {
                    // NOTE: completion will decrement the loading count (in non-test case), then notification will be sent. Client will get the notification, and check whether loading is still in progess or not... 
                    completion(true)
                    self.notifyOnDataLoad()
                }
            } catch let error as NSError {
                DDLogError("Failed to save MOC: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
            
            if insertEventCounter != 0 || deleteEventCounter != 0 {
                DDLogInfo("final items added: \(insertEventCounter), deleted: \(deleteEventCounter), net: \(insertEventCounter-deleteEventCounter)")
            }
        }
    }
    
    // Note: currently only called by test software
    func updateEvents(_ moc: NSManagedObjectContext, eventsJSON: JSON) {
        // We get back an array of JSON objects. Iterate through the array and insert the objects into the database, removing any existing objects we may have.
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonData")
        var eventCounter = 0
        for (_, subJson) in eventsJSON {
            //DDLogInfo("updateEvents next subJson: \(subJson)")
            if let obj = CommonData.fromJSON(subJson, moc: moc) {
                // Remove existing object with the same ID
                if let id=obj.id {
                    eventCounter += 1
                    request.predicate = NSPredicate(format: "id = %@", id)
                    
                    do {
                        let foundObjects = try moc.fetch(request) as! [NSManagedObject]
                        for foundObject in foundObjects {
                            moc.delete(foundObject)
                        }
                        moc.insert(obj)
                    } catch let error as NSError {
                        DDLogError("updateEvents: Failed to replace existing event with ID \(id) error: \(error)")
                    }
                } else {
                    DDLogInfo("updateEvents: no ID found for object: \(obj), not inserting!")
                }
            }
        }
        DDLogInfo("updateEvents updated \(eventCounter) items")
        // Save the database
        do {
            try moc.save()
            DDLogInfo("updateEvents: Database saved!")
            notifyOnDataLoad()
        } catch let error as NSError {
            DDLogError("Failed to save MOC: \(error)")
        }
    }
    
    private func notifyOnDataLoad() {
        // This will come in on the main thread, unlike the NSManagedObjectContextDidSaveNotification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: NewBlockRangeLoadedNotification), object:nil)
        }
    }
    
    private var loadingCount: Int = 0
    
    private func startTidepoolLoad() {
        if loadingCount == 0 {
            DDLogInfo("loading Tidepool Events started")
        }
        loadingCount += 1
    }
    
    private func endTidepoolLoad() {
        loadingCount -= 1
        if loadingCount <= 0 {
            if loadingCount < 0 {
                loadingCount = 0
                DDLogInfo("ERROR: loading count negative!")
            }
            DDLogInfo("loading Tidepool Events complete")
        }
    }
    
    func isLoadingTidepoolEvents() -> Bool {
        return loadingCount > 0
    }
    
    // Note: This call has the side effect of fetching data from the service which may result in a future notification of database changes; if this class is in the process of fetching tidepool events, isLoadingTidepoolEvents will be true.
    func getTidepoolEvents(_ afterTime: Date, thruTime: Date, objectTypes: [String]? = nil, skipCheckLoad: Bool = false) throws -> [NSManagedObject] {
        let moc = TidepoolMobileDataController.sharedInstance.mocForTidepoolEvents()!

        // load on-demand: if data has not been loaded, a notification will come later!
        if !skipCheckLoad {
            checkLoadDataForDateRange(afterTime, endDate: thruTime)
        }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonData")
        
        if let types = objectTypes {
            // Return only objects of the requested types in the requested range
            request.predicate = NSPredicate(format: "(type IN %@) AND (time > %@) AND (time <= %@)", types, afterTime as CVarArg, thruTime as CVarArg)
        } else {
            // Return all objects in the requested range
            request.predicate = NSPredicate(format: "(time > %@) AND (time <= %@)", afterTime as CVarArg, thruTime as CVarArg)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        let events = try moc.fetch(request) as! [NSManagedObject]
        return events
    }

}
