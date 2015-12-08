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
    
    /** Removes everything from the database. Do this on logout and / or after a successful login */
    // TODO: add code to delete "meal" and "workout" items from the database once we upload them to the service so they are backed up.
    class func clearDatabase(moc: NSManagedObjectContext) {
        NSLog("***Clearing database!***")
        moc.performBlock { () -> Void in
            
            let entities = ["Activity", "Alarm", "Basal", "BloodKetone", "Bolus", "Calibration",
                "ContinuousGlucose", "Food", "GrabBag", "Note", "Prime", "ReservoirChange", "SelfMonitoringGlucose",
                "Settings", "Status", "TimeChange", "Upload", "UrineKetone", "Wizard", "User"]
            
            var objectCount = 0
            for entity in entities {
                do {
                    let request = NSFetchRequest(entityName: entity)
                    let myList = try moc.executeFetchRequest(request)
                    for obj: AnyObject in myList {
                        moc.deleteObject(obj as! NSManagedObject)
                        objectCount++
                    }
                } catch let error as NSError {
                    print("Failed to delete \(entity) items: \(error)")
                }
            }
            
            do {
                try moc.save()
                NSLog("***Database cleared of \(objectCount) objects!***")
            } catch let error as NSError {
                NSLog("clearDatabase: Failed to save MOC: \(error)")
            }
        }
    }

    class func databaseSave(moc: NSManagedObjectContext) -> Bool {
        // Save the database
        do {
            try moc.save()
            print("EventGroup: Database saved!")
            return true
        } catch let error as NSError {
            // TO DO: error message!
            print("Failed to save MOC: \(error)")
            return false
        }
    }

    class func getUser(moc: NSManagedObjectContext) -> User? {
        let request = NSFetchRequest(entityName: "User")
        do {
            if let results = try moc.executeFetchRequest(request) as? [User] {
                return results[0]
            }
            return  nil
        } catch let error as NSError {
            print("Error getting user: \(error)")
            return nil
        }
    }
    
    class func updateUser(currentUser: User?, newUser: User?) {
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        // Remove existing user if passed in
        if let currentUser = currentUser {
            let request = NSFetchRequest(entityName: "User")
            request.predicate = NSPredicate(format: "userid==%@", currentUser.userid!)
            do {
                let results = try moc.executeFetchRequest(request) as! [User]
                for result in results {
                    moc.deleteObject(result)
                }
            } catch let error as NSError {
                print("Failed to remove existing user: \(currentUser.userid) error: \(error)")
            }
        }

        if let newUser = newUser {
            moc.insertObject(newUser)
        }
        
        // Save the database
        do {
            try moc.save()
        } catch let error as NSError {
            print("Failed to save MOC for user: \(error)")
        }
    }

    // MARK: - Methods to cache read-only data from service

    // A sorted cache of server blocks we have fetched during the current application lifetime, along with the date of fetch...
    static var serverBlocks = [Int : NSDate]()

    class func dateToBucketNumber(date: NSDate) -> Int {
        let refSeconds = Int(date.timeIntervalSinceReferenceDate)
        let kBucketSeconds = 60*60*20 // 20 hour chunks
        let result = refSeconds/kBucketSeconds
        print("Date: \(date), bucket number: \(result)")
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
        print("Bucket number: \(bucket), date: \(date), string: \(result)")
        return result
    }

    class func checkLoadDataForDateRange(startDate: NSDate, endDate: NSDate) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let now = NSDate()
        let startBucket = DatabaseUtils.dateToBucketNumber(startDate)
        let endBucket = DatabaseUtils.dateToBucketNumber(endDate)
        for bucket in startBucket...endBucket {
            
            if let lastFetchDate = serverBlocks[bucket] {
                if now.timeIntervalSinceDate(lastFetchDate) < 60*10 {
                    // don't check more often than every 10 minutes...
                    NSLog("checkLoadDataForDateRange: skip load of bucket \(bucket)")
                    continue
                }
            }
            // kick off a fetch if we are online...
            if appDelegate.serviceAvailable() {
                // TODO: if fetch fails, should we wait less time before retrying? 
                serverBlocks[bucket] = now
                let moc = appDelegate.managedObjectContext
                let startTimeIsoDateStr = DatabaseUtils.bucketNumberToIsoDateString(bucket)
                let endTimeIsoDateStr = DatabaseUtils.bucketNumberToIsoDateString(bucket+1)
                appDelegate.API?.getReadOnlyUserData(startTimeIsoDateStr, endDate:endTimeIsoDateStr, completion: { (result) -> (Void) in
                    if result.isSuccess {
                        DatabaseUtils.updateEvents(moc, eventsJSON: result.value!)
                    } else {
                        print("Failed to get events in range for user. Error: \(result.error!)")
                    }
                })
            }
        }
    }
    
    class func updateEventsForRange(moc: NSManagedObjectContext, eventsJSON: JSON) {
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
                        print("updateEvents: Failed to replace existing event with ID \(id) error: \(error)")
                    }
                } else {
                    print("updateEvents: no ID found for object: \(obj), not inserting!")
                }
            }
        }
        NSLog("extra events processed: \(eventCounter)")
        // Save the database
        do {
            try moc.save()
            print("updateEvents: Database saved!")
            //dispatch_async(dispatch_get_main_queue()) {
            notifyOnDataLoad()
            //}
        } catch let error as NSError {
            print("Failed to save MOC: \(error)")
        }
    }
    
    class func notifyOnDataLoad() {
        // This will come in on the main thread, unlike the NSManagedObjectContextDidSaveNotification
        NSNotificationCenter.defaultCenter().postNotificationName(NewBlockRangeLoadedNotification, object:nil)
    }
    
    // Note: This call has the side effect of fetching data from the service which may result in a future notification of database changes.
    class func getEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate, objectTypes: [String]? = nil) throws -> [CommonData] {

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

//    class func getMealItem(moc: NSManagedObjectContext, atTime: NSDate, title: String) throws -> [Meal] {
//        let request = NSFetchRequest(entityName: "EventItem")
//        request.predicate = NSPredicate(format: "(title == %@) AND  (time == %@)", title, atTime)
//        return try moc.executeFetchRequest(request) as! [Meal]
//    }

    // TODO: This will need to be reworked to sync data from the service when the service supports meal and workout events.
    class func getAllNutEvents(moc: NSManagedObjectContext) throws -> [EventItem] {
        let request = NSFetchRequest(entityName: "EventItem")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        return try moc.executeFetchRequest(request) as! [EventItem]
    }

//    class func getAllWorkoutEvents(moc: NSManagedObjectContext) throws -> [Workout] {
//        let request = NSFetchRequest(entityName: "Workout")
//        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
//        return try moc.executeFetchRequest(request) as! [Workout]
//    }
//
//    class func getAllMealEvents(moc: NSManagedObjectContext) throws -> [Meal] {
//        let request = NSFetchRequest(entityName: "Meal")
//        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
//        return try moc.executeFetchRequest(request) as! [Meal]
//    }
//    
//    class func getAllWizardEvents(moc: NSManagedObjectContext) throws -> [Wizard] {
//        let request = NSFetchRequest(entityName: "Wizard")
//        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
//        return try moc.executeFetchRequest(request) as! [Wizard]
//    }

    class func deleteAllNutEvents(moc: NSManagedObjectContext) {
        // TODO: Note this is currently only used for testing!
        do {
            let request = NSFetchRequest(entityName: "Meal")
            let myList = try moc.executeFetchRequest(request)
            for obj: AnyObject in myList {
                if let objId = obj.id as? String {
                    if objId.hasPrefix("demo")  {
                        moc.deleteObject(obj as! NSManagedObject)
                    }
                }
            }
        } catch let error as NSError {
            print("Failed to delete meal items: \(error)")
        }
        
        do {
            let request = NSFetchRequest(entityName: "Workout")
            let myList = try moc.executeFetchRequest(request)
            for obj: AnyObject in myList {
                if let objId = obj.id as? String {
                    if objId.hasPrefix("demo")  {
                        moc.deleteObject(obj as! NSManagedObject)
                    }
                }
            }
        } catch let error as NSError {
            print("Failed to delete workout items: \(error)")
        }

        
        do {
            try moc.save()
        } catch let error as NSError {
            print("clearDatabase: Failed to save MOC: \(error)")
        }
    }
}