//
//  DatabaseUtils.swift
//  Nutshell
//
//  Created by Brian King on 9/16/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

public let NewBlockRangeLoadedNotification = "NewBlockRangeLoadedNotification"

class DatabaseUtils {
    
    class func databaseSave(moc: NSManagedObjectContext) -> Bool {
        // Save the database
        do {
            try moc.save()
            NSLog("DatabaseUtils: Database saved!")
            return true
        } catch let error as NSError {
            // TO DO: error message!
            NSLog("Failed to save MOC: \(error)")
            return false
        }
    }

    // MARK: - Methods to cache read-only data from service

    // A sorted cache of server blocks we have fetched during the current application lifetime, along with the date of fetch...
    static var serverBlocks = [Int : NSDate]()
    // TODO: look at moving this to NutshellDataController...
    class func resetTidepoolEventLoader() {
        DatabaseUtils.serverBlocks = [Int : NSDate]()
    }
 
    class func dateToBucketNumber(date: NSDate) -> Int {
        let refSeconds = Int(date.timeIntervalSinceReferenceDate)
        let kBucketSeconds = 60*60*20 // 20 hour chunks
        let result = refSeconds/kBucketSeconds
        //NSLog("Date: \(date), bucket number: \(result)")
        return result
    }

    class func bucketNumberToDate(bucket: Int) -> NSDate {
        let date = NSDate(timeIntervalSinceReferenceDate: NSTimeInterval(bucket*60*60*20))
        //NSLog("Bucket number: \(bucket), date: \(date)")
        return date
    }

    class func checkLoadDataForDateRange(startDate: NSDate, endDate: NSDate, completion: ((Int) -> Void)?) {
        let now = NSDate()
        let startBucket = DatabaseUtils.dateToBucketNumber(startDate)
        let endBucket = DatabaseUtils.dateToBucketNumber(endDate)
        var itemsAdded = 0
        var itemsDeleted = 0
        for bucket in startBucket...endBucket {
            
            if let lastFetchDate = serverBlocks[bucket] {
                if now.timeIntervalSinceDate(lastFetchDate) < 60 {
                    // don't check more often than every minute...
                    NSLog("checkLoadDataForDateRange: skip load of bucket \(bucket)")
                    continue
                }
            }
            NSLog("checkLoadDataForDateRange: fetch server data for bucket \(bucket)")
            // kick off a fetch if we are online...
            if APIConnector.connector().serviceAvailable() {
                // TODO: if fetch fails, should we wait less time before retrying? 
                serverBlocks[bucket] = now
                let startTime = DatabaseUtils.bucketNumberToDate(bucket)
                let endTime = DatabaseUtils.bucketNumberToDate(bucket+1)
                APIConnector.connector().getReadOnlyUserData(startTime, endDate:endTime, completion: { (result) -> (Void) in
                    if result.isSuccess {
                        let (adds, deletes) = DatabaseUtils.updateEventsForTimeRange(startTime, endTime: endTime, moc: NutDataController.controller().mocForTidepoolEvents()!, eventsJSON: result.value!)
                        itemsAdded += adds
                        itemsDeleted += deletes
                    } else {
                        NSLog("Failed to fetch events in range \(startTime) to \(endTime)")
                    }
                })
            } else {
                NSLog("skipping: serviceAvailable is false")
            }
            
        }
        // Call optional completion routine with estimate of items added (net of adds less deletes)
        NSLog("items added: \(itemsAdded), deleted: \(itemsDeleted), net: \(itemsAdded-itemsDeleted)")
        if let completion = completion {
            completion(itemsAdded-itemsDeleted)
        }
    }
    
