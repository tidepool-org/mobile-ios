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
    var mostRecent: NSDate
    var itemArray: [NutMeal]
    init(firstEvent: Meal) {
        self.title = firstEvent.title != nil ? firstEvent.title! : ""
        // TODO: should NutMeal also take optionals?
        if firstEvent.time == nil {
            print("ERROR: nil time leaked in for event \(self.title)")
        }
        self.mostRecent = firstEvent.time != nil ? firstEvent.time! : NSDate()
        let firstItem = NutMeal(title: firstEvent.title, notes: firstEvent.notes, location: firstEvent.location, photo: firstEvent.photo, time: firstEvent.time)
        self.itemArray = [firstItem]
    }
    
    func addEvent(newEvent: Meal) {
        if (newEvent.title == self.title) {
            let newItem = NutMeal(title: newEvent.title, notes: newEvent.notes, location: newEvent.location, photo: newEvent.photo, time: newEvent.time)
            
            self.itemArray.append(newItem)
            mostRecent = newItem.time.laterDate(mostRecent)
        } else {
            print("attempting to add item with non-matching title to NutEvent!")
        }
    }
    
    func printNutEvent() {
        print("nut has \(itemArray.count) items")
        for item in itemArray {
            print("item: \(item.notes), \(item.location), \(item.time)")
        }
    }
    
    func describe() -> String {
        return "NutEvent with title: \(title) and items \(itemArray)"
    }

}
