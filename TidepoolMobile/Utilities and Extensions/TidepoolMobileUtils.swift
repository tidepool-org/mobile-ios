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

import UIKit
import CoreData
import Photos

class TidepoolMobileUtils {

    class func onIPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    class func dispatchBoolToVoidAfterSecs(_ secs: Float, result: Bool, boolToVoid: @escaping (Bool) -> (Void)) {
        let time = DispatchTime.now() + Double(Int64(secs * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time){
            boolToVoid(result)
        }
    }
    
    class func delay(_ delay:Double, closure:@escaping ()->()) {
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
    }
    
    class func dateFromJSON(_ json: String?) -> Date? {
        if let json = json {
            var result = jsonDateFormatter.date(from: json)
            if result == nil {
                result = jsonAltDateFormatter.date(from: json)
            }
            return result
        }
        return nil
    }
    
    class func dateToJSON(_ date: Date) -> String {
        return jsonDateFormatter.string(from: date)
    }

    class func decimalFromJSON(_ json: String?) -> NSDecimalNumber? {
        if let json = json {
            return NSDecimalNumber(string: json)
        }
        return nil
    }

    /** Date formatter for JSON date strings */
    class var jsonDateFormatter : DateFormatter {
        struct Static {
            static let instance: DateFormatter = {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                dateFormatter.timeZone = TimeZone(identifier: "GMT")
                return dateFormatter
                }()
        }
        return Static.instance
    }
    
    class var jsonAltDateFormatter : DateFormatter {
        struct Static {
            static let instance: DateFormatter = {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                dateFormatter.timeZone = TimeZone(identifier: "GMT")
                return dateFormatter
            }()
        }
        return Static.instance
    }

    
    /** Date formatter for date strings in the UI */
    fileprivate class var dateFormatter : DateFormatter {
        struct Static {
            static let instance: DateFormatter = {
                let df = DateFormatter()
                df.dateFormat = Styles.uniformDateFormat
                return df
            }()
        }
        return Static.instance
    }

    // NOTE: these date routines are not localized, and do not take into account user preferences for date display.

    /// Call setFormatterTimezone to set time zone before calling standardUIDayString or standardUIDateString
    class func setFormatterTimezone(_ timezoneOffsetSecs: Int) {
        let df = TidepoolMobileUtils.dateFormatter
        df.timeZone = TimeZone(secondsFromGMT:timezoneOffsetSecs)
    }
    
    /// Returns delta time different due to a different daylight savings time setting for a date different from the current time, assuming the location-based time zone is the same as the current default.
    class func dayLightSavingsAdjust(_ dateInPast: Date) -> Int {
        let thisTimeZone = TimeZone.autoupdatingCurrent
        let dstOffsetForThisDate = thisTimeZone.daylightSavingTimeOffset(for: Date())
        let dstOffsetForPickerDate = thisTimeZone.daylightSavingTimeOffset(for: dateInPast)
        let dstAdjust = dstOffsetForPickerDate - dstOffsetForThisDate
        return Int(dstAdjust)
    }
    
    /// Returns strings like "Mar 17, 2016", "Today", "Yesterday"
    /// Note: call setFormatterTimezone before this!
    class func standardUIDayString(_ date: Date) -> String {
        let df = TidepoolMobileUtils.dateFormatter
        df.dateFormat = "MMM d, yyyy"
        var dayString = df.string(from: date)
        // If this year, remove year.
        df.dateFormat = ", yyyy"
        let thisYearString = df.string(from: Date())
        dayString = dayString.replacingOccurrences(of: thisYearString, with: "")
        // Replace with today, yesterday if appropriate: only check if it's in the last 48 hours
        // TODO: look at using NSCalendar.startOfDayForDate and then time intervals to determine today, yesterday, Saturday, etc., back a week.
        if (date.timeIntervalSinceNow > -48 * 60 * 60) {
            if Calendar.current.isDateInToday(date) {
                dayString = "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                dayString = "Yesterday"
            }
        }
        return dayString
    }
    
    /// Returns strings like "Yesterday at 9:17 am"
    /// Note: call setFormatterTimezone before this!
    class func standardUIDateString(_ date: Date) -> String {
        let df = TidepoolMobileUtils.dateFormatter
        let dayString = TidepoolMobileUtils.standardUIDayString(date)
        // Figure the hour/minute part...
        df.dateFormat = "h:mm a"
        var hourString = df.string(from: date)
        // Replace uppercase PM and AM with lowercase versions
        hourString = hourString.replacingOccurrences(of: "PM", with: "pm", options: NSString.CompareOptions.literal, range: nil)
        hourString = hourString.replacingOccurrences(of: "AM", with: "am", options: NSString.CompareOptions.literal, range: nil)
        return dayString + " at " + hourString
    }

}
