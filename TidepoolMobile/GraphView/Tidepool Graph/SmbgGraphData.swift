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

class SmbgGraphDataType: GraphDataType {
    
    override func typeString() -> String {
        return "smbg"
    }
}

class SmbgGraphDataLayer: TidepoolGraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    let circleRadius: CGFloat = 9.0
    var lastCircleDrawn = CGRect.null
    var context: CGContext?

    override func typeString() -> String {
        return "smbg"
    }

    fileprivate let kGlucoseConversionToMgDl: CGFloat = 18.0

    //
    // MARK: - Loading data
    //

    override func nominalPixelWidth() -> CGFloat {
        return circleRadius * 2
    }
    
    override func loadEvent(_ event: CommonData, timeOffset: TimeInterval) {
        if let smbgEvent = event as? SelfMonitoringGlucose {
            //DDLogInfo("Adding smbg event: \(event)")
            if let value = smbgEvent.value {
                let convertedValue = round(CGFloat(truncating: value) * kGlucoseConversionToMgDl)
                dataArray.append(CbgGraphDataType(value: convertedValue, timeOffset: timeOffset))
            } else {
                DDLogInfo("ignoring smbg event with nil value")
            }
        }
    }

    //
    // MARK: - Drawing data points
    //

    // override for any draw setup
    override func configureForDrawing() {
        self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        context = UIGraphicsGetCurrentContext()
   }
    
    // override!
    override func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
        
        let centerX = xOffset
        var value = round(dataPoint.value)
        let valueForLabel = value
        if value > layout.kGlucoseMaxValue {
            value = layout.kGlucoseMaxValue
        }
        // flip the Y to compensate for origin!
        let centerY: CGFloat = layout.yTopOfGlucose + layout.yPixelsGlucose - floor(value * pixelsPerValue)
        
        let circleColor = value < layout.lowBoundary ? layout.lowColor : value < layout.highBoundary ? layout.targetColor : layout.highColor

        let largeCirclePath = UIBezierPath(ovalIn: CGRect(x: centerX-circleRadius, y: centerY-circleRadius, width: circleRadius*2, height: circleRadius*2))
        circleColor.setFill()
        largeCirclePath.fill()
        layout.backgroundColor.setStroke()
        largeCirclePath.lineWidth = 1.5
        largeCirclePath.stroke()
        
        let intValue = Int(valueForLabel)
        let readingLabelTextContent = String(intValue)
        let readingLabelStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        readingLabelStyle.alignment = .center
        let readingLabelFontAttributes = [NSAttributedStringKey.font: Styles.smallSemiboldFont, NSAttributedStringKey.foregroundColor: circleColor, NSAttributedStringKey.paragraphStyle: readingLabelStyle]
        var readingLabelTextSize = readingLabelTextContent.boundingRect(with: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: readingLabelFontAttributes, context: nil).size
        readingLabelTextSize = CGSize(width: ceil(readingLabelTextSize.width), height: ceil(readingLabelTextSize.height))
        let readingLabelRect = CGRect(x: centerX-(readingLabelTextSize.width/2), y: centerY+circleRadius, width: readingLabelTextSize.width, height: readingLabelTextSize.height)
        
        let readingLabelPath = UIBezierPath(rect: readingLabelRect.insetBy(dx: 1.0, dy: 2.5))
        layout.backgroundColor.setFill()
        readingLabelPath.fill()
        
        context!.saveGState()
        context!.clip(to: readingLabelRect);
        readingLabelTextContent.draw(in: readingLabelRect, withAttributes: readingLabelFontAttributes)
        context!.restoreGState()
    }
}
