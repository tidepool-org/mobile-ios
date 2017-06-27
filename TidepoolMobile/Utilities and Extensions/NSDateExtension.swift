/*
* Copyright (c) 2016, Tidepool Project
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

extension Date {
    func differenceInDays(_ date: Date) -> Int {
        let calendar: Calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.day, from: calendar.startOfDay(for: self), to: calendar.startOfDay(for: date), options: [])
        return components.day!
    }
    
    func timeAgoInWords(_ date: Date) -> String {
        // TODO: Localize these strings
        
        let timeAgoInSeconds = round(abs(date.timeIntervalSince(self)))
        
        switch timeAgoInSeconds {
        case 0...59:
            return "less than a minute ago"
        default:
            break
        }
        
        let timeAgoInMinutes = round(timeAgoInSeconds / 60.0)
        switch timeAgoInMinutes {
        case 0...1:
            return "1 minute ago"
        case 2...59:
            return "\(Int(timeAgoInMinutes))" + " minutes ago"
        default:
            break
        }

        let timeAgoInHours = round(timeAgoInMinutes / 60.0)
        switch timeAgoInHours {
        case 0...1:
            return "1 hour ago"
        case 2...23:
            return "\(Int(timeAgoInHours))" + " hours ago"
        default:
            break
        }
        
        let timeAgoInDays = round(timeAgoInHours / 24.0)
        switch timeAgoInDays {
        case 0...1:
            return "1 day ago"
        case 2...29:
            return "\(Int(timeAgoInDays))" + " days ago"
        default:
            break
        }
        
        let timeAgoInMonths = round(timeAgoInDays / 30.0)
        switch timeAgoInMonths {
        case 0...1:
            return "1 month ago"
        case 2...11:
            return "\(Int(timeAgoInMonths))" + " months ago"
        default:
            break
        }
        
        let timeAgoInYears = round(timeAgoInMonths / 12.0)
        switch timeAgoInYears {
        case 0...1:
            return "1 year ago"
        default:
            return "\(Int(timeAgoInYears))" + " years ago"
        }
    }
}
