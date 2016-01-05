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

/// Basic graph datapoint has a value and a time offset.
class GraphDataType {

    let value: CGFloat
    let timeOffset: NSTimeInterval
    
    init(value: CGFloat = 0.0, timeOffset: NSTimeInterval = 0.0) {
        self.value = value
        self.timeOffset = timeOffset
    }
    
    func label() -> String {
        return String(value)
    }
    
    func typeString() -> String {
        return ""
    }
}

// OLD ARCH
struct BolusData {
    var timeOffset: NSTimeInterval = 0
    var value: CGFloat = 0.0  // value is normal plus any extended bolus delivered
    var hasExtension: Bool = false
    var extendedValue: CGFloat = 0.0
    var duration: NSTimeInterval = 0.0
    
    init(event: Bolus, deltaTime: NSTimeInterval) {
        self.timeOffset = deltaTime
        self.value = CGFloat(event.value!)
        self.hasExtension = false
        let extendedBolus = event.extended
        let duration = event.duration
        if let extendedBolus = extendedBolus, duration = duration {
            self.hasExtension = true
            self.extendedValue = CGFloat(extendedBolus)
            let durationInMS = Int(duration)
            self.duration = NSTimeInterval(durationInMS / 1000)
        }
    }
}
