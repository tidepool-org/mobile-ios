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

class TidepoolGraphDataLayer: GraphDataLayer {

    var layout: TidepoolGraphLayout

    init(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate, layout: TidepoolGraphLayout) {
        self.layout = layout
        super.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime)
    }


    //
    // MARK: - Loading data
    //
   
    /// Nominal width of an object. This is not used for drawing, but dealing with overlap of graphs constructed of multiple verical panes (collection cells).
    /// For example, a datapoint value shown as a circle of diameter 10 pixels (with the data value at the center) might have one pixel drawn on pane A, and the other nine on the following pane B. Since data is fetched by time, pane A needs to include data of this type whose center point is up to a radius past the end of A. If the circle had 9 points on pane A and 1 on pane B, pane B would need to include data whose center point is up to half a diameter before pane B.
    /// Override for correct width!
    func nominalPixelWidth() -> CGFloat {
        return 10.0
    }

    /// Optionally override instead of nominalPixelWidth() if a different start time is necessary
    func loadStartTime() -> NSDate {
        let timeExtensionForDataFetch = NSTimeInterval(nominalPixelWidth()/viewPixelsPerSec)
        return startTime.dateByAddingTimeInterval(-timeExtensionForDataFetch)
    }
    
    /// Optionally override instead of nominalPixelWidth() if a different end time is necessary
    func loadEndTime() -> NSDate {
        let endTime = startTime.dateByAddingTimeInterval(timeIntervalForView)
        let timeExtensionForDataFetch = NSTimeInterval(nominalPixelWidth()/viewPixelsPerSec)
        return endTime.dateByAddingTimeInterval(timeExtensionForDataFetch)
    }

    // Override!
    func typeString() -> String {
        return ""
    }

    // Override!
    func loadEvent(event: CommonData, timeOffset: NSTimeInterval) {
        
    }
    
    func loadComplete() {
        let itemsLoaded = dataArray.count
        //NSLog("loaded \(itemsLoaded) \(typeString()) events")
        if itemsLoaded > 0 {
            layout.dataDetected = true
        }
    }
    
    override func loadDataItems() {
        dataArray = []
        let earlyStartTime = loadStartTime()
        let lateEndTime = loadEndTime()
        // TODO: adjust for time zone offset of meal here?
        
        do {
            let events = try DatabaseUtils.getTidepoolEvents(earlyStartTime, thruTime: lateEndTime, objectTypes: [typeString()])
            for event in events {
                if let event = event as? CommonData {
                    if let eventTime = event.time {
                        let deltaTime = eventTime.timeIntervalSinceDate(startTime)
                        loadEvent(event, timeOffset: deltaTime)
                    }
                }
            }
        } catch let error as NSError {
            NSLog("Error: \(error)")
        }
        
        loadComplete()
    }

    //
    // MARK: - Drawing data points
    //

}