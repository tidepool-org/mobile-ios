//
//  NutEvent.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/9/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutEventItem {
    
    var subtext: String
    var timestamp: NSDate
    var location: String
    var guid: String
    
    init(subtext: String, timestamp: NSDate, location: String) {
        self.subtext = subtext
        self.timestamp = timestamp
        self.location = location
        self.guid = NSUUID().UUIDString
    }
    
    convenience init(subtext: String) {
        self.init(subtext:subtext, timestamp:NSDate(), location:"")
    }

    convenience init() {
        self.init(subtext:"")
    }

    func dictionaryFromNSEvent() -> [String: AnyObject] {
        let dateFormatter = NSDateFormatter()
        let jsonObject: [String: AnyObject] = [
            "nuteventitem": [
                "subtext": self.subtext,
                "timestamp": dateFormatter.isoStringFromDate(self.timestamp, zone: nil),
                "location": self.location,
                "guid": self.guid
            ]
        ]
        return jsonObject
    }
}