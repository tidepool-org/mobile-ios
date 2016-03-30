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

import Foundation
import UIKit
import CoreData

class NutEvent {
    
    var title: String
    var location: String
    var mostRecent: NSDate
    var itemArray: [NutEventItem]
    var isWorkout: Bool = false

    init(firstEvent: EventItem) {
        self.title = firstEvent.title!
        self.location = ""
        self.mostRecent = firstEvent.time!
        if let meal = firstEvent as? Meal {
            let firstItem = NutMeal(meal: meal)
            if let loc = meal.location {
                self.location = loc
            }
            self.itemArray = [firstItem]
        } else if let workout = firstEvent as? Workout {
            let firstItem = NutWorkout(workout: workout)
            self.itemArray = [firstItem]
            isWorkout = true
        } else {
            self.itemArray = []
        }
    }
    
    init() {
        self.title = ""
        self.location = ""
        self.mostRecent = NSDate()
        self.itemArray = []
    }
    
    func addEvent(newEvent: EventItem) -> NutEventItem? {
        var newItem: NutEventItem? = nil
        if (newEvent.nutEventIdString() == self.nutEventIdString()) {
            if let meal = newEvent as? Meal {
                newItem = NutMeal(meal: meal)
                self.itemArray.append(newItem!)
                mostRecent = newItem!.time.laterDate(mostRecent)
            } else if let workout = newEvent as? Workout {
                newItem = NutWorkout(workout: workout)
                self.itemArray.append(newItem!)
                mostRecent = newItem!.time.laterDate(mostRecent)
            }
        } else {
            NSLog("attempting to add item with non-matching title and location to NutEvent!")
        }
        return newItem
    }
    
    class func createMealEvent(title: String, notes: String, location: String, photo: String, photo2: String, photo3: String, time: NSDate, timeZoneOffset: Int) -> EventItem? {
        let moc = NutDataController.controller().mocForNutEvents()!
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
            me.title = title
            me.notes = notes
            me.location = location
            me.photo = photo
            me.photo2 = photo2
            me.photo3 = photo3
            me.time = time
            me.type = "meal"
            let now = NSDate()
            me.createdTime = now
            me.modifiedTime = now
            me.timezoneOffset = timeZoneOffset/60
            // TODO: Determine policy for local id creation!
            me.id = NSUUID().UUIDString
            me.userid = NutDataController.controller().currentUserId // critical!
            moc.insertObject(me)
            if DatabaseUtils.databaseSave(moc) {
                return me
            }
        }
        return nil
    }
    
    func sortEvents() {
        itemArray = itemArray.sort() {
            $0.time.compare($1.time) == NSComparisonResult.OrderedDescending }
    }

    func nutEventIdString() -> String {
        // TODO: this will alias:
        //  title: "My NutEvent at Home", loc: "" with
        //  title: "My NutEvent at ", loc: "Home"
        // But for now consider this a feature...
        let prefix = isWorkout ? "W" : "M"
        return prefix + title + location
    }

    func containsSearchString(searchString: String) -> Bool {
        if title.localizedCaseInsensitiveContainsString(searchString) {
            return true
        }
        if location.localizedCaseInsensitiveContainsString(searchString) {
            return true
        }
        for nutItem in itemArray {
            if nutItem.containsSearchString(searchString) {
                return true
            }
        }
        return false;
    }

    func printNutEvent() {
        NSLog("nut has \(itemArray.count) items")
        for item in itemArray {
            NSLog("item: \(item.notes), \(item.time)")
        }
    }
    
    func describe() -> String {
        return "NutEvent with title: \(title) and items \(itemArray)"
    }

}
