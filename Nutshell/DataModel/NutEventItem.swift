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