    class func updateEventsForTimeRange(startTime: NSDate, endTime: NSDate, objectTypes: [String] = ["smbg","bolus","cbg","wizard","basal"], moc: NSManagedObjectContext, eventsJSON: JSON) -> (Int, Int) {
        NSLog("updateEventsForTimeRange from \(startTime) to \(endTime) for types \(objectTypes)")
        // NSLog("Events from \(startTime) to \(endTime): \(eventsJSON)")
        var deleteEventCounter = 0
        // Delete all tidepool items in range before adding the new ones...
        do {
            let request = NSFetchRequest(entityName: "CommonData")
            // Return all objects in the requested range, exclusive of start time and inclusive of end time, to match server fetch
            // NOTE: This would include Meal and Workout items if they were part of this database!
            request.predicate = NSPredicate(format: "(type IN %@) AND (time > %@) AND (time <= %@)", objectTypes, startTime, endTime)
            request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            let events = try moc.executeFetchRequest(request) as! [NSManagedObject]
            for obj: NSManagedObject in events {
//                if let tObj = obj as? CommonData {
//                    NSLog("deleting event id: \(tObj.id) with time: \(tObj.time)")
//                }
                moc.deleteObject(obj)
                deleteEventCounter += 1
            }
        } catch let error as NSError {
            NSLog("Error in updateEventsForTimeRange deleting objects: \(error)")
        }
        //NSLog("updateEventsForTimeRange deleted \(deleteEventCounter) items")

        var insertEventCounter = 0
        for (_, subJson) in eventsJSON {
            //NSLog("updateEvents next subJson: \(subJson)")
            if let obj = CommonData.fromJSON(subJson, moc: moc) {
                // add objects
                if let _=obj.id {
                    insertEventCounter += 1
                    moc.insertObject(obj)
                    //NSLog("inserting event id: \(obj.id) with time: \(obj.time)")
                } else {
                    NSLog("updateEvents: no ID found for object: \(obj), not inserting!")
                }
            }
        }
        //NSLog("updateEventsForTimeRange updated \(insertEventCounter) items")
        if deleteEventCounter != 0 && insertEventCounter != deleteEventCounter {
            NSLog("NOTE: deletes were non-zero and did not match inserts!!!")
        }
        // Save the database
        do {
            try moc.save()
            //NSLog("updateEventsForTimeRange \(startTime) to \(endTime): Database saved!")
            notifyOnDataLoad()
        } catch let error as NSError {
            NSLog("Failed to save MOC: \(error)")
        }
        
        // return net events added...
        return (insertEventCounter, deleteEventCounter)
    }
    
    class func updateEvents(moc: NSManagedObjectContext, eventsJSON: JSON) {
        // We get back an array of JSON objects. Iterate through the array and insert the objects into the database, removing any existing objects we may have.
        
        let request = NSFetchRequest(entityName: "CommonData")
        var eventCounter = 0
        for (_, subJson) in eventsJSON {
            //NSLog("updateEvents next subJson: \(subJson)")
            if let obj = CommonData.fromJSON(subJson, moc: moc) {
                // Remove existing object with the same ID
                if let id=obj.id {
                    eventCounter += 1
                    request.predicate = NSPredicate(format: "id = %@", id)
                    
                    do {
                        let foundObjects = try moc.executeFetchRequest(request) as! [NSManagedObject]
                        for foundObject in foundObjects {
                            moc.deleteObject(foundObject)
                        }
                        moc.insertObject(obj)
                    } catch let error as NSError {
                        NSLog("updateEvents: Failed to replace existing event with ID \(id) error: \(error)")
                    }
                } else {
                    NSLog("updateEvents: no ID found for object: \(obj), not inserting!")
                }
            }
        }
        NSLog("updateEvents updated \(eventCounter) items")
        // Save the database
        do {
            try moc.save()
            NSLog("updateEvents: Database saved!")
            //dispatch_async(dispatch_get_main_queue()) {
            notifyOnDataLoad()
            //}
        } catch let error as NSError {
            NSLog("Failed to save MOC: \(error)")
        }
    }
    
    class func notifyOnDataLoad() {
        // This will come in on the main thread, unlike the NSManagedObjectContextDidSaveNotification
        NSNotificationCenter.defaultCenter().postNotificationName(NewBlockRangeLoadedNotification, object:nil)
    }
    
    // Note: This call has the side effect of fetching data from the service which may result in a future notification of database changes.
    class func getTidepoolEvents(afterTime: NSDate, thruTime: NSDate, objectTypes: [String]? = nil, skipCheckLoad: Bool = false) throws -> [NSManagedObject] {
        let moc = NutDataController.controller().mocForTidepoolEvents()!

        // load on-demand: if data has not been loaded, a notification will come later!
        if !skipCheckLoad {
            DatabaseUtils.checkLoadDataForDateRange(afterTime, endDate: thruTime, completion: nil)
        }

