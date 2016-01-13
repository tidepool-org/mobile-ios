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

class BolusGraphDataType: GraphDataType {
    
    var extendedValue: CGFloat?
    var duration: NSTimeInterval?
    var expectedNormal: CGFloat?
    var expectedExtended: CGFloat?
    var expectedDuration: NSTimeInterval?
    var id: String
    
    init(event: Bolus, timeOffset: NSTimeInterval) {
        self.id = event.id! as String
        if event.extended != nil {
            self.extendedValue = CGFloat(event.extended!)
        }
        if event.duration != nil {
            let durationInMS = Int(event.duration!)
            self.duration = NSTimeInterval(durationInMS / 1000)
        }
        if event.expectedNormal != nil {
            self.expectedNormal = CGFloat(event.expectedNormal!)
        }
        if event.expectedExtended != nil {
            self.expectedExtended = CGFloat(event.expectedExtended!)
        }
        if event.expectedDuration != nil {
            let expectedDurationInMS = Int(event.expectedDuration!)
            self.expectedDuration = NSTimeInterval(expectedDurationInMS / 1000)
        }
        let value = CGFloat(event.value!)
        super.init(value: value, timeOffset: timeOffset)
    }

    func maxValue() -> CGFloat {
        var maxValue: CGFloat = value
        if let expectedNormal = expectedNormal {
            if expectedNormal > maxValue {
                maxValue = expectedNormal
            }
        }
        return maxValue
    }
    
    init(curDatapoint: BolusGraphDataType, deltaTime: NSTimeInterval) {
        self.id = curDatapoint.id
        self.extendedValue = curDatapoint.extendedValue
        self.duration = curDatapoint.duration
        self.expectedNormal = curDatapoint.expectedNormal
        self.expectedExtended = curDatapoint.expectedExtended
        self.expectedDuration = curDatapoint.expectedDuration
        super.init(value: curDatapoint.value, timeOffset: deltaTime)
    }

    //(timeOffset: NSTimeInterval, value: NSNumber, suppressed: NSNumber?)
    override func typeString() -> String {
        return "bolus"
    }
}

/// BolusGraphDataType and WizardGraphDataType layers are coupled. Wizard datapoints are drawn after bolus datapoints, and directly above their corresponding bolus datapoint. Also, the bolus drawing needs to refer to the corresponding wizard data to determine whether an override has taken place.
class BolusGraphDataLayer: TidepoolGraphDataLayer {
    
    // when drawing the bolus layer, it is necessary to check for corresponding wizard values to determine if a bolus is an override of a wizard recommendation.
    var wizardLayer: WizardGraphDataLayer?
    
    // config...
    private let kBolusTextBlue = Styles.mediumBlueColor
    private let kBolusBlueRectColor = Styles.blueColor
    private let kBolusOverrideIconColor = UIColor(hex: 0x0C6999)
    private let kBolusInterruptBarColor = Styles.peachColor
    private let kBolusOverrideRectColor = Styles.lightBlueColor
    private let kBolusRectWidth: CGFloat = 14.0
    private let kBolusLabelToRectGap: CGFloat = 0.0
    private let kBolusLabelRectHeight: CGFloat = 12.0
    private let kBolusMinScaleValue: CGFloat = 1.0
    private let kExtensionLineHeight: CGFloat = 2.0
    private let kExtensionEndshapeWidth: CGFloat = 7.0
    private let kExtensionEndshapeHeight: CGFloat = 11.0
    private let kBolusMaxExtension: NSTimeInterval = 6*60*60 // Assume maximum bolus extension of 6 hours!

    // locals...
    private var context: CGContext?
    private var startValue: CGFloat = 0.0
    private var startTimeOffset: NSTimeInterval = 0.0
    private var startValueSuppressed: CGFloat?

    //
    // MARK: - Loading data
    //

    override func nominalPixelWidth() -> CGFloat {
        return kBolusRectWidth
    }

    // NOTE: the first BolusGraphDataLayer slice that has loadDataItems called loads the bolus data for the entire graph time interval
    override func loadStartTime() -> NSDate {
        return layout.graphStartTime.dateByAddingTimeInterval(-kBolusMaxExtension)
    }
    
