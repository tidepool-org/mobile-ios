//
//  NutEvent.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/9/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutEvent {
    
    var title: String
    var itemArray = [NutEventItem]()
    
    init(title: String, itemArray: [NutEventItem]) {
        self.title = title
        self.itemArray = itemArray
    }
    
    class func testNutEvent(title: String) -> NutEvent {
        if (title == "Three Tacos") {
            return NutEvent(title: title, itemArray: [
                NutEventItem(subtext:"with 15 chips & salsa", timestamp: NSDate(timeIntervalSinceNow:-60*60*24), location:"home"),
                NutEventItem(subtext:"after ballet", timestamp: NSDate(timeIntervalSinceNow:-2*60*60*24), location:"238 Garrett St"),
                NutEventItem(subtext:"Apple Juice before", timestamp: NSDate(timeIntervalSinceNow:-2*60*60*24), location:"Golden Gate Park"),
                NutEventItem(subtext:"and horchata", timestamp: NSDate(timeIntervalSinceNow:-2*60*60*24), location:"Golden Gate Park")])
        } else {
            return NutEvent(title: title, itemArray: [])
        }
    }
}