        let request = NSFetchRequest(entityName: "CommonData")
        
        if let types = objectTypes {
            // Return only objects of the requested types in the requested range
            request.predicate = NSPredicate(format: "(type IN %@) AND (time > %@) AND (time <= %@)", types, afterTime, thruTime)
        } else {
            // Return all objects in the requested range
            request.predicate = NSPredicate(format: "(time > %@) AND (time <= %@)", afterTime, thruTime)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        let events = try moc.executeFetchRequest(request) as! [NSManagedObject]
        return events
    }

    class func getNutEvent(id: String) throws -> [EventItem] {
        let moc = NutDataController.controller().mocForNutEvents()!
        let request = NSFetchRequest(entityName: "EventItem")
        request.predicate = NSPredicate(format: "id == %@", id)
        return try moc.executeFetchRequest(request) as! [EventItem]
    }
    
    class func getNutEventItemWithId(id: String) -> EventItem? {
        do {
            let nutEventArray = try DatabaseUtils.getNutEvent(id)
            if nutEventArray.count == 1 {
                return nutEventArray[0]
            } else {
                NSLog("getNutEventItemWithId returns nil")
                return nil
            }
        } catch let error as NSError {
            NSLog("getNutEventItemWithId error: \(error)")
            return nil
        }
    }

    // Note: This call has the side effect of fetching data from the service which may result in a future notification of database changes.
    // TODO: This will need to be reworked to sync data from the service when the service supports meal and workout events.
    class func getAllNutEvents() throws -> [EventItem] {
        
        let moc = NutDataController.controller().mocForNutEvents()!
        let userId = NutDataController.controller().currentUserId!
        let request = NSFetchRequest(entityName: "EventItem")
        // Return all nut events in the requested range for the current user!
        // TODO: remove nil option before shipping!
        request.predicate = NSPredicate(format: "(userid == %@) OR (userid = nil)", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        return try moc.executeFetchRequest(request) as! [EventItem]
    }

    class func nutEventRequest(nutType: String, fromTime: NSDate, toTime: NSDate) -> (request: NSFetchRequest, moc: NSManagedObjectContext) {
        let moc = NutDataController.controller().mocForNutEvents()!
        let userId = NutDataController.controller().currentUserId!
        let request = NSFetchRequest(entityName: nutType)
        // Return only objects in the requested range for the current user!
        // TODO: remove nil option before shipping!
        request.predicate = NSPredicate(format: "((userid == %@) OR (userid = nil)) AND (time >= %@) AND (time <= %@)", userId, fromTime, toTime)
        
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        return (request, moc)
    }
 
    class func getWorkoutEvents(fromTime: NSDate, toTime: NSDate) throws -> [Workout] {
        let (request, moc) = nutEventRequest("Workout", fromTime: fromTime, toTime: toTime)
        return try moc.executeFetchRequest(request) as! [Workout]
    }
    

    class func getMealEvents(fromTime: NSDate, toTime: NSDate) throws -> [Meal] {
        let (request, moc) = nutEventRequest("Meal", fromTime: fromTime, toTime: toTime)
        return try moc.executeFetchRequest(request) as! [Meal]
    }

    // TEST ONLY!
    // TODO: Move to NutshellTests!
    class func deleteAllNutEvents() {
        // TODO: Note this is currently only used for testing!
        let moc = NutDataController.controller().mocForNutEvents()!
        do {
            let request = NSFetchRequest(entityName: "EventItem")
            let userId = NutDataController.controller().currentUserId!
            request.predicate = NSPredicate(format: "(userid == %@) OR (userid = nil)", userId)
            let myList = try moc.executeFetchRequest(request)
            for obj: AnyObject in myList {
                if let objId = obj.id as? String {
                    if objId.hasPrefix("demo")  {
                        moc.deleteObject(obj as! NSManagedObject)
                    }
                }
            }
        } catch let error as NSError {
            NSLog("Failed to delete nut event items: \(error)")
        }
        
        do {
            try moc.save()
        } catch let error as NSError {
            NSLog("deleteAllNutEvents: Failed to save MOC: \(error)")
        }
    }
}