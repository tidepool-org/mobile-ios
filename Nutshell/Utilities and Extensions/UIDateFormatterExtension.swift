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

//
//  Extension to format the dates consistently through the application.
//

import UIKit

// TODO: change this file to return strings useful for nutshell...
// ------------ Date Formatter ------------

/*
Commonly used date formats
Careful with changing iso8601 date formats
Uniform date format will change NoteCell and Add/EditNoteVCs
Regular date format for birthdays, diagnosis date, etc.
*/

let iso8601dateOne: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
let iso8601dateTwo: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

public extension NSDateFormatter {
    
    func dateFromISOString(string: String) -> NSDate? {
        self.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        self.timeZone = NSTimeZone.localTimeZone()
        self.dateFormat = iso8601dateOne
        if let date = self.dateFromString(string) {
            return date
        }
        self.dateFormat = iso8601dateTwo
        if let date = self.dateFromString(string) {
            return date
        }
        print("ERROR: can't handle date format for: \(string)")
        return nil
    }
    
    func isoStringFromDate(date: NSDate, zone: NSTimeZone?) -> String {
        self.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        if (zone != nil) {
            self.timeZone = zone
        } else {
            self.timeZone = NSTimeZone.localTimeZone()
        }
        self.dateFormat = iso8601dateOne
        return self.stringFromDate(date)
    }
    
}
