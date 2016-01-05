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
class BolusGraphDataType: GraphDataType {
    
    var hasExtension: Bool = false
    var extendedValue: CGFloat = 0.0
    var duration: NSTimeInterval = 0.0
    
    convenience init(event: Bolus, deltaTime: NSTimeInterval) {
        let value = CGFloat(event.value!)
        self.init(value: value, timeOffset: deltaTime)
        let extendedBolus = event.extended
        let duration = event.duration
        if let extendedBolus = extendedBolus, duration = duration {
            self.hasExtension = true
            self.extendedValue = CGFloat(extendedBolus)
            let durationInMS = Int(duration)
            self.duration = NSTimeInterval(durationInMS / 1000)
        }
    }

    //(timeOffset: NSTimeInterval, value: NSNumber, suppressed: NSNumber?)
    override func typeString() -> String {
        return "bolus"
    }
}

class BolusGraphDataLayer: GraphDataLayer {
    
    // vars for drawing datapoints of this type
    var pixelsPerValue: CGFloat = 0.0
    var maxBolus: CGFloat = 0.0
    
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
            if maxBolus < layout.kBolusMinScaleValue {
                maxBolus = layout.kBolusMinScaleValue
            }
            self.pixelsPerValue = layout.yPixelsBolus / CGFloat(maxBolus)
        }
        startValue = 0.0
        startTimeOffset = 0.0
        startValueSuppressed = nil
   }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let layout = self.layout as? TidepoolGraphLayout {
            if let bolus = dataPoint as? BolusGraphDataType {
                // Bolus rect is center-aligned to time start
                let centerX = xOffset
                var bolusValue = bolus.value
                if bolusValue > maxBolus && bolusValue > layout.kBolusMinScaleValue {
                    NSLog("ERR: max bolus exceeded!")
                    bolusValue = maxBolus
                }
                let rectLeft = floor(centerX - (layout.kBolusRectWidth/2))
                let bolusRectHeight = ceil(pixelsPerValue * bolusValue)
                let bolusValueRect = CGRect(x: rectLeft, y: layout.yBottomOfBolus - bolusRectHeight, width: layout.kBolusRectWidth, height: bolusRectHeight)
                let bolusValueRectPath = UIBezierPath(rect: bolusValueRect)
                layout.bolusBlueRectColor.setFill()
                bolusValueRectPath.fill()
                
                let bolusFloatValue = Float(bolus.value)
                var bolusLabelTextContent = String(format: "%.2f", bolusFloatValue)
                if bolusLabelTextContent.hasSuffix("0") {
                    bolusLabelTextContent = String(format: "%.1f", bolusFloatValue)
                }
                let bolusLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
                bolusLabelStyle.alignment = .Center
                let bolusLabelFontAttributes = [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: layout.bolusTextBlue, NSParagraphStyleAttributeName: bolusLabelStyle]
                var bolusLabelTextSize = bolusLabelTextContent.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: bolusLabelFontAttributes, context: nil).size
                bolusLabelTextSize = CGSize(width: ceil(bolusLabelTextSize.width), height: ceil(bolusLabelTextSize.height))
                let bolusLabelRect = CGRect(x:centerX-(bolusLabelTextSize.width/2), y:layout.yBottomOfBolus - bolusRectHeight - layout.kBolusLabelToRectGap - bolusLabelTextSize.height, width: bolusLabelTextSize.width, height: bolusLabelTextSize.height)
                
                let bolusLabelPath = UIBezierPath(rect: bolusLabelRect.insetBy(dx: 0.0, dy: 2.0))
                layout.backgroundColor.setFill()
                bolusLabelPath.fill()
                
                CGContextSaveGState(context)
                CGContextClipToRect(context, bolusLabelRect);
                bolusLabelTextContent.drawInRect(bolusLabelRect, withAttributes: bolusLabelFontAttributes)
                CGContextRestoreGState(context)
                
                if bolus.hasExtension {
                    let width = floor(CGFloat(bolus.duration) * viewPixelsPerSec)
                    // Note: bolus.value is comprised of the initial bolus value plus the extended value, and hasExtension is false if the extended value is zero, so there should be no divide by zero issues even with "bad" data
                    let height = bolus.extendedValue * pixelsPerValue
                    drawBolusExtension(bolusValueRect.origin.x + bolusValueRect.width, centerY: layout.yBottomOfBolus - height, width: width, layout: layout)
                    NSLog("bolus extension duration \(bolus.duration/60) minutes, extended value \(bolus.extendedValue), total value: \(bolus.value)")
                }
                
                layout.bolusRects.append(bolusLabelRect.union(bolusValueRect))
            }
        }
    }
    
    private func drawBolusExtension(var originX: CGFloat, centerY: CGFloat, var width: CGFloat, layout: TidepoolGraphLayout) {
        if width < layout.kExtensionEndshapeWidth {
            // If extension is shorter than the end trapezoid shape, only draw that shape, backing it into the bolus rect
            originX = originX - (layout.kExtensionEndshapeWidth - width)
            width = layout.kExtensionEndshapeWidth
        }
        let originY = centerY - (layout.kExtensionEndshapeHeight/2.0)
        let bottomLineY = centerY + (layout.kExtensionLineHeight / 2.0)
        let topLineY = centerY - (layout.kExtensionLineHeight / 2.0)
        let rightSideX = originX + width
        
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(rightSideX, originY))
        bezierPath.addLineToPoint(CGPointMake(rightSideX, originY + layout.kExtensionEndshapeHeight))
        bezierPath.addLineToPoint(CGPointMake(rightSideX - layout.kExtensionEndshapeWidth, bottomLineY))
        bezierPath.addLineToPoint(CGPointMake(originX, bottomLineY))
        bezierPath.addLineToPoint(CGPointMake(originX, topLineY))
        bezierPath.addLineToPoint(CGPointMake(rightSideX - layout.kExtensionEndshapeWidth, topLineY))
        bezierPath.addLineToPoint(CGPointMake(rightSideX, originY))
        bezierPath.closePath()
        layout.bolusBlueRectColor.setFill()
        bezierPath.fill()
    }

}