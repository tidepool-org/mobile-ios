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

class NutEvent {
    
    var title: String
    var location: String
    var mostRecent: NSDate
    var itemArray: [NutEventItem]

    init(firstEvent: EventItem) {
        self.title = firstEvent.title!
        self.location = ""
        self.mostRecent = firstEvent.time!
        if let meal = firstEvent as? Meal {
            let firstItem = NutMeal(meal: meal, title: meal.title, notes: meal.notes, location: meal.location, photo: meal.photo, time: meal.time)
            if let loc = meal.location {
                self.location = loc
            }
            self.itemArray = [firstItem]
        } else if let workout = firstEvent as? Workout {
            let firstItem = NutWorkout(workout: workout, title: workout.title, notes: workout.notes, distance: workout.distance, duration: workout.duration, time: workout.time)
            self.itemArray = [firstItem]
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
    
    func addEvent(newEvent: EventItem) {
        if (newEvent.title == self.title) {
            if let meal = newEvent as? Meal {
                let newItem = NutMeal(meal: meal, title: meal.title, notes: meal.notes, location: meal.location, photo: meal.photo, time: meal.time)
                self.itemArray.append(newItem)
                mostRecent = newItem.time.laterDate(mostRecent)
            } else if let workout = newEvent as? Workout {
                let newItem = NutWorkout(workout: workout, title: workout.title, notes: workout.notes, distance: workout.distance, duration: workout.duration, time: workout.time)
                self.itemArray.append(newItem)
                mostRecent = newItem.time.laterDate(mostRecent)
            }
        } else {
            print("attempting to add item with non-matching title to NutEvent!")
        }
    }
    
    func sortEvents() {
        itemArray = itemArray.sort() {
            $0.time.compare($1.time) == NSComparisonResult.OrderedDescending }
    }
    
    func printNutEvent() {
        print("nut has \(itemArray.count) items")
        for item in itemArray {
            print("item: \(item.notes), \(item.time)")
        }
    }
    
    func describe() -> String {
        return "NutEvent with title: \(title) and items \(itemArray)"
    }

}
