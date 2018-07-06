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

class BolusGraphDataType: GraphDataType {
    
    var extendedValue: CGFloat?
    var duration: TimeInterval?
    var expectedNormal: CGFloat?
    var expectedExtended: CGFloat?
    var expectedDuration: TimeInterval?
    var id: String
    
    init(event: Bolus, timeOffset: TimeInterval) {
        self.id = event.id! as String
        if event.extended != nil {
            self.extendedValue = CGFloat(truncating: event.extended!)
        }
        if event.duration != nil {
            let durationInMS = Int(truncating: event.duration!)
            self.duration = TimeInterval(durationInMS / 1000)
        }
        if event.expectedNormal != nil {
            self.expectedNormal = CGFloat(truncating: event.expectedNormal!)
        }
        if event.expectedExtended != nil {
            self.expectedExtended = CGFloat(truncating: event.expectedExtended!)
        }
        if event.expectedDuration != nil {
            let expectedDurationInMS = Int(truncating: event.expectedDuration!)
            self.expectedDuration = TimeInterval(expectedDurationInMS / 1000)
        }
        let value = CGFloat(truncating: event.value!)
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
    
    init(curDatapoint: BolusGraphDataType, deltaTime: TimeInterval) {
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
    fileprivate let kBolusTextBlue = Styles.mediumBlueColor
    fileprivate let kBolusBlueRectColor = Styles.blueColor
    fileprivate let kBolusOverrideIconColor = UIColor(hex: 0x0C6999)
    fileprivate let kBolusInterruptBarColor = Styles.peachColor
    fileprivate let kBolusRectWidth: CGFloat = 14.0
    fileprivate let kBolusLabelToRectGap: CGFloat = 0.0
    fileprivate let kBolusLabelRectHeight: CGFloat = 12.0
    fileprivate let kBolusMinScaleValue: CGFloat = 1.0
    fileprivate let kExtensionLineHeight: CGFloat = 2.0
    fileprivate let kExtensionEndshapeWidth: CGFloat = 7.0
    fileprivate let kExtensionEndshapeHeight: CGFloat = 11.0
    fileprivate let kExtensionInterruptBarWidth: CGFloat = 6.0
    fileprivate let kBolusMaxExtension: TimeInterval = 6*60*60 // Assume maximum bolus extension of 6 hours!

    // locals...
    fileprivate var context: CGContext?
    fileprivate var startValue: CGFloat = 0.0
    fileprivate var startTimeOffset: TimeInterval = 0.0
    fileprivate var startValueSuppressed: CGFloat?

    //
    // MARK: - Loading data
    //

    override func nominalPixelWidth() -> CGFloat {
        return kBolusRectWidth
    }

    // NOTE: the first BolusGraphDataLayer slice that has loadDataItems called loads the bolus data for the entire graph time interval
    override func loadStartTime() -> Date {
        return layout.graphStartTime.addingTimeInterval(-kBolusMaxExtension) as Date
    }
    
    override func loadEndTime() -> Date {
        let timeExtensionForDataFetch = TimeInterval(nominalPixelWidth()/viewPixelsPerSec)
        return layout.graphStartTime.addingTimeInterval(layout.graphTimeInterval + timeExtensionForDataFetch)
    }

    override func typeString() -> String {
        return "bolus"
    }
    
    override func loadEvent(_ event: CommonData, timeOffset: TimeInterval) {
        if let event = event as? Bolus {
            //DDLogInfo("Adding Bolus event: \(event)")
            if event.value != nil {
                let eventTime = event.time!
                let graphTimeOffset = eventTime.timeIntervalSince(layout.graphStartTime as Date)
                let bolus = BolusGraphDataType(event: event, timeOffset: graphTimeOffset)
                dataArray.append(bolus)
                let maxValue = bolus.maxValue()
                if maxValue > layout.maxBolus {
                    layout.maxBolus = maxValue
                }
            } else {
                DDLogInfo("ignoring Bolus event with nil value")
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
            //DDLogInfo("Prefetched \(dataArray.count) bolus items for graph")
        }
        
        dataArray = []
        let dataLayerOffset = startTime.timeIntervalSince(layout.graphStartTime as Date)
        let rangeStart = dataLayerOffset - kBolusMaxExtension
        let timeExtensionForDataFetch = TimeInterval(nominalPixelWidth()/viewPixelsPerSec)
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
        //DDLogInfo("Copied \(dataArray.count) bolus items from graph cache for slice at offset \(dataLayerOffset/3600) hours")
        
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
    override func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
        
        if let bolus = dataPoint as? BolusGraphDataType {
            // Bolus rect is center-aligned to time start
            let centerX = xOffset
            var bolusValue = bolus.value
            if bolusValue > layout.maxBolus && bolusValue > kBolusMinScaleValue {
                DDLogInfo("ERR: max bolus exceeded!")
                bolusValue = layout.maxBolus
            }
            
            // Measure out the label first so we know how much space we have for the rect below it.
            let bolusFloatValue = Float(bolus.value)
            var bolusLabelTextContent = String(format: "%.2f", bolusFloatValue)
            if bolusLabelTextContent.hasSuffix("0") {
                bolusLabelTextContent = String(format: "%.1f", bolusFloatValue)
            }
            let bolusLabelStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            bolusLabelStyle.alignment = .center
            let bolusLabelFontAttributes = [NSAttributedStringKey.font: Styles.smallSemiboldFont, NSAttributedStringKey.foregroundColor: kBolusTextBlue, NSAttributedStringKey.paragraphStyle: bolusLabelStyle]
            var bolusLabelTextSize = bolusLabelTextContent.boundingRect(with: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: bolusLabelFontAttributes, context: nil).size
            bolusLabelTextSize = CGSize(width: ceil(bolusLabelTextSize.width), height: ceil(bolusLabelTextSize.height))

            let pixelsPerValue = (layout.yPixelsBolus - bolusLabelTextSize.height - kBolusLabelToRectGap) / CGFloat(layout.maxBolus)
            
            var override = false
            var interrupted = false
            var wizardHasOriginal = false
            var originalValue: CGFloat = 0.0
            // See if there is a corresponding wizard datapoint
            let wizardPoint = getWizardForBolusId(bolus.id)
            if let wizardPoint = wizardPoint {
                //DDLogInfo("found wizard with carb \(wizardPoint.value) for bolus of value \(bolusValue)")
                if let recommended = wizardPoint.recommendedNet {
                    if recommended.floatValue != Float(bolusValue) {
                        override = true
                        wizardHasOriginal = true
                        originalValue = CGFloat(truncating: recommended)
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
            
            layout.backgroundColor.setStroke()
            bolusValueRectPath.lineWidth = 0.5
            bolusValueRectPath.stroke()

            // Handle interrupted boluses
            if let expectedNormal = bolus.expectedNormal {
                if expectedNormal > bolusValue {
                    interrupted = true
                    override = true
                    originalValue = expectedNormal
                    wizardHasOriginal = false
                } else {
                    DDLogInfo("UNEXPECTED DATA - expectedNormal \(expectedNormal) not > bolus \(bolusValue)")
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
                        DDLogInfo("UNEXPECTED DATA - expectedExtended \(expectedExtended) not > extended \(extendedValue)")
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
                // if recommended value was higher than the bolus, first draw a light-colored rect with dashed outline at the recommended value
                if originalValue > bolusValue {
                    yOriginOverrideIcon = yOriginBolusRect
                    // comment the following line to place the label on top of the bolus rect, over the recommended rect bottom
                    yOriginBolusRect = originalYOffset // bump to recommended height so label goes above this!
                    let originalRectHeight = ceil(pixelsPerValue * (originalValue - bolusValue))
                    let originalRect = CGRect(x: rectLeft+0.5, y: originalYOffset+0.5, width: kBolusRectWidth-1.0, height: originalRectHeight)
                    let originalRectPath = UIBezierPath(rect: originalRect)
                    // fill with background color
                    layout.backgroundColor.setFill()
                    originalRectPath.fill()
                    // then outline with a dashed line
                    kBolusBlueRectColor.setStroke()
                    originalRectPath.lineWidth = 1
                    originalRectPath.lineCapStyle = .butt
                    let pattern: [CGFloat] = [2.0, 2.0]
                    originalRectPath.setLineDash(pattern, count: 2, phase: 0.0)
                    originalRectPath.stroke()
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
            
            context!.saveGState()
            context!.clip(to: bolusLabelRect);
            bolusLabelTextContent.draw(in: bolusLabelRect, withAttributes: bolusLabelFontAttributes)
            context!.restoreGState()
            
            if let extendedValue = bolus.extendedValue, let duration = bolus.duration {
                let width = floor(CGFloat(duration) * viewPixelsPerSec)
                var height = ceil(extendedValue * pixelsPerValue)
                if height < kExtensionLineHeight/2.0 {
                    // tweak to align extension rect with bottom of bolus rect
                    height = kExtensionLineHeight/2.0
                }
                var originalWidth: CGFloat?
                if let _ = bolus.expectedExtended, let expectedDuration = bolus.expectedDuration {
                    // extension was interrupted...
                    if expectedDuration > duration {
                        originalWidth = floor(CGFloat(expectedDuration) * viewPixelsPerSec)
                    } else {
                        DDLogInfo("UNEXPECTED DATA - expectedDuration \(expectedDuration) not > duration \(duration)")
                    }
                }
                var yOrigin = layout.yBottomOfBolus - height
                if yOrigin == bolusValueRect.origin.y {
                // tweak to align extension rect with top of bolus rect
                   yOrigin = yOrigin + kExtensionLineHeight/2.0
                }
                drawBolusExtension(bolusValueRect.origin.x + bolusValueRect.width, centerY: yOrigin, width: width, originalWidth: originalWidth)
                //DDLogInfo("bolus extension duration \(bolus.duration/60) minutes, extended value \(bolus.extendedValue), total value: \(bolus.value)")
            }
            
            let completeBolusRect = bolusLabelRect.union(bolusValueRect)
            wizardLayer?.bolusRects.append(completeBolusRect)
            wizardPoint?.bolusTopY = completeBolusRect.origin.y
        }
    }

    fileprivate func drawBolusOverrideIcon(_ xOffset: CGFloat, yOffset: CGFloat, pointUp: Bool) {
        // The override icon has its origin at the y position corresponding to the suggested bolus value that was overridden. 
        let context = UIGraphicsGetCurrentContext()
        context!.saveGState()
        context!.translateBy(x: xOffset, y: yOffset)
        let flip: CGFloat = pointUp ? -1.0 : 1.0
        
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: 0, y: 0))
        bezierPath.addLine(to: CGPoint(x: 0, y: 3.5*flip))
        bezierPath.addLine(to: CGPoint(x: 3.5, y: 3.5*flip))
        bezierPath.addLine(to: CGPoint(x: 7, y: 7*flip))
        bezierPath.addLine(to: CGPoint(x: 10.5, y: 3.5*flip))
        bezierPath.addLine(to: CGPoint(x: 14, y: 3.5*flip))
        bezierPath.addLine(to: CGPoint(x: 14, y: 0))
        bezierPath.addLine(to: CGPoint(x: 0, y: 0))
        bezierPath.close()
        kBolusOverrideIconColor.setFill()
        bezierPath.fill()
        context!.restoreGState()
    }

    fileprivate func drawBolusInterruptBar(_ xOffset: CGFloat, yOffset: CGFloat) {
        // Bar width matches width of bolus rect, height is 3.5 points
        let context = UIGraphicsGetCurrentContext()
        context!.saveGState()
        let barWidth = kBolusRectWidth - 1.0
        context!.translateBy(x: xOffset + 0.5, y: yOffset)
        
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: 0, y: 0))
        bezierPath.addLine(to: CGPoint(x: 0, y: 3.5))
        bezierPath.addLine(to: CGPoint(x: barWidth, y: 3.5))
        bezierPath.addLine(to: CGPoint(x: barWidth, y: 0))
        bezierPath.addLine(to: CGPoint(x: 0, y: 0))
        bezierPath.close()
        kBolusInterruptBarColor.setFill()
        bezierPath.fill()
        context!.restoreGState()
    }

    fileprivate func drawBolusExtensionInterruptBar(_ xOffset: CGFloat, centerY: CGFloat) {
        // Blip extension interrupt bar width is smaller than bolus interrupt bar by 10:24 ratio, x:14 here
        // Bar width is 5 points, and fits on the end of the delivered extension bar
        let context = UIGraphicsGetCurrentContext()
        context!.saveGState()
        let barHeight = kExtensionLineHeight
        context!.translateBy(x: xOffset, y: centerY-(barHeight/2.0))
        
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: 0, y: 0))
        bezierPath.addLine(to: CGPoint(x: kExtensionInterruptBarWidth, y: 0))
        bezierPath.addLine(to: CGPoint(x: kExtensionInterruptBarWidth, y: barHeight))
        bezierPath.addLine(to: CGPoint(x: 0, y: barHeight))
        bezierPath.addLine(to: CGPoint(x: 0, y: 0))
        bezierPath.close()
        kBolusInterruptBarColor.setFill()
        bezierPath.fill()
        context!.restoreGState()
    }

    fileprivate func drawBolusExtensionShape(_ originX: CGFloat, centerY: CGFloat, width: CGFloat, borderOnly: Bool = false, noEndShape: Bool = false) {
        let centerY = round(centerY)
        let originY = centerY - (kExtensionEndshapeHeight/2.0)
        let bottomLineY = centerY + (kExtensionLineHeight / 2.0)
        let topLineY = centerY - (kExtensionLineHeight / 2.0)
        let rightSideX = originX + width
        
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        if noEndShape {
            bezierPath.move(to: CGPoint(x: rightSideX, y: topLineY))
            bezierPath.addLine(to: CGPoint(x: rightSideX, y: bottomLineY))
            bezierPath.addLine(to: CGPoint(x: originX, y: bottomLineY))
            bezierPath.addLine(to: CGPoint(x: originX, y: topLineY))
            bezierPath.addLine(to: CGPoint(x: rightSideX, y: topLineY))
        } else {
            bezierPath.move(to: CGPoint(x: rightSideX, y: originY))
            bezierPath.addLine(to: CGPoint(x: rightSideX, y: originY + kExtensionEndshapeHeight))
            bezierPath.addLine(to: CGPoint(x: rightSideX - kExtensionEndshapeWidth, y: bottomLineY))
            bezierPath.addLine(to: CGPoint(x: originX, y: bottomLineY))
            bezierPath.addLine(to: CGPoint(x: originX, y: topLineY))
            bezierPath.addLine(to: CGPoint(x: rightSideX - kExtensionEndshapeWidth, y: topLineY))
            bezierPath.addLine(to: CGPoint(x: rightSideX, y: originY))
        }
        bezierPath.close()
        if borderOnly {
            // use a border, with no fill
            kBolusBlueRectColor.setStroke()
            bezierPath.lineWidth = 1
            bezierPath.lineCapStyle = .butt
            let pattern: [CGFloat] = [2.0, 2.0]
            bezierPath.setLineDash(pattern, count: 2, phase: 0.0)
            bezierPath.stroke()
        } else {
            kBolusBlueRectColor.setFill()
            bezierPath.fill()
        }
    }

    fileprivate func drawBolusExtension( _ originX: CGFloat, centerY: CGFloat, width: CGFloat, originalWidth: CGFloat?) {
        var width = width
        var originX = originX
        if width < kExtensionEndshapeWidth {
            // If extension is shorter than the end trapezoid shape, only draw that shape, backing it into the bolus rect
            originX = originX - (kExtensionEndshapeWidth - width)
            width = kExtensionEndshapeWidth
        }
        
        // only draw original end shape if bolus was not interrupted!
        drawBolusExtensionShape(originX, centerY: centerY, width: width, borderOnly: false, noEndShape: (originalWidth != nil))
        
        // handle interrupted extended bolus
        if let originalWidth = originalWidth {
            // draw original extension, but make sure it is at least as large as the end shape!
            var extensionWidth = originalWidth - width
            if extensionWidth < kExtensionEndshapeWidth {
                extensionWidth = kExtensionEndshapeWidth
            }
            drawBolusExtensionShape(originX + width, centerY: centerY, width: extensionWidth, borderOnly: true)
            
            // always draw an interrupt bar at the end of the delivered part of the extension
            drawBolusExtensionInterruptBar(originX + width, centerY: centerY)
        }
    }

    fileprivate func getWizardForBolusId(_ bolusId: String) -> WizardGraphDataType? {
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