    override func loadEndTime() -> NSDate {
        let timeExtensionForDataFetch = NSTimeInterval(nominalPixelWidth()/viewPixelsPerSec)
        return layout.graphStartTime.dateByAddingTimeInterval(layout.graphTimeInterval + timeExtensionForDataFetch)
    }

    override func typeString() -> String {
        return "bolus"
    }
    
    override func loadEvent(event: CommonData, timeOffset: NSTimeInterval) {
        if let event = event as? Bolus {
            //NSLog("Adding Bolus event: \(event)")
            if event.value != nil {
                let eventTime = event.time!
                let graphTimeOffset = eventTime.timeIntervalSinceDate(layout.graphStartTime)
                let bolus = BolusGraphDataType(event: event, timeOffset: graphTimeOffset)
                dataArray.append(bolus)
                let maxValue = bolus.maxValue()
                if maxValue > layout.maxBolus {
                    layout.maxBolus = maxValue
                }
            } else {
                NSLog("ignoring Bolus event with nil value")
            }
        }
    }

    override func loadDataItems() {
        // Note: since each graph tile needs to know the max bolus value for the graph, the first tile to load loads data for the whole graph range...
        if layout.allBolusData == nil {
            dataArray = []
            super.loadDataItems()
            layout.allBolusData = dataArray
            if layout.maxBolus < kBolusMinScaleValue {
                layout.maxBolus = kBolusMinScaleValue
            }
            //NSLog("Prefetched \(dataArray.count) bolus items for graph")
        }
        
        dataArray = []
        let dataLayerOffset = startTime.timeIntervalSinceDate(layout.graphStartTime)
        let rangeStart = dataLayerOffset - kBolusMaxExtension
        let timeExtensionForDataFetch = NSTimeInterval(nominalPixelWidth()/viewPixelsPerSec)
        let rangeEnd = dataLayerOffset + timeIntervalForView + timeExtensionForDataFetch
        // copy over cached items in the range needed for this tile!
        for item in layout.allBolusData! {
            if let bolusItem = item as? BolusGraphDataType {
                if bolusItem.timeOffset >= rangeStart && bolusItem.timeOffset <= rangeEnd {
                    let copiedItem = BolusGraphDataType(curDatapoint: bolusItem, deltaTime: bolusItem.timeOffset - dataLayerOffset)
                    
                    dataArray.append(copiedItem)
                }
            }
        }
        //NSLog("Copied \(dataArray.count) bolus items from graph cache for slice at offset \(dataLayerOffset/3600) hours")
        
    }

    //
    // MARK: - Drawing data points
    //

    // override for any draw setup
    override func configureForDrawing() {
        context = UIGraphicsGetCurrentContext()
        wizardLayer?.bolusRects = []
        startValue = 0.0
        startTimeOffset = 0.0
        startValueSuppressed = nil
   }
    
    // override!
    override func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
        
        if let bolus = dataPoint as? BolusGraphDataType {
            // Bolus rect is center-aligned to time start
            let centerX = xOffset
            var bolusValue = bolus.value
            if bolusValue > layout.maxBolus && bolusValue > kBolusMinScaleValue {
                NSLog("ERR: max bolus exceeded!")
                bolusValue = layout.maxBolus
            }
            
            // Measure out the label first so we know how much space we have for the rect below it.
            let bolusFloatValue = Float(bolus.value)
            var bolusLabelTextContent = String(format: "%.2f", bolusFloatValue)
            if bolusLabelTextContent.hasSuffix("0") {
                bolusLabelTextContent = String(format: "%.1f", bolusFloatValue)
            }
            let bolusLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            bolusLabelStyle.alignment = .Center
            let bolusLabelFontAttributes = [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: kBolusTextBlue, NSParagraphStyleAttributeName: bolusLabelStyle]
            var bolusLabelTextSize = bolusLabelTextContent.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: bolusLabelFontAttributes, context: nil).size
            bolusLabelTextSize = CGSize(width: ceil(bolusLabelTextSize.width), height: ceil(bolusLabelTextSize.height))

