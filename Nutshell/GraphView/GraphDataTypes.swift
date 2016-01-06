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
    //
    
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
    
    /// Nominal width of an object. This is not used for drawing, but dealing with overlap of graphs constructed of multiple verical panes (collection cells).
    /// For example, a datapoint value shown as a circle of diameter 10 pixels (with the data value at the center) might have one pixel drawn on pane A, and the other nine on the following pane B. Since data is fetched by time, pane A needs to include data of this type whose center point is up to a radius past the end of A. If the circle had 9 points on pane A and 1 on pane B, pane B would need to include data whose center point is up to half a diameter before pane B.
    func nominalPixelWidth() -> CGFloat {
        return 0.0
    }
    
    func leftPixelOverlap() -> CGFloat {
        return nominalPixelWidth()/2.0
    }

    func rightPixelOverlap() -> CGFloat {
        return nominalPixelWidth()/2.0
    }
    
    /// Some items grow/shrink based on time density which determines the data fetch overlaps. Assuming these have a start time and duration, only one direction is currently supported though the data source can always override this.
    func maxTimeExtension() -> NSTimeInterval {
        return 0.0
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
