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

}

class WorkoutGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
 
    private var layout: TidepoolGraphLayout
    
    init(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate, layout: TidepoolGraphLayout) {
        self.layout = layout
        super.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime)
    }

    // Assume maximum workout length of 3 hours for prefetch!
    private let maxWorkoutDuration: NSTimeInterval = 3*60*60
    private let minPixelWidth: CGFloat = 2.0

    //
    // MARK: - Loading data
    //

    override func loadDataItems() {
        dataArray = []
        let endTime = startTime.dateByAddingTimeInterval(timeIntervalForView)
        let timeExtensionForDataFetch = NSTimeInterval(minPixelWidth/viewPixelsPerSec)
        let earlyStartTime = startTime.dateByAddingTimeInterval(-maxWorkoutDuration)
        let lateEndTime = endTime.dateByAddingTimeInterval(timeExtensionForDataFetch)
        do {
            let events = try DatabaseUtils.getWorkoutEvents(earlyStartTime, toTime: lateEndTime)
            for workoutEvent in events {
                if let eventTime = workoutEvent.time {
                    let deltaTime = eventTime.timeIntervalSinceDate(startTime)
                    var isMainEvent = false
                    isMainEvent = workoutEvent.time == layout.mainEventTime
                    if let duration = workoutEvent.duration {
                        dataArray.append(WorkoutGraphDataType(timeOffset: deltaTime, isMain: isMainEvent, duration: NSTimeInterval(duration)))
                    } else {
                        NSLog("ignoring Workout event with nil duration")
                    }
                }
            }
        } catch let error as NSError {
            NSLog("Error: \(error)")
        }
        if dataArray.count > 0 {
            NSLog("loaded \(dataArray.count) workout events")
        }
    }

    //
    // MARK: - Drawing data points
    //

    // override for draw setup
    override func configureForDrawing() {
        self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
    }
    
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
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