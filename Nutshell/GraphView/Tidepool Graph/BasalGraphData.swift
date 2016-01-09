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
class BasalGraphDataType: GraphDataType {
    
    var suppressed: CGFloat?
    
    convenience init(value: CGFloat, timeOffset: NSTimeInterval, suppressed: CGFloat?) {
        self.init(value: value, timeOffset: timeOffset)
        self.suppressed = suppressed
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
    private let kBasalLightBlueRectColor = Styles.lightBlueColor
    private let kBasalMinScaleValue: CGFloat = 1.0
    private let kBasalDarkBlueRectColor = Styles.blueColor
    private let kBasalMaxDuration: NSTimeInterval = 12*60*60 // Assume maximum basal of 12 hours!

    // locals...
    private var context: CGContext?
    private var startValue: CGFloat = 0.0
    private var startTimeOffset: NSTimeInterval = 0.0
    private var startValueSuppressed: CGFloat?

    // NOTE: the first BasalGraphDataLayer slice that has loadDataItems called loads the basal data for the entire graph time interval
    override func loadStartTime() -> NSDate {
        return layout.graphStartTime.dateByAddingTimeInterval(-kBasalMaxDuration)
    }
    
    override func loadEndTime() -> NSDate {
        return layout.graphStartTime.dateByAddingTimeInterval(layout.graphTimeInterval)
    }

    override func typeString() -> String {
        return "basal"
    }
    
    override func loadEvent(event: CommonData, timeOffset: NSTimeInterval) {
        if let event = event as? Basal {
            let eventTime = event.time!
            let graphTimeOffset = eventTime.timeIntervalSinceDate(layout.graphStartTime)
            //NSLog("Adding Basal event: \(event)")
            var value = event.value
            if value == nil {
                if let deliveryType = event.deliveryType {
                    if deliveryType == "suspend" {
                        value = NSNumber(double: 0.0)
                    }
                }
            }
            if value != nil {
                let floatValue = CGFloat(value!)
                var suppressed: CGFloat? = nil
                if event.percent != nil {
                    suppressed = CGFloat(event.percent!)
                }
                dataArray.append(BasalGraphDataType(value: floatValue, timeOffset: graphTimeOffset, suppressed: suppressed))
                if floatValue > layout.maxBasal {
                    layout.maxBasal = floatValue
                }
            } else {
                NSLog("ignoring Basal event with nil value")
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
            NSLog("Prefetched \(dataArray.count) basal items for graph")
        }
        
        dataArray = []
        let dataLayerOffset = startTime.timeIntervalSinceDate(layout.graphStartTime)
        let rangeStart = dataLayerOffset - kBasalMaxDuration
        let rangeEnd = dataLayerOffset + timeIntervalForView
        // copy over cached items in the range needed for this tile!
        for item in layout.allBasalData! {
            if let basalItem = item as? BasalGraphDataType {
                if basalItem.timeOffset >= rangeStart && basalItem.timeOffset <= rangeEnd {
                    dataArray.append(BasalGraphDataType(value: basalItem.value, timeOffset: basalItem.timeOffset - dataLayerOffset, suppressed: basalItem.suppressed))
                }
            }
        }
        NSLog("Copied \(dataArray.count) basal items from graph cache for slice at offset \(dataLayerOffset/3600) hours")

    }

    // override for any draw setup
    override func configureForDrawing() {
        context = UIGraphicsGetCurrentContext()
        self.pixelsPerValue = layout.yPixelsBasal / CGFloat(layout.maxBasal)
        startValue = 0.0
        startTimeOffset = 0.0
        startValueSuppressed = nil
   }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let basalPoint = dataPoint as? BasalGraphDataType {
            // skip over values before starting time, but remember last value...
            let itemTime = basalPoint.timeOffset
            let itemValue = basalPoint.value
            let itemSuppressed = basalPoint.suppressed

            if itemTime < 0 {
                startValue = itemValue
                startValueSuppressed = basalPoint.suppressed
            } else if startValue == 0.0 {
                if (itemValue > 0.0) {
                    // just starting a rect, note the time...
                    startTimeOffset = itemTime
                    startValue = itemValue
                    startValueSuppressed = itemSuppressed
                }
            } else {
                // got another value, draw the rect
                drawBasalRect(startTimeOffset, endTimeOffset: itemTime, value: startValue, suppressed: startValueSuppressed, layout: layout)
                // and start another rect...
                startValue = itemValue
                startTimeOffset = itemTime
                startValueSuppressed = itemSuppressed
            }
        }
    }
    
    override func finishDrawing() {
        // finish off any rect we started...
        if (startValue > 0.0) {
            drawBasalRect(startTimeOffset, endTimeOffset: timeIntervalForView, value: startValue, suppressed: startValueSuppressed, layout: layout)
        }
    }
    
    private func drawSuppressedLine(rect: CGRect, layout: TidepoolGraphLayout) {
        let lineHeight: CGFloat = 2.0
        let context = UIGraphicsGetCurrentContext()
        let linePath = UIBezierPath()
        linePath.moveToPoint(CGPoint(x: rect.origin.x, y: rect.origin.y))
        linePath.addLineToPoint(CGPoint(x: (rect.origin.x + rect.size.width), y: rect.origin.y))
        linePath.miterLimit = 4;
        linePath.lineCapStyle = .Square;
        linePath.lineJoinStyle = .Round;
        linePath.usesEvenOddFillRule = true;
        
        kBasalDarkBlueRectColor.setStroke()
        linePath.lineWidth = lineHeight
        CGContextSaveGState(context)
        CGContextSetLineDash(context, 0, [2, 5], 2)
        linePath.stroke()
        CGContextRestoreGState(context)
    }
    
    private func drawBasalRect(startTimeOffset: NSTimeInterval, endTimeOffset: NSTimeInterval, value: CGFloat, suppressed: CGFloat?, layout: TidepoolGraphLayout) {
        
        let rectLeft = floor(CGFloat(startTimeOffset) * viewPixelsPerSec)
        let rectRight = ceil(CGFloat(endTimeOffset) * viewPixelsPerSec)
        let rectHeight = floor(pixelsPerValue * value)
        var basalRect = CGRect(x: rectLeft, y: layout.yBottomOfBasal - rectHeight, width: rectRight - rectLeft, height: rectHeight)
        
        let basalValueRectPath = UIBezierPath(rect: basalRect)
        kBasalLightBlueRectColor.setFill()
        basalValueRectPath.fill()
        
        if let suppressed = suppressed {
            if suppressed != 0 {
                let lineHeight = floor(pixelsPerValue * suppressed)
                // reuse basalRect, it just needs y adjust, height not used
                basalRect.origin.y = layout.yBottomOfBasal - lineHeight
                drawSuppressedLine(basalRect, layout: layout)
            }
        }
    }

}