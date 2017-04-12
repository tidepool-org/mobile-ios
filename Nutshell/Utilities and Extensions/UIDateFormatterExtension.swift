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

// ------------ Date Formatter ------------

/*
Commonly used date formats
Careful with changing iso8601 date formats
Uniform date format will change NoteCell and Add/EditNoteVCs
Regular date format for birthdays, diagnosis date, etc.
*/

// TODO: the dates here are slightly different - reconcile!
let iso8601dateOne: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
let iso8601dateTwo: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
let iso8601dateZuluTime: String = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
let iso8601dateNoTimeZone: String = "yyyy-MM-dd'T'HH:mm:ss"
let regularDateFormat: String = "yyyy-MM-dd"

public extension DateFormatter {

    func attributedStringFromDate(_ date: Date) -> NSMutableAttributedString {
        let uniformDateFormat: String = "EEEE M/d/yy h:mma"
        // Date format being used.
        self.dateFormat = uniformDateFormat
        var dateString = self.string(from: date)
        
        // Replace uppercase PM and AM with lowercase versions
        dateString = dateString.replacingOccurrences(of: "PM", with: "pm", options: NSString.CompareOptions.literal, range: nil)
        dateString = dateString.replacingOccurrences(of: "AM", with: "am", options: NSString.CompareOptions.literal, range: nil)
        
        // Count backwards until the first space (will bold)
        var count = 0
        for char in Array(dateString.characters.reversed()) {
            if (char == " ") {
                break
            } else {
                count += 1
            }
        }
        
        // Bold the last (count) characters (the time)
        let attrStr = NSMutableAttributedString(string: dateString, attributes: [NSForegroundColorAttributeName: noteTextColor, NSFontAttributeName: smallRegularFont])
        attrStr.addAttribute(NSFontAttributeName, value: smallBoldFont, range: NSRange(location: attrStr.length - count, length: count))
        
        return attrStr
    }

    func dateFromISOString(_ string: String) -> Date? {
        self.locale = Locale(identifier: "en_US_POSIX")
        self.timeZone = TimeZone.autoupdatingCurrent
        self.dateFormat = iso8601dateOne
        if let date = self.date(from: string) {
            return date
        } else {
            self.dateFormat = iso8601dateTwo
            return self.date(from: string)
        }
    }
    
    func isoStringFromDate(_ date: Date, zone: TimeZone? = nil, dateFormat: String = iso8601dateOne) -> String {
        self.locale = Locale(identifier: "en_US_POSIX")
        if (zone != nil) {
            self.timeZone = zone
        } else {
            self.timeZone = TimeZone.autoupdatingCurrent
        }
        self.dateFormat = dateFormat
        return self.string(from: date)
    }
    
    func stringFromRegDate(_ date:Date) -> String {
        self.dateFormat = regularDateFormat
        return string(from: date)
    }
    
}
