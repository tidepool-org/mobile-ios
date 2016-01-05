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

class BasalGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    var maxBasal: CGFloat = 0.0
    
    // locals...
    private var context: CGContext?
    private var startValue: CGFloat = 0.0
    private var startTimeOffset: NSTimeInterval = 0.0
    private var startValueSuppressed: CGFloat?

    override func configure() {
    }
    
    // override for any draw setup
    override func configureForDrawing() {
        context = UIGraphicsGetCurrentContext()
        if let layout = self.layout as? TidepoolGraphLayout {
            if maxBasal < layout.kBasalMinScaleValue {
                maxBasal = layout.kBasalMinScaleValue
            }
            self.pixelsPerValue = layout.yPixelsBasal / CGFloat(maxBasal)
        }
        startValue = 0.0
        startTimeOffset = 0.0
        startValueSuppressed = nil
   }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let layout = self.layout as? TidepoolGraphLayout {
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
    }
    
    override func finishDrawing() {
        // finish off any rect we started...
        if (startValue > 0.0) {
            if let layout = self.layout as? TidepoolGraphLayout {
                drawBasalRect(startTimeOffset, endTimeOffset: timeIntervalForView, value: startValue, suppressed: startValueSuppressed, layout: layout)
            }
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
        
        layout.bolusBlueRectColor.setStroke()
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
        layout.basalLightBlueRectColor.setFill()
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