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
    var lastCircleDrawn = CGRect.null


    override func typeString() -> String {
        return "cbg"
    }

    fileprivate let kGlucoseConversionToMgDl: CGFloat = 18.0

    //
    // MARK: - Loading data
    //

    override func nominalPixelWidth() -> CGFloat {
        return circleRadius * 2
    }
    
    override func loadEvent(_ event: CommonData, timeOffset: TimeInterval) {
        if let cbgEvent = event as? ContinuousGlucose {
            //DDLogInfo("Adding Cbg event: \(event)")
            if let value = cbgEvent.value {
                let convertedValue = round(CGFloat(value) * kGlucoseConversionToMgDl)
                dataArray.append(CbgGraphDataType(value: convertedValue, timeOffset: timeOffset))
            } else {
                DDLogInfo("ignoring Cbg event with nil value")
            }
        }
    }

    //
    // MARK: - Drawing data points
    //

    override func configureForDrawing() {
        self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        lastCircleDrawn = CGRect.null
    }
    
    // override!
    override func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
        
        let centerX = xOffset
        var value = round(dataPoint.value)
        if value > layout.kGlucoseMaxValue {
            value = layout.kGlucoseMaxValue
        }
        // flip the Y to compensate for origin!
        let centerY: CGFloat = layout.yTopOfGlucose + layout.yPixelsGlucose - floor(value * pixelsPerValue)
        
        let circleColor = value < layout.lowBoundary ? layout.lowColor : value < layout.highBoundary ? layout.targetColor : layout.highColor
        let circleRect = CGRect(x: centerX-circleRadius, y: centerY-circleRadius, width: circleRadius*1.5, height: circleRadius*1.5)
        //let smallCircleRect = circleRect.insetBy(dx: 1.0, dy: 1.0)
        
//        if !lastCircleDrawn.intersects(circleRect) {
            let smallCirclePath = UIBezierPath(ovalIn: circleRect)
            circleColor.setFill()
            smallCirclePath.fill()
            // Draw border so circle stands out from other objects like meal lines
            //layout.backgroundColor.setStroke()
            //smallCirclePath.lineWidth = 1.5
            //smallCirclePath.stroke()
//        } else {
//            // Don't draw border when circles intersect as it creates a distracting pattern
//            let smallCirclePath = UIBezierPath(ovalIn: circleRect)
//            circleColor.setFill()
//            smallCirclePath.fill()
//        }
        
        lastCircleDrawn = circleRect
    }
}
