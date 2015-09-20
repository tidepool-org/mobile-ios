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

class DatabaseUtils {
    
    /** Removes everything from the database. Do this on logout and / or after a successful login */
    class func clearDatabase(moc: NSManagedObjectContext) {
        moc.performBlock { () -> Void in
            
            let entities = ["Activity", "Alarm", "Basal", "BloodKetone", "Bolus", "Calibration",
                "ContinuousGlucose", "Food", "GrabBag", "Note", "Prime", "ReservoirChange", "SelfMonitoringGlucose",
                "Settings", "Status", "TimeChange", "Upload", "UrineKetone", "Wizard", "User"]
            
            for entity in entities {
                do {
                    let request = NSFetchRequest(entityName: entity)
                    let myList = try moc.executeFetchRequest(request)
                    for obj: AnyObject in myList {
                        moc.deleteObject(obj as! NSManagedObject)
                    }
                } catch let error as NSError {
                    print("Failed to delete \(entity) items: \(error)")
                }
            }
            
            do {
                try moc.save()
            } catch let error as NSError {
                print("clearDatabase: Failed to save MOC: \(error)")
            }
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
    
    class func updateUser(moc: NSManagedObjectContext, user: User) {
        // Remove existing users
        let request = NSFetchRequest(entityName: "User")
        request.predicate = NSPredicate(format: "userid==%@", user.userid!)
        do {
            let results = try moc.executeFetchRequest(request) as! [User]
            for result in results {
                moc.deleteObject(result)
            }
        } catch let error as NSError {
            print("Failed to remove existing user: \(user.userid) error: \(error)")
        }
        
        moc.insertObject(user)
        // Save the database
        do {
            try moc.save()
        } catch let error as NSError {
            print("Failed to save MOC: \(error)")
        }
    }
    
    class func updateEvents(moc: NSManagedObjectContext, eventsJSON: JSON) {
        // We get back an array of JSON objects. Iterate through the array and insert the objects
        // into the database, removing any existing objects we may have.
        
        // Do this in the background- currently it takes forever because the result set is huge
        dispatch_async(dispatch_get_global_queue(Int(DISPATCH_QUEUE_PRIORITY_BACKGROUND), 0)){
            let bgMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            bgMOC.persistentStoreCoordinator = moc.persistentStoreCoordinator;
            
            let request = NSFetchRequest(entityName: "CommonData")
            for (_, subJson) in eventsJSON {
                if let obj = CommonData.fromJSON(subJson, moc: bgMOC) {
                    // Remove existing object with the same ID
                    if let id=obj.id {
                        request.predicate = NSPredicate(format: "id = %@", id)
                        do {
                            let foundObjects = try bgMOC.executeFetchRequest(request) as! [NSManagedObject]
                            for foundObject in foundObjects {
                                bgMOC.deleteObject(foundObject)
                            }
                            bgMOC.insertObject(obj)
                        } catch let error as NSError {
                            print("updateEvents: Failed to replace existing event with ID \(id) error: \(error)")
                        }
                    } else {
                        print("udpateEvents: no ID found for object: \(obj), not inserting!")
                    }
                }
            }
            
            // Save the database
            do {
                try bgMOC.save()
                print("updateEvents: Database saved!")
            } catch let error as NSError {
                print("Failed to save MOC: \(error)")
            }
        }
    }
    
    class func getEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate) throws -> [CommonData] {
        let request = NSFetchRequest(entityName: "CommonData")
        request.predicate = NSPredicate(format: "(time >= %@) AND (time <= %@)", fromTime, toTime)
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [CommonData]
    }

    class func getSmbgAndBolusEvents(moc: NSManagedObjectContext) throws -> [CommonData] {
        let request = NSFetchRequest(entityName: "CommonData")
            request.predicate = NSPredicate(format: "(type == %@) OR (type == %@)", "smbg", "bolus")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [CommonData]
    }

    class func getAllFoodEvents(moc: NSManagedObjectContext) throws -> [Food] {
        let request = NSFetchRequest(entityName: "Food")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [Food]
    }
    
    class func getActivityEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate) throws -> [Activity] {
        let request = NSFetchRequest(entityName: "Activity")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [Activity]
    }
    
    class func getBolusEvents(moc: NSManagedObjectContext, fromTime: NSDate?, toTime: NSDate?) throws -> [Bolus] {
        let request = NSFetchRequest(entityName: "Bolus")
        if let fromTime = fromTime, toTime = toTime {
            request.predicate = NSPredicate(format: "(time >= %@) AND (time <= %@)", fromTime, toTime)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [Bolus]
    }

    class func getSmbgEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate) throws -> [SelfMonitoringGlucose] {
        let request = NSFetchRequest(entityName: "SelfMonitoringGlucose")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [SelfMonitoringGlucose]
    }

    class func getCbgEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate) throws -> [ContinuousGlucose] {
        let request = NSFetchRequest(entityName: "ContinuousGlucose")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [ContinuousGlucose]
    }

    class func getBasalEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate) throws -> [Basal] {
        let request = NSFetchRequest(entityName: "Basal")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [Basal]
    }

}