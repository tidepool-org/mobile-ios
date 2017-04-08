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
    var duration: TimeInterval = 0.0
    var id: String?
    var rectInGraph: CGRect = CGRect.zero
    
    init(timeOffset: TimeInterval, isMain: Bool, duration: TimeInterval, event: Workout) {
        self.isMainEvent = isMain
        self.duration = duration
        // id needed if user taps on this item...
        if let eventId = event.id as? String {
            self.id = eventId
        } else {
            // historically may be nil...
            self.id = nil
        }
        super.init(timeOffset: timeOffset)
    }
    
    override func typeString() -> String {
        return "workout"
    }

}

class WorkoutGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
 
    fileprivate var layout: TidepoolGraphLayout
    
    init(viewSize: CGSize, timeIntervalForView: TimeInterval, startTime: Date, layout: TidepoolGraphLayout) {
        self.layout = layout
        super.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime)
    }

    // Assume maximum workout length of 3 hours for prefetch!
    fileprivate let maxWorkoutDuration: TimeInterval = 3*60*60
    fileprivate let minPixelWidth: CGFloat = 2.0

    //
    // MARK: - Loading data
    //

    override func loadDataItems() {
        dataArray = []
        let endTime = startTime.addingTimeInterval(timeIntervalForView)
        let timeExtensionForDataFetch = TimeInterval(minPixelWidth/viewPixelsPerSec)
        let earlyStartTime = startTime.addingTimeInterval(-maxWorkoutDuration)
        let lateEndTime = endTime.addingTimeInterval(timeExtensionForDataFetch)
        do {
            let events = try DatabaseUtils.sharedInstance.getWorkoutEvents(earlyStartTime, toTime: lateEndTime)
            for workoutEvent in events {
                if let eventTime = workoutEvent.time {
                    let deltaTime = eventTime.timeIntervalSince(startTime)
                    var isMainEvent = false
                    isMainEvent = workoutEvent.time == layout.mainEventTime
                    if let duration = workoutEvent.duration {
                        dataArray.append(WorkoutGraphDataType(timeOffset: deltaTime, isMain: isMainEvent, duration: TimeInterval(duration), event: workoutEvent))
                    } else {
                        NSLog("ignoring Workout event with nil duration")
                    }
                }
            }
        } catch let error as NSError {
            NSLog("Error: \(error)")
        }
        if dataArray.count > 0 {
            //NSLog("loaded \(dataArray.count) workout events")
        }
    }

    //
    // MARK: - Drawing data points
    //

    // override for draw setup
    override func configureForDrawing() {
        self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
    }
    
    override func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
        
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
            
            if !isMain {
                workoutDataType.rectInGraph = workoutRect
            }
        }
    }
    
    // override to handle taps - return true if tap has been handled
    override func tappedAtPoint(_ point: CGPoint) -> GraphDataType? {
        for dataPoint in dataArray {
            if let workoutDataPoint = dataPoint as? WorkoutGraphDataType {
                if workoutDataPoint.rectInGraph.contains(point) {
                    return workoutDataPoint
                }
            }
        }
        return nil
    }

}
