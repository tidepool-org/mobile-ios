//
//  DatabaseUtils.swift
//  Nutshell
//
//  Created by Brian King on 9/16/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData

class DatabaseUtils {
    
    /** Removes everything from the database. Do this on logout and / or after a successful login */
    class func clearDatabase(moc: NSManagedObjectContext) {
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
    
    class func getEvents(moc: NSManagedObjectContext, fromTime: NSDate, toTime: NSDate) throws -> [CommonData] {
        let request = NSFetchRequest(entityName: "CommonData")
        request.predicate = NSPredicate(format: "(time >= %@) AND (time <= %@)", fromTime, toTime)
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        return try moc.executeFetchRequest(request) as! [CommonData]
    }
}