            let pixelsPerValue = (layout.yPixelsBolus - bolusLabelTextSize.height - kBolusLabelToRectGap) / CGFloat(layout.maxBolus)
            
            var override = false
            var interrupted = false
            var wizardHasOriginal = false
            var originalValue: CGFloat = 0.0
            // See if there is a corresponding wizard datapoint
            let wizardPoint = getWizardForBolusId(bolus.id)
            if let wizardPoint = wizardPoint {
                //NSLog("found wizard with carb \(wizardPoint.value) for bolus of value \(bolusValue)")
                if let recommended = wizardPoint.recommendedNet {
                    if recommended != bolusValue {
                        override = true
                        wizardHasOriginal = true
                        originalValue = CGFloat(recommended)
                    }
                }
            }

            // Draw the bolus rectangle
            let rectLeft = floor(centerX - (kBolusRectWidth/2))
            let bolusRectHeight = ceil(pixelsPerValue * bolusValue)
            var yOriginBolusRect = layout.yBottomOfBolus - bolusRectHeight
            let bolusValueRect = CGRect(x: rectLeft, y: yOriginBolusRect, width: kBolusRectWidth, height: bolusRectHeight)
            let bolusValueRectPath = UIBezierPath(rect: bolusValueRect)
            kBolusBlueRectColor.setFill()
            bolusValueRectPath.fill()
            
            // Alt option: Draw background colored border to separate the bolus from other objects
            //layout.backgroundColor.setStroke()
            //bolusValueRectPath.lineWidth = 1.0
            //bolusValueRectPath.stroke()

            // Handle interrupted boluses
            if let expectedNormal = bolus.expectedNormal {
                if expectedNormal > bolusValue {
                    interrupted = true
                    override = true
                    originalValue = expectedNormal
                    wizardHasOriginal = false
                } else {
                    NSLog("UNEXPECTED DATA - expectedNormal \(expectedNormal) not > bolus \(bolusValue)")
                }
            }

            // Handle extended, and interrupted extended bolus portion
            if let extendedValue = bolus.extendedValue {
                var extendedOriginal = extendedValue
                if let expectedExtended = bolus.expectedExtended {
                    if expectedExtended > extendedValue {
                        override = true
                        interrupted = true
                        extendedOriginal = expectedExtended
                    } else {
                        NSLog("UNEXPECTED DATA - expectedExtended \(expectedExtended) not > extended \(extendedValue)")
                    }
                }
                if !wizardHasOriginal {
                    originalValue += extendedOriginal
                }
            }

            // Draw override/interrupted rectangle and icon/bar if applicable
            if override  {
                let originalYOffset = layout.yBottomOfBolus - ceil(pixelsPerValue * originalValue)
                var yOriginOverrideIcon = originalYOffset
                // if recommended value was higher than the bolus, first draw a light-colored rect at the recommended value
                if originalValue > bolusValue {
                    yOriginOverrideIcon = yOriginBolusRect
                    // comment the following to place the label on top of the bolus rect, over the recommended rect bottom
                    yOriginBolusRect = originalYOffset // bump to recommended height so label goes above this!
                    let originalRectHeight = ceil(pixelsPerValue * (originalValue - bolusValue))

                    // alt 1: draw light colored blue, though this blends with basal rect color!
                    //let originalRect2 = CGRect(x: rectLeft, y: originalYOffset, width: kBolusRectWidth, height: originalRectHeight)
                    //let originalRectPath2 = UIBezierPath(rect: originalRect2)
                    //kBolusOverrideRectColor.setFill()
                    //originalRectPath2.fill()

                    // alt option: draw background colored border to separate the bolus from other objects
                    //layout.backgroundColor.setStroke()
                    //originalRectPath2.lineWidth = 1.0
                    //originalRectPath2.stroke()

                    // alt 2: just draw dotted rect with no fill
                    let originalRect = CGRect(x: rectLeft+0.5, y: originalYOffset+0.5, width: kBolusRectWidth-1.0, height: originalRectHeight)
                    let originalRectPath = UIBezierPath(rect: originalRect)
                    kBolusBlueRectColor.setStroke()
                    originalRectPath.lineWidth = 1
                    CGContextSaveGState(context)
                    CGContextSetLineDash(context, 0, [2, 2], 2)
                    originalRectPath.stroke()
                    CGContextRestoreGState(context)
                }
                if interrupted {
                    self.drawBolusInterruptBar(rectLeft, yOffset: yOriginOverrideIcon)
                } else {
                    self.drawBolusOverrideIcon(rectLeft, yOffset: yOriginOverrideIcon, pointUp: originalValue < bolusValue)
                }
            }

