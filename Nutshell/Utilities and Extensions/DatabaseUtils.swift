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

    private class var isoDateFormatter : NSDateFormatter {
        struct Static {
            static let instance: NSDateFormatter = {
                let df = NSDateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                return df
            }()
        }
        return Static.instance
    }

    class func bucketNumberToIsoDateString(bucket: Int) -> String {
        let date = NSDate(timeIntervalSinceReferenceDate: NSTimeInterval(bucket*60*60*20))
        let df = DatabaseUtils.isoDateFormatter
        let result = df.stringFromDate(date) + "Z"
        //NSLog("Bucket number: \(bucket), date: \(date), string: \(result)")
        return result
    }

    class func checkLoadDataForDateRange(startDate: NSDate, endDate: NSDate) {
        let now = NSDate()
        let startBucket = DatabaseUtils.dateToBucketNumber(startDate)
        let endBucket = DatabaseUtils.dateToBucketNumber(endDate)
        for bucket in startBucket...endBucket {
            
            if let lastFetchDate = serverBlocks[bucket] {
                if now.timeIntervalSinceDate(lastFetchDate) < 60*10 {
                    // don't check more often than every 10 minutes...
                    //NSLog("checkLoadDataForDateRange: skip load of bucket \(bucket)")
                    continue
                }
            }
            // kick off a fetch if we are online...
            if APIConnector.connector().serviceAvailable() {
                // TODO: if fetch fails, should we wait less time before retrying? 
                serverBlocks[bucket] = now
                let startTimeIsoDateStr = DatabaseUtils.bucketNumberToIsoDateString(bucket)
                let endTimeIsoDateStr = DatabaseUtils.bucketNumberToIsoDateString(bucket+1)
                APIConnector.connector().getReadOnlyUserData(startTimeIsoDateStr, endDate:endTimeIsoDateStr, completion: { (result) -> (Void) in
                    if result.isSuccess {
                        DatabaseUtils.updateEvents(NutDataController.controller().mocForTidepoolEvents()!, eventsJSON: result.value!)
                    } else {
                        NSLog("No events in range \(startTimeIsoDateStr) to \(endTimeIsoDateStr)")
                    }
                })
            }
        }
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
                    eventCounter++
                    if eventCounter > 1000 {
                        eventCounter = 0
                        NSLog("1000 items")
                    }
                    request.predicate = NSPredicate(format: "id = %@", id)
                    
                    do {
                        let foundObjects = try moc.executeFetchRequest(request) as! [CommonData]
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
        NSLog("\(eventCounter) items")
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
    class func getTidepoolEvents(fromTime: NSDate, toTime: NSDate, objectTypes: [String]? = nil) throws -> [CommonData] {
        let moc = NutDataController.controller().mocForTidepoolEvents()!

        // load on-demand: if data has not been loaded, a notification will come later!
        DatabaseUtils.checkLoadDataForDateRange(fromTime, endDate: toTime)

        let request = NSFetchRequest(entityName: "CommonData")
        
        if let types = objectTypes {
            // Return only objects of the requested types in the requested range
            request.predicate = NSPredicate(format: "(type IN %@) AND (time >= %@) AND (time <= %@)", types, fromTime, toTime)
        } else {
            // Return all objects in the requested range
            request.predicate = NSPredicate(format: "(time >= %@) AND (time <= %@)", fromTime, toTime)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        return try moc.executeFetchRequest(request) as! [CommonData]
    }

    // Note: This call has the side effect of fetching data from the service which may result in a future notification of database changes.
    // TODO: This will need to be reworked to sync data from the service when the service supports meal and workout events.
    class func getNutEvents(fromTime: NSDate? = nil, toTime: NSDate? = nil) throws -> [EventItem] {
        
        let moc = NutDataController.controller().mocForNutEvents()!
        let userId = NutDataController.controller().currentUserId!
        let request = NSFetchRequest(entityName: "EventItem")
        
        if let fromTime = fromTime, toTime = toTime {
            // Return only objects in the requested range for the current user!
            // TODO: remove nil option before shipping!
            request.predicate = NSPredicate(format: "((userid == %@) OR (userid = nil)) AND (time >= %@) AND (time <= %@)", userId, fromTime, toTime)
        } else {
            // Return all nut events in the requested range for the current user!
            // TODO: remove nil option before shipping!
            request.predicate = NSPredicate(format: "(userid == %@) OR (userid = nil)", userId)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        return try moc.executeFetchRequest(request) as! [EventItem]
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