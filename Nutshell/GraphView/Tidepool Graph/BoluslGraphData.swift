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
    
    var hasExtension: Bool = false
    var extendedValue: CGFloat = 0.0
    var duration: NSTimeInterval = 0.0
    var id: String
    
    init(event: Bolus, timeOffset: NSTimeInterval) {
        self.id = event.id! as String
        let extendedBolus = event.extended
        let duration = event.duration
        if let extendedBolus = extendedBolus, duration = duration {
            self.hasExtension = true
            self.extendedValue = CGFloat(extendedBolus)
            let durationInMS = Int(duration)
            self.duration = NSTimeInterval(durationInMS / 1000)
        }
        let value = CGFloat(event.value!)
        super.init(value: value, timeOffset: timeOffset)
    }

    init(curDatapoint: BolusGraphDataType, deltaTime: NSTimeInterval) {
        self.id = curDatapoint.id
        self.hasExtension = curDatapoint.hasExtension
        self.extendedValue = curDatapoint.extendedValue
        self.duration = curDatapoint.duration
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
                if bolus.value > layout.maxBolus {
                    layout.maxBolus = bolus.value
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
            NSLog("Prefetched \(dataArray.count) bolus items for graph")
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
        NSLog("Copied \(dataArray.count) bolus items from graph cache for slice at offset \(dataLayerOffset/3600) hours")
        
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
            var recommendedValue: CGFloat = 0.0
            // See if there is a corresponding wizard datapoint
            let wizardPoint = getWizardForBolusId(bolus.id)
            if let wizardPoint = wizardPoint {
                NSLog("found wizard with carb \(wizardPoint.value) for bolus of value \(bolusValue)")
                if let recommended = wizardPoint.recommendedNet {
                    recommendedValue = CGFloat(recommended)
                    override = recommendedValue != bolusValue
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

            // Draw override rectangle and icon if applicable
            if override  {
                let recommendedYOffset = layout.yBottomOfBolus - ceil(pixelsPerValue * recommendedValue)
                var yOriginOverrideIcon = recommendedYOffset
                // if recommended value was higher than the bolus, first draw a light-colored rect at the recommended value
                if recommendedValue > bolusValue {
                    yOriginOverrideIcon = yOriginBolusRect
                    // comment the following to place the label on top of the bolus rect, over the recommended rect bottom
                    yOriginBolusRect = recommendedYOffset // bump to recommended height so label goes above this!
                    let recommendedRectHeight = ceil(pixelsPerValue * (recommendedValue - bolusValue))
                    // alt 1: just draw dotted rect with no fill
                    let recommendedRect = CGRect(x: rectLeft+0.5, y: recommendedYOffset+0.5, width: kBolusRectWidth-1.0, height: recommendedRectHeight)
                    let recommendedRectPath = UIBezierPath(rect: recommendedRect)
                    kBolusBlueRectColor.setStroke()
                    recommendedRectPath.lineWidth = 1
                    CGContextSaveGState(context)
                    CGContextSetLineDash(context, 0, [2, 2], 2)
                    recommendedRectPath.stroke()
                    CGContextRestoreGState(context)
                    // alt 2: draw light colored blue, though this blends with basal rect color!
                    //let recommendedRect = CGRect(x: rectLeft, y: recommendedYOffset, width: kBolusRectWidth, height: recommendedRectHeight)
                    //let recommendedRectPath = UIBezierPath(rect: recommendedRect)
                    //kBolusOverrideRectColor.setFill()
                    //recommendedRectPath.fill()
                }
                self.drawBolusOverrideIcon(rectLeft, yOffset: yOriginOverrideIcon, pointUp: recommendedValue < bolusValue)
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
            
            if bolus.hasExtension {
                let width = floor(CGFloat(bolus.duration) * viewPixelsPerSec)
                // Note: bolus.value is comprised of the initial bolus value plus the extended value, and hasExtension is false if the extended value is zero, so there should be no divide by zero issues even with "bad" data
                let height = bolus.extendedValue * pixelsPerValue
                drawBolusExtension(bolusValueRect.origin.x + bolusValueRect.width, centerY: layout.yBottomOfBolus - height, width: width, layout: layout)
                //NSLog("bolus extension duration \(bolus.duration/60) minutes, extended value \(bolus.extendedValue), total value: \(bolus.value)")
            }
            
            wizardLayer?.bolusRects.append(bolusLabelRect.union(bolusValueRect))
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
    
    private func drawBolusExtension(var originX: CGFloat, centerY: CGFloat, var width: CGFloat, layout: TidepoolGraphLayout) {
        if width < kExtensionEndshapeWidth {
            // If extension is shorter than the end trapezoid shape, only draw that shape, backing it into the bolus rect
            originX = originX - (kExtensionEndshapeWidth - width)
            width = kExtensionEndshapeWidth
        }
        let originY = centerY - (kExtensionEndshapeHeight/2.0)
        let bottomLineY = centerY + (kExtensionLineHeight / 2.0)
        let topLineY = centerY - (kExtensionLineHeight / 2.0)
        let rightSideX = originX + width
        
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
        kBolusBlueRectColor.setFill()
        bezierPath.fill()
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