            // Finally, draw the bolus label above the rectangle
            let bolusLabelRect = CGRect(x:centerX-(bolusLabelTextSize.width/2), y: yOriginBolusRect - kBolusLabelToRectGap - bolusLabelTextSize.height, width: bolusLabelTextSize.width, height: bolusLabelTextSize.height)
            let bolusLabelPath = UIBezierPath(rect: bolusLabelRect.insetBy(dx: 0.0, dy: 2.0))
            layout.backgroundColor.setFill()
            bolusLabelPath.fill()
            
            CGContextSaveGState(context)
            CGContextClipToRect(context, bolusLabelRect);
            bolusLabelTextContent.drawInRect(bolusLabelRect, withAttributes: bolusLabelFontAttributes)
            CGContextRestoreGState(context)
            
            if let extendedValue = bolus.extendedValue, duration = bolus.duration {
                let width = floor(CGFloat(duration) * viewPixelsPerSec)
                let height = extendedValue * pixelsPerValue
                var originalWidth: CGFloat?
                if let _ = bolus.expectedExtended, expectedDuration = bolus.expectedDuration {
                    // extension was interrupted...
                    if expectedDuration > duration {
                        originalWidth = floor(CGFloat(expectedDuration) * viewPixelsPerSec)
                    } else {
                        NSLog("UNEXPECTED DATA - expectedDuration \(expectedDuration) not > duration \(duration)")
                    }
                }
                drawBolusExtension(bolusValueRect.origin.x + bolusValueRect.width, centerY: layout.yBottomOfBolus - height, width: width, originalWidth: originalWidth)
                //NSLog("bolus extension duration \(bolus.duration/60) minutes, extended value \(bolus.extendedValue), total value: \(bolus.value)")
            }
            
