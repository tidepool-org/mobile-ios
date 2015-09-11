//  Copyright (c) 2015, Tidepool Project
//  All rights reserved.
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
