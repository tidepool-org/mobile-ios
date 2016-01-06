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

/// Continuous Blood Glucose readings vary between sub-100 to over 340 (we clip them there).
/// CbgGraphDataType is a single-value type, so no additional data is needed.
class WorkoutGraphDataType: GraphDataType {
    
    var isMainEvent: Bool = false
    var duration: NSTimeInterval = 0.0
    
    convenience init(timeOffset: NSTimeInterval, isMain: Bool, duration: NSTimeInterval) {
        self.init(timeOffset: timeOffset)
        self.isMainEvent = isMain
        self.duration = duration
    }
    
    override func typeString() -> String {
        return "workout"
    }

    override func maxTimeExtension() -> NSTimeInterval {
        return 3*60*60  // Assume maximum workout length of 3 hours!
    }
}

class WorkoutGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    
    // override for any draw setup
    override func configureForDrawing() {
        if let layout = self.layout as? TidepoolGraphLayout {
            self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        }
    }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let layout = self.layout as? TidepoolGraphLayout {
            var isMain = false
            if let workoutDataType = dataPoint as? WorkoutGraphDataType {
                isMain = workoutDataType.isMainEvent
            
                let workoutDuration = workoutDataType.duration
                let lineWidth: CGFloat = isMain ? 2.0 : 1.0
                
                //// eventLine Drawing
                let centerX = xOffset
                let eventLinePath = UIBezierPath(rect: CGRect(x: centerX, y: layout.yTopOfWorkout, width: lineWidth, height: layout.yBottomOfWorkout - layout.yTopOfWorkout))
                Styles.pinkColor.setFill()
                eventLinePath.fill()
                
                //// eventRectangle Drawing
                let workoutRectWidth = floor(CGFloat(workoutDuration) * viewPixelsPerSec)
                let workoutRect = CGRect(x: centerX /*- (workoutRectWidth/2)*/, y:layout.yTopOfWorkout, width: workoutRectWidth, height: layout.yPixelsWorkout)
                let eventRectanglePath = UIBezierPath(rect: workoutRect)
                Styles.pinkColor.setFill()
                eventRectanglePath.fill()
            }

        }
    }
}