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
import CocoaLumberjack

class BasalGraphDataType: GraphDataType {
    
    var suppressed: CGFloat?
    var duration: TimeInterval = 0.0
    
    init(value: CGFloat, timeOffset: TimeInterval, duration: TimeInterval, suppressed: CGFloat?) {
        self.suppressed = suppressed
        self.duration = duration
        super.init(value: value, timeOffset: timeOffset)
    }

    //(timeOffset: NSTimeInterval, value: NSNumber, suppressed: NSNumber?)
    override func typeString() -> String {
        return "basal"
    }

}

class BasalGraphDataLayer: TidepoolGraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
 
    // config...
    fileprivate let kBasalLightBlueRectColor = Styles.lightBlueColor
    fileprivate let kBasalMinScaleValue: CGFloat = 1.0
    fileprivate let kBasalDarkBlueRectColor = Styles.blueColor
    fileprivate let kBasalMaxDuration: TimeInterval = 12*60*60 // Assume maximum basal of 12 hours!

    // locals...
    fileprivate var context: CGContext?
    fileprivate var startValue: CGFloat = 0.0
    fileprivate var startTimeOffset: TimeInterval = 0.0
    fileprivate var startValueSuppressed: CGFloat?
    fileprivate var suppressedLine: UIBezierPath?
    
    //
    // MARK: - Loading data
    //

    // NOTE: the first BasalGraphDataLayer slice that has loadDataItems called loads the basal data for the entire graph time interval
    override func loadStartTime() -> Date {
        return layout.graphStartTime.addingTimeInterval(-kBasalMaxDuration) as Date
    }
    
    override func loadEndTime() -> Date {
        return layout.graphStartTime.addingTimeInterval(layout.graphTimeInterval)
    }

    override func typeString() -> String {
        return "basal"
    }
    
    override func loadEvent(_ event: CommonData, timeOffset: TimeInterval) {
        if let event = event as? Basal {
            let eventTime = event.time!
            let graphTimeOffset = eventTime.timeIntervalSince(layout.graphStartTime as Date)
            //DDLogInfo("Adding Basal event: \(event)")
            var value = event.value
            if value == nil {
                if let deliveryType = event.deliveryType {
                    if deliveryType == "suspend" {
                        value = NSNumber(value: 0.0 as Double)
                    }
                }
            }
            if value != nil {
                if event.duration != nil {
                    let duration = TimeInterval(CGFloat(truncating: event.duration!)/1000)
                    if duration > 0 {
                        let floatValue = CGFloat(truncating: value!)
                        var suppressed: CGFloat? = nil
                        if event.suppressedRate != nil {
                            suppressed = CGFloat(truncating: event.suppressedRate!)
                        }
                        dataArray.append(BasalGraphDataType(value: floatValue, timeOffset: graphTimeOffset, duration: duration, suppressed: suppressed))
                        if floatValue > layout.maxBasal {
                            layout.maxBasal = floatValue
                        }
                    } else {
                        // Note: a zero duration event may follow a suspended bolus, and might even have the same time stamp as another basal event with a different rate value! In general, durations should be very long.
                        DDLogInfo("ignoring Basal event with zero duration")
                    }
                } else {
                    // Note: sometimes suspend events have a nil duration - put in a zero valued record!
                    if event.deliveryType == "suspend" {
                        dataArray.append(BasalGraphDataType(value: 0.0, timeOffset: graphTimeOffset, duration: 0, suppressed: nil))
                    } else {
                        DDLogInfo("ignoring non-suspend Basal event with nil duration")
                    }
                }
            } else {
                DDLogInfo("ignoring Basal event with nil value")
            }
        }
    }

    override func loadDataItems() {
        // Note: since each graph tile needs to know the max basal value for the graph, the first tile to load loads data for the whole graph range...
        if layout.allBasalData == nil {
            dataArray = []
            super.loadDataItems()
            layout.allBasalData = dataArray
            if layout.maxBasal < kBasalMinScaleValue {
                layout.maxBasal = kBasalMinScaleValue
            }
            //DDLogInfo("Prefetched \(dataArray.count) basal items for graph")
        }
        
        dataArray = []
        let dataLayerOffset = startTime.timeIntervalSince(layout.graphStartTime as Date)
        func addItem(_ basalItem: BasalGraphDataType) {
            dataArray.append(BasalGraphDataType(value: basalItem.value, timeOffset: basalItem.timeOffset - dataLayerOffset, duration: basalItem.duration, suppressed: basalItem.suppressed))
        }
        
        // save end of last Basal as a possible graph item with zero value
        var previousBasal: BasalGraphDataType?
        func savePrevious(_ basalItem: BasalGraphDataType) {
            previousBasal = BasalGraphDataType(value: 0.0, timeOffset: basalItem.timeOffset + basalItem.duration, duration: 0, suppressed: nil)
        }

        let rangeStart = dataLayerOffset - kBasalMaxDuration
        let rangeEnd = dataLayerOffset + timeIntervalForView
        // copy over cached items in the range needed for this tile!
        for item in layout.allBasalData! {
            if let basalItem = item as? BasalGraphDataType {
                if basalItem.timeOffset >= rangeStart && basalItem.timeOffset <= rangeEnd {
                    if let previousItem = previousBasal {
                        if previousItem.timeOffset < basalItem.timeOffset {
                            // the previous basal ended before this one started, so add it in to complete that basal rect!
                            addItem(previousItem)
                        }
                    }
                    addItem(basalItem)
                    savePrevious(basalItem)
                }
            }
        }
        // handle case of last basal in slice with duration ending it before slice end - since no next item within slice will cause it to be emitted
        if let previousItem = previousBasal {
            if previousItem.timeOffset < rangeEnd {
                addItem(previousItem)
            }
        }
        //DDLogInfo("Copied \(dataArray.count) basal items from graph cache for slice at offset \(dataLayerOffset/3600) hours")

    }

    //
    // MARK: - Drawing data points
    //

    override func configureForDrawing() {
        context = UIGraphicsGetCurrentContext()
        self.pixelsPerValue = layout.yPixelsBasal / CGFloat(layout.maxBasal)
        startValue = 0.0
        startTimeOffset = 0.0
        startValueSuppressed = nil
        suppressedLine = nil
   }
    
    override func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
        
        if let basalPoint = dataPoint as? BasalGraphDataType {
            // skip over values before starting time, but remember last value...
            let itemTime = basalPoint.timeOffset
            let itemValue = basalPoint.value
            let itemSuppressed = basalPoint.suppressed

            //DDLogInfo("time: \(itemTime) val: \(itemValue) sup: \(itemSuppressed)")
            
            if itemTime < 0 {
                startValue = itemValue
                startValueSuppressed = itemSuppressed
            } else if startValue == 0.0 && startValueSuppressed == nil {
                if (itemValue > 0.0 || itemSuppressed != nil) {
                    // just starting a rect, note the time...
                    startTimeOffset = itemTime
                    startValue = itemValue
                    startValueSuppressed = itemSuppressed
                }
            } else {
                // got another value, draw the rect
                drawBasalRect(startTimeOffset, endTimeOffset: itemTime, value: startValue, suppressed: startValueSuppressed, layout: layout, finish: itemTime == timeIntervalForView)
                // and start another rect...
                startValue = itemValue
                startTimeOffset = itemTime
                startValueSuppressed = itemSuppressed
            }
        }
    }
    
    override func finishDrawing() {
        // finish off any rect/supressed line we started, to right edge of graph
        if (startValue > 0.0 || startValueSuppressed != nil) {
            drawBasalRect(startTimeOffset, endTimeOffset: timeIntervalForView, value: startValue, suppressed: startValueSuppressed, layout: layout, finish: true)
        }
    }
    
    fileprivate func drawSuppressedLine() {
        if let linePath = suppressedLine {
            kBasalDarkBlueRectColor.setStroke()
            linePath.lineWidth = 2.0
            linePath.lineCapStyle = .square // note this requires pattern change from 2, 2 to 2, 4!
            let pattern: [CGFloat] = [2.0, 4.0]
            linePath.setLineDash(pattern, count: 2, phase: 0.0)
            linePath.stroke()
            suppressedLine = nil
        }
    }
    
    fileprivate func drawBasalRect(_ startTimeOffset: TimeInterval, endTimeOffset: TimeInterval, value: CGFloat, suppressed: CGFloat?, layout: TidepoolGraphLayout, finish: Bool) {
        let rectLeft = floor(CGFloat(startTimeOffset) * viewPixelsPerSec)
        let rectRight = ceil(CGFloat(endTimeOffset) * viewPixelsPerSec)
        let rectWidth = rectRight-rectLeft
        //DDLogInfo("  len: \(rectWidth) bas: \(value), sup: \(suppressed)")
        let rectHeight = floor(pixelsPerValue * value)
        let basalRect = CGRect(x: rectLeft, y: layout.yBottomOfBasal - rectHeight, width: rectWidth, height: rectHeight)
        let basalValueRectPath = UIBezierPath(rect: basalRect)
        kBasalLightBlueRectColor.setFill()
        basalValueRectPath.fill()
        
        if let suppressed = suppressed {
            var suppressedStart = CGPoint(x: basalRect.origin.x + 1.0, y:layout.yBottomOfBasal - floor(pixelsPerValue * suppressed) + 1.0) // add 1.0 so suppressed line top is same as basal top
            let suppressedEnd = CGPoint(x: suppressedStart.x + basalRect.size.width - 2.0, y: suppressedStart.y)
            if suppressedLine == nil {
                // start a new line path
                suppressedLine = UIBezierPath()
                suppressedLine!.move(to: suppressedStart)
                //DDLogInfo("suppressed move to \(suppressedStart)")
            } else {
                // continue an existing suppressed line path by adding connecting line if it's at a different y
                let currentEnd = suppressedLine!.currentPoint
                if abs(currentEnd.y - suppressedStart.y) > 1.0 {
                    suppressedLine!.addLine(to: suppressedStart)
                    //DDLogInfo("suppressed line to \(suppressedStart)")
                }
                suppressedStart.y = currentEnd.y
            }
            // add current line segment
            suppressedLine!.addLine(to: suppressedEnd)
            //DDLogInfo("suppressed line to \(suppressedEnd)")
            if finish {
                drawSuppressedLine()
                //DDLogInfo("suppressed line draw at finish!")
            }
        } else if suppressedLine != nil {
            drawSuppressedLine()
            //DDLogInfo("suppressed line draw!")
        }
    }
}
