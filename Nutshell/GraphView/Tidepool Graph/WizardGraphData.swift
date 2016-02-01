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


class WizardGraphDataType: GraphDataType {

    var bolusId: String?
    var recommendedNet: NSNumber?
    var bolusTopY: CGFloat?
    
    init(value: CGFloat, timeOffset: NSTimeInterval, bolusId: String?, recommendedNet: NSNumber?) {
        super.init(value: value, timeOffset: timeOffset)
        self.bolusId = bolusId
        self.recommendedNet = recommendedNet
    }
    
    override func typeString() -> String {
        return "wizard"
    }

}

class WizardGraphDataLayer: TidepoolGraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    let circleRadius: CGFloat = 9.0
    var lastCircleDrawn = CGRectNull
    var context: CGContext?
    
    // Bolus drawing will store rects here. E.g., Wizard circles are drawn just over associated Bolus labels.
    var bolusRects: [CGRect] = []
    
    private let kWizardCircleDiameter: CGFloat = 31.0

    //
    // MARK: - Loading data
    //

    override func nominalPixelWidth() -> CGFloat {
        return kWizardCircleDiameter
    }
    
    override func typeString() -> String {
        return "wizard"
    }
    
    override func loadEvent(event: CommonData, timeOffset: NSTimeInterval) {
        if let event = event as? Wizard {
            let value = event.carbInput ?? 0.0
            let floatValue = round(CGFloat(value))
            dataArray.append(WizardGraphDataType(value: floatValue, timeOffset: timeOffset, bolusId: event.bolus, recommendedNet: event.recommendedNet))
            
            // Let recommended bolus values figure into the bolus value scaling as well!
            if let recommended = event.recommendedNet {
                let recommendedValue = CGFloat(recommended)
                if recommendedValue > layout.maxBolus {
                    layout.maxBolus = recommendedValue
                }
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
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType) {
        
        if dataPoint.value == 0.0 {
            // Don't plot nil or zero values - probably used for recommended bolus record!
            //NSLog("Skip plot of wizard with zero value!")
            return
        }
        
        if let wizard = dataPoint as? WizardGraphDataType {
            let centerX = xOffset
            let circleDiameter = kWizardCircleDiameter
            let value = round(dataPoint.value)
            // Carb circle should be centered at timeline
            let offsetX = centerX - (circleDiameter/2)
            var wizardRect = CGRect(x: offsetX, y: layout.yBottomOfWizard - circleDiameter, width: circleDiameter, height: circleDiameter)
            var yAtBolusTop = bolusYAtPosition(wizardRect)
            if wizard.bolusTopY != nil {
                yAtBolusTop = wizard.bolusTopY
            }
            if let yAtBolusTop = yAtBolusTop {
                wizardRect.origin.y = yAtBolusTop - circleDiameter
            }
            let wizardOval = UIBezierPath(ovalInRect: wizardRect)
            Styles.goldColor.setFill()
            wizardOval.fill()
            // Draw background colored border to separate the circle from other objects
            layout.backgroundColor.setStroke()
            wizardOval.lineWidth = 0.5
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
    
    //
    // MARK: - Tidepool specific utility functions
    //
    
    func bolusYAtPosition(rect: CGRect) -> CGFloat? {
        var result: CGFloat?
        let rectLeft = rect.origin.x
        let rectRight = rectLeft + rect.width
        for bolusRect in bolusRects {
            let bolusLeftX = bolusRect.origin.x
            let bolusRightX = bolusLeftX + bolusRect.width
            if bolusRightX > rectLeft && bolusLeftX < rectRight {
                if bolusRect.height > result {
                    // return the bolusRect that is largest and intersects the x position of the target rect
                    result = bolusRect.height
                }
            }
        }
        return result
    }

}