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
class MealGraphDataType: GraphDataType {
    
    var isMainEvent: Bool = false
    
    convenience init(timeOffset: NSTimeInterval, isMain: Bool) {
        self.init(timeOffset: timeOffset)
        isMainEvent = isMain
    }
    
    override func typeString() -> String {
        return "meal"
    }
}

class MealGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    
    // override for any draw setup
    override func configureForDrawing() {
        if let layout = self.layout as? TidepoolGraphLayout {
            self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        }
    }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let layout = self.layout as? TidepoolGraphLayout {
            var isMain = false
            if let mealDataType = dataPoint as? MealGraphDataType {
                isMain = mealDataType.isMainEvent
            }

            // eventLine Drawing
            let lineColor = isMain ? layout.mealLineColor : layout.otherMealColor
            let triangleColor = isMain ? layout.mealTriangleColor : layout.otherMealColor
            let lineHeight: CGFloat = isMain ? viewSize.height : layout.headerHeight
            let lineWidth: CGFloat = isMain ? 2.0 : 1.0
            
            let rect = CGRect(x: xOffset, y: 0.0, width: lineWidth, height: lineHeight)
            let eventLinePath = UIBezierPath(rect: rect)
            lineColor.setFill()
            eventLinePath.fill()
            
            let trianglePath = UIBezierPath()
            let centerX = rect.origin.x + lineWidth/2.0
            let triangleSize: CGFloat = 15.5
            let triangleOrgX = centerX - triangleSize/2.0
            trianglePath.moveToPoint(CGPointMake(triangleOrgX, 0.0))
            trianglePath.addLineToPoint(CGPointMake(triangleOrgX + triangleSize, 0.0))
            trianglePath.addLineToPoint(CGPointMake(triangleOrgX + triangleSize/2.0, 13.5))
            trianglePath.addLineToPoint(CGPointMake(triangleOrgX, 0))
            trianglePath.closePath()
            trianglePath.miterLimit = 4;
            trianglePath.usesEvenOddFillRule = true;
            triangleColor.setFill()
            trianglePath.fill()
        }
    }
}