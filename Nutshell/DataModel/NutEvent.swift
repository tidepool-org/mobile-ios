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
    var itemArray: [Food]
    init(firstEvent: Food) {
        self.title = firstEvent.name!
        self.mostRecent = firstEvent.time!
        self.itemArray = [firstEvent]
    }
    
    func addEvent(newEvent: Food) {
        if (newEvent.name == self.title) {
            self.itemArray.append(newEvent)
            mostRecent = newEvent.time!.laterDate(mostRecent)
        } else {
            print("attempting to add item with non-matching title to NutEvent!")
        }
    }
    
    func printNutEvent() {
        print("nut has \(itemArray.count) items")
        for item in itemArray {
            print("item: \(item.name), \(item.location), \(item.time)")
        }
    }
    
    func describe() -> String {
        return "NutEvent with title: \(title) and items \(itemArray)"
    }

//    class func testNutEvent(title: String) -> NutEvent {
//        if (title == "Three Tacos") {
//            let df = NSDateFormatter()
//            return NutEvent(title: title, itemArray: [
//                NutEventItem(subtext: "with 15 chips & salsa", timestamp: df.dateFromISOString("2015-07-29 04:55:27 +0000"), location: "home"),
//                NutEventItem(subtext: "after ballet", timestamp: df.dateFromISOString("2015-07-29 01:38:53 +0000"), location:"238 Garrett St"),
//                NutEventItem(subtext: "Apple Juice before", timestamp: df.dateFromISOString("2015-07-10 14:25:21 +0000"), location: "Golden Gate Park"),
//                NutEventItem(subtext: "and horchata", timestamp: NSDate(), location: "Golden Gate Park")])
//        } else {
//            return NutEvent(title: title, itemArray: [])
//        }
//    }
}
