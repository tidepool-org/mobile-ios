//  Copyright (c) 2015, Tidepool Project
//  All rights reserved.
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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