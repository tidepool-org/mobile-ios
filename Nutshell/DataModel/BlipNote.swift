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

class BlipNote {
    
    var id: String
    var userid: String
    var groupid: String
    var timestamp: Date
    var createdtime: Date
    var messagetext: String
    var user: BlipUser?
    
    init(id: String, userid: String, groupid: String, timestamp: Date, createdtime: Date, messagetext: String, user: BlipUser) {
        self.id = id
        self.userid = userid
        self.groupid = groupid
        self.timestamp = timestamp
        self.createdtime = createdtime
        self.messagetext = messagetext
        self.user = user
    }
    
    init() {
        self.id = ""
        self.userid = ""
        self.groupid = ""
        self.timestamp = Date()
        self.createdtime = Date()
        self.messagetext = ""
    }
    
    func dictionaryFromNote() -> [String: AnyObject] {
        let dateFormatter = DateFormatter()
        let jsonObject: [String: AnyObject] = [
            "message": [
                "guid": UUID().uuidString,
                "userid": self.userid,
                "groupid": self.groupid,
                "parentmessage": NSNull(),
                "timestamp": dateFormatter.isoStringFromDate(self.timestamp, zone: nil),
                "messagetext": self.messagetext
            ] as AnyObject
        ]
        return jsonObject
    }
    
    func updatesFromNote() -> [String: AnyObject] {

        let dateFormatter = DateFormatter()
        let jsonObject: [String: AnyObject] = [
            "message": [
                "timestamp": dateFormatter.isoStringFromDate(self.timestamp, zone: nil),
                "messagetext": self.messagetext
            ] as AnyObject
        ]
        return jsonObject
    }
}