            let completeBolusRect = bolusLabelRect.union(bolusValueRect)
            wizardLayer?.bolusRects.append(completeBolusRect)
            wizardPoint?.bolusTopY = completeBolusRect.origin.y
        }
    }

    private func drawBolusOverrideIcon(xOffset: CGFloat, yOffset: CGFloat, pointUp: Bool) {
        // The override icon has its origin at the y position corresponding to the suggested bolus value that was overridden. 
        let context = UIGraphicsGetCurrentContext()
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, xOffset, yOffset)
        let flip: CGFloat = pointUp ? -1.0 : 1.0
        
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(0, 0))
        bezierPath.addLineToPoint(CGPointMake(0, 3.5*flip))
        bezierPath.addLineToPoint(CGPointMake(3.5, 3.5*flip))
        bezierPath.addLineToPoint(CGPointMake(7, 7*flip))
        bezierPath.addLineToPoint(CGPointMake(10.5, 3.5*flip))
        bezierPath.addLineToPoint(CGPointMake(14, 3.5*flip))
        bezierPath.addLineToPoint(CGPointMake(14, 0))
        bezierPath.addLineToPoint(CGPointMake(0, 0))
        bezierPath.closePath()
        kBolusOverrideIconColor.setFill()
        bezierPath.fill()
        CGContextRestoreGState(context)
    }

    private func drawBolusInterruptBar(xOffset: CGFloat, yOffset: CGFloat) {
        // Bar width matches width of bolus rect, height is 3.5 points
        let context = UIGraphicsGetCurrentContext()
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, xOffset, yOffset)
        
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(0, 0))
        bezierPath.addLineToPoint(CGPointMake(0, 3.5))
        bezierPath.addLineToPoint(CGPointMake(14, 3.5))
        bezierPath.addLineToPoint(CGPointMake(14, 0))
        bezierPath.addLineToPoint(CGPointMake(0, 0))
        bezierPath.closePath()
        kBolusInterruptBarColor.setFill()
        bezierPath.fill()
        CGContextRestoreGState(context)
    }

    private func drawBolusExtensionInterruptBar(xOffset: CGFloat, centerY: CGFloat) {
        // Bar width is 3.5 points, height is same as extension end triangle, fits on the end of the delivered extension triangle
        let context = UIGraphicsGetCurrentContext()
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, xOffset, centerY-(kExtensionEndshapeHeight/2.0))
        
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(0, 0))
        bezierPath.addLineToPoint(CGPointMake(3.5, 0))
        bezierPath.addLineToPoint(CGPointMake(3.5, kExtensionEndshapeHeight))
        bezierPath.addLineToPoint(CGPointMake(0, kExtensionEndshapeHeight))
        bezierPath.addLineToPoint(CGPointMake(0, 0))
        bezierPath.closePath()
        kBolusInterruptBarColor.setFill()
        bezierPath.fill()
        CGContextRestoreGState(context)
    }

    private func drawBolusExtensionShape(originX: CGFloat, centerY: CGFloat, width: CGFloat, borderOnly: Bool = false) {
        let originY = centerY - (kExtensionEndshapeHeight/2.0)
        let bottomLineY = centerY + (kExtensionLineHeight / 2.0)
        let topLineY = centerY - (kExtensionLineHeight / 2.0)
        let rightSideX = originX + width
        
        //if borderOnly {
        //    topLineY -= 0.5
        //    bottomLineY += 0.5
        //}
        
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(rightSideX, originY))
        bezierPath.addLineToPoint(CGPointMake(rightSideX, originY + kExtensionEndshapeHeight))
        bezierPath.addLineToPoint(CGPointMake(rightSideX - kExtensionEndshapeWidth, bottomLineY))
        bezierPath.addLineToPoint(CGPointMake(originX, bottomLineY))
        bezierPath.addLineToPoint(CGPointMake(originX, topLineY))
        bezierPath.addLineToPoint(CGPointMake(rightSideX - kExtensionEndshapeWidth, topLineY))
        bezierPath.addLineToPoint(CGPointMake(rightSideX, originY))
        bezierPath.closePath()
        if borderOnly {
            // Alt 1: use light-color instead
            //kBolusOverrideRectColor.setFill()
            //bezierPath.fill()
            
            // Alt 2: use a border
            kBolusBlueRectColor.setStroke()
            bezierPath.lineWidth = 1
            CGContextSaveGState(context)
            CGContextSetLineDash(context, 0, [2, 2], 2)
            bezierPath.stroke()
            CGContextRestoreGState(context)
        } else {
            kBolusBlueRectColor.setFill()
            bezierPath.fill()
        }
    }

    private func drawBolusExtension(var originX: CGFloat, centerY: CGFloat, var width: CGFloat, originalWidth: CGFloat?) {
        if width < kExtensionEndshapeWidth {
            // If extension is shorter than the end trapezoid shape, only draw that shape, backing it into the bolus rect
            originX = originX - (kExtensionEndshapeWidth - width)
            width = kExtensionEndshapeWidth
        }
        drawBolusExtensionShape(originX, centerY: centerY, width: width)
        // handle interrupted extended bolus!
        if let originalWidth = originalWidth {
            // only draw original extension if it is at least as large as the end shape!
            if originalWidth > (width + 3.5 + kExtensionEndshapeWidth) {
                drawBolusExtensionShape(originX + width, centerY: centerY, width: (originalWidth - width), borderOnly: true)
            }
            // always draw an interrupt bar at the end of the delivered part of the extension
            drawBolusExtensionInterruptBar(originX+width, centerY: centerY)
        }
    }

    private func getWizardForBolusId(bolusId: String) -> WizardGraphDataType? {
        if let wizardLayer = wizardLayer {
            for wizardItem in wizardLayer.dataArray {
                if let wizardItem = wizardItem as? WizardGraphDataType {
                    if let wizBolusId = wizardItem.bolusId {
                        if wizBolusId == bolusId  {
                            return wizardItem
                        }
                    }
                }
            }
        }
        return nil
    }
    
}