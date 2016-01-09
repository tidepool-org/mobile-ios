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
class CbgGraphDataType: GraphDataType {
    
    override func typeString() -> String {
        return "cbg"
    }
}

class CbgGraphDataLayer: TidepoolGraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    let circleRadius: CGFloat = 3.5
    var lastCircleDrawn = CGRectNull

    override func nominalPixelWidth() -> CGFloat {
        return circleRadius * 2
    }

    override func typeString() -> String {
        return "cbg"
    }

    private let kGlucoseConversionToMgDl: CGFloat = 18.0
    override func loadEvent(event: CommonData, timeOffset: NSTimeInterval) {
        if let cbgEvent = event as? ContinuousGlucose {
            //NSLog("Adding Cbg event: \(event)")
            if let value = cbgEvent.value {
                let convertedValue = round(CGFloat(value) * kGlucoseConversionToMgDl)
                dataArray.append(CbgGraphDataType(value: convertedValue, timeOffset: timeOffset))
            } else {
                NSLog("ignoring Cbg event with nil value")
            }
        }
    }

    // override for any draw setup
    override func configureForDrawing() {
        self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        lastCircleDrawn = CGRectNull
    }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        let centerX = xOffset
        var value = round(dataPoint.value)
        if value > layout.kGlucoseMaxValue {
            value = layout.kGlucoseMaxValue
        }
        // flip the Y to compensate for origin!
        let centerY: CGFloat = layout.yTopOfGlucose + layout.yPixelsGlucose - floor(value * pixelsPerValue)
        
        let circleColor = value < layout.lowBoundary ? layout.lowColor : value < layout.highBoundary ? layout.targetColor : layout.highColor
        let circleRect = CGRectMake(centerX-circleRadius, centerY-circleRadius, circleRadius*2, circleRadius*2)
        let smallCircleRect = circleRect.insetBy(dx: 1.0, dy: 1.0)
        
        if !lastCircleDrawn.intersects(circleRect) {
            let smallCirclePath = UIBezierPath(ovalInRect: circleRect)
            circleColor.setFill()
            smallCirclePath.fill()
            layout.backgroundColor.setStroke()
            smallCirclePath.lineWidth = 1.5
            smallCirclePath.stroke()
        } else {
            let smallCirclePath = UIBezierPath(ovalInRect: smallCircleRect)
            circleColor.setFill()
            smallCirclePath.fill()
        }
        
        lastCircleDrawn = circleRect
    }
}