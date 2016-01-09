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
class SmbgGraphDataType: GraphDataType {
    
    override func typeString() -> String {
        return "smbg"
    }
}

class SmbgGraphDataLayer: TidepoolGraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    let circleRadius: CGFloat = 9.0
    var lastCircleDrawn = CGRectNull
    var context: CGContext?
    
    override func nominalPixelWidth() -> CGFloat {
        return circleRadius * 2
    }
    
    override func typeString() -> String {
        return "smbg"
    }
    
    private let kGlucoseConversionToMgDl: CGFloat = 18.0
    override func loadEvent(event: CommonData, timeOffset: NSTimeInterval) {
        if let smbgEvent = event as? SelfMonitoringGlucose {
            //NSLog("Adding smbg event: \(event)")
            if let value = smbgEvent.value {
                let convertedValue = round(CGFloat(value) * kGlucoseConversionToMgDl)
                dataArray.append(CbgGraphDataType(value: convertedValue, timeOffset: timeOffset))
            } else {
                NSLog("ignoring smbg event with nil value")
            }
        }
    }
    
    // override for any draw setup
    override func configureForDrawing() {
        self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        context = UIGraphicsGetCurrentContext()
   }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        let centerX = xOffset
        var value = round(dataPoint.value)
        let valueForLabel = value
        if value > layout.kGlucoseMaxValue {
            value = layout.kGlucoseMaxValue
        }
        // flip the Y to compensate for origin!
        let centerY: CGFloat = layout.yTopOfGlucose + layout.yPixelsGlucose - floor(value * pixelsPerValue)
        
        let circleColor = value < layout.lowBoundary ? layout.lowColor : value < layout.highBoundary ? layout.targetColor : layout.highColor

        let largeCirclePath = UIBezierPath(ovalInRect: CGRectMake(centerX-circleRadius, centerY-circleRadius, circleRadius*2, circleRadius*2))
        circleColor.setFill()
        largeCirclePath.fill()
        layout.backgroundColor.setStroke()
        largeCirclePath.lineWidth = 1.5
        largeCirclePath.stroke()
        
        let intValue = Int(valueForLabel)
        let readingLabelTextContent = String(intValue)
        let readingLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        readingLabelStyle.alignment = .Center
        let readingLabelFontAttributes = [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: circleColor, NSParagraphStyleAttributeName: readingLabelStyle]
        var readingLabelTextSize = readingLabelTextContent.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: readingLabelFontAttributes, context: nil).size
        readingLabelTextSize = CGSize(width: ceil(readingLabelTextSize.width), height: ceil(readingLabelTextSize.height))
        let readingLabelRect = CGRectMake(centerX-(readingLabelTextSize.width/2), centerY+circleRadius, readingLabelTextSize.width, readingLabelTextSize.height)
        
        let readingLabelPath = UIBezierPath(rect: readingLabelRect.insetBy(dx: 1.0, dy: 2.5))
        layout.backgroundColor.setFill()
        readingLabelPath.fill()
        
        CGContextSaveGState(context)
        CGContextClipToRect(context, readingLabelRect);
        readingLabelTextContent.drawInRect(readingLabelRect, withAttributes: readingLabelFontAttributes)
        CGContextRestoreGState(context)
    }
}