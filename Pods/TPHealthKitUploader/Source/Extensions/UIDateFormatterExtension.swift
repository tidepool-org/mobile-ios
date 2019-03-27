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

let iso8601dateZuluTime: String = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
let iso8601dateNoTimeZone: String = "yyyy-MM-dd'T'HH:mm:ss"

public extension DateFormatter {

    func isoStringFromDate(_ date: Date, zone: TimeZone? = nil, dateFormat: String? = nil) -> String {
        self.locale = Locale(identifier: "en_US_POSIX")
        if (zone != nil) {
            self.timeZone = zone
        } else {
            self.timeZone = TimeZone.autoupdatingCurrent
        }
        self.dateFormat = dateFormat ?? iso8601dateZuluTime
        return self.string(from: date)
    }
    
}
