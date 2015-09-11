//  Copyright (c) 2015, Tidepool Project
//  All rights reserved.
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
