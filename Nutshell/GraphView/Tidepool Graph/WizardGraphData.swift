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
class WizardGraphDataType: GraphDataType {
    
    override func typeString() -> String {
        return "wizard"
    }
}

class WizardGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    let circleRadius: CGFloat = 9.0
    var lastCircleDrawn = CGRectNull
    var context: CGContext?
    
    override func configure() {
    }
    
    // override for any draw setup
    override func configureForDrawing() {
        if let layout = self.layout as? TidepoolGraphLayout {
            self.pixelsPerValue = layout.yPixelsGlucose/layout.kGlucoseRange
        }
        context = UIGraphicsGetCurrentContext()
   }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let layout = self.layout as? TidepoolGraphLayout {
            let centerX = xOffset
            let circleDiameter = layout.kWizardCircleDiameter
            let value = round(dataPoint.value)
            // Carb circle should be centered at timeline
            let offsetX = centerX - (circleDiameter/2)
            var wizardRect = CGRect(x: offsetX, y: layout.yBottomOfWizard - circleDiameter, width: circleDiameter, height: circleDiameter)
            let bolusRect = layout.bolusRectAtPosition(wizardRect)
            if bolusRect.height != 0.0 {
                wizardRect.origin.y = bolusRect.origin.y - circleDiameter
            }
            let wizardOval = UIBezierPath(ovalInRect: wizardRect)
            Styles.goldColor.setFill()
            wizardOval.fill()
            // Draw background colored border to separate the circle from other objects
            layout.backgroundColor.setStroke()
            wizardOval.lineWidth = 1.5
            wizardOval.stroke()
            
            // Label Drawing
            let labelRect = wizardRect
            let labelText = String(Int(value))
            let labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            labelStyle.alignment = .Center
            
            let labelAttrStr = NSMutableAttributedString(string: labelText, attributes: [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: Styles.darkPurpleColor, NSParagraphStyleAttributeName: labelStyle])
            
            let labelTextHeight: CGFloat = ceil(labelAttrStr.boundingRectWithSize(CGSizeMake(labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil).size.height)
            
            CGContextSaveGState(context)
            CGContextClipToRect(context, labelRect);
            labelAttrStr.drawInRect(CGRectMake(labelRect.minX, labelRect.minY + (labelRect.height - labelTextHeight) / 2, labelRect.width, labelTextHeight))
            CGContextRestoreGState(context)
        }
    }
}