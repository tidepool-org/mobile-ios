//
//  NutEventList.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/10/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

/*
    This part of the data model should provide:

    - A current list of events (nuts?) the user has entered in this app, sorted chronologically, most recent date first. Each nut event can have more than one nut event item.
    - The nut event database will have to be synced with the service to pick up changes entered on other devices. (Could use iCloud for now to do this easily?)
    - An interface to add a new event/item, or delete an existing event/item. If the title for the event item matches an existing event, it is added to that event's item array.
    - A search function that returns a subset of the sorted list of events, based on a query that matches a string. Actually this should include the workout events from Healthkit as well.
    - This database should probably be available offline, so users can add events when they don't have network access. They won't see their blood glucose or insulin data until after entering in events anyway, when they can sync their monitors/pumps with the service.
*/

class EventListDB {

    //    public class var darkBackground: UIColor { return Cache.darkBackground }

    class func testNutEventList() -> NSArray {
        return [NutEvent.testNutEvent("Three Tacos"),
            NutEvent.testNutEvent("Workout"),
            NutEvent.testNutEvent(""),
            NutEvent.testNutEvent("CPK 5 cheese margarita"),
            NutEvent.testNutEvent("Bagel & cream cheese fruit"),
            NutEvent.testNutEvent("Birthday Party"),
            NutEvent.testNutEvent("Soccer Practice")]
    }
    
}
