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
import CoreGraphics

public class GraphViews {

    // Note: This is somewhat obscure, but caller needs to know to provide data on end of view time to avoid collection view overlap discontinuities. Calculated at init time.
    var timeExtensionForDataFetch: NSTimeInterval = 0.0
    private let kLargestGraphItemWidth: CGFloat = 30.0
    
    //
    // MARK: - Customization constants
    //

    private let kGraphHeaderHeight: CGFloat = 32.0
    private let kGraphWizardHeight: CGFloat = 27.0
    // After removing a constant height for the header and wizard values, the remaining graph vertical space is divided into four sections based on the following fractions (which should add to 1.0)
    private let kGraphFractionForGlucose: CGFloat = 180.0/266.0
    private let kGraphFractionForBolusAndBasal: CGFloat = 76.0/266.0
    //private let kGraphFractionForWorkout: CGFloat = 16.0/266.0
    // Each section has some base offset as well
    private let kGraphGlucoseBaseOffset: CGFloat = 2.0
    private let kGraphWizardBaseOffset: CGFloat = 2.0
    private let kGraphBolusBaseOffset: CGFloat = 2.0
    private let kGraphBasalBaseOffset: CGFloat = 2.0
    private let kGraphWorkoutBaseOffset: CGFloat = 2.0
    // Some margin constants
    private let kGraphYLabelHeight: CGFloat = 18.0
    private let kGraphYLabelWidth: CGFloat = 26.0
    private let kGraphYLabelXOrigin: CGFloat = 0.0
    private let kYAxisLineLeftMargin: CGFloat = 24.0
    private let kYAxisLineRightMargin: CGFloat = 10.0
    // General constants
    private let kHourInSecs:NSTimeInterval = 3600.0

    //
    // MARK: - Area-specific customization
    //

    // 
    // Background
    //
    private let hourMarkerStrokeColor = UIColor(hex: 0xe2e4e7)
    private let axisTextColor = UIColor(hex: 0x58595B)
    private let mealLineColor = Styles.blackColor
    private let mealTriangleColor = Styles.darkPurpleColor
    private let otherMealColor = UIColor(hex: 0x948ca3)
    // Colors
    // TODO: add all graph colors here, based on Styles colors
    private let backgroundRightColor = Styles.veryLightGreyColor
    private let backgroundLeftColor = Styles.veryLightGreyColor
    private let backgroundColor = Styles.veryLightGreyColor
    private let horizontalLineColor = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)

    //
    // Blood glucose data (cbg and smbg)
    //
    // NOTE: only supports minvalue==0 right now!
    private let kGlucoseMinValue: CGFloat = 0.0
    private let kGlucoseMaxValue: CGFloat = 340.0
    private let kGlucoseRange: CGFloat = 340.0
    private let kGlucoseConversionToMgDl: CGFloat = 18.0
    private let highBoundary: NSNumber = 180.0
    private let lowBoundary: NSNumber = 80.0
    // Colors
    private let highColor = Styles.purpleColor
    private let targetColor = Styles.greenColor
    private let lowColor = Styles.peachColor

    //
    // Wizard and bolus data
    //
    private let kWizardCircleDiameter: CGFloat = 31.0
    private let kBolusRectWidth: CGFloat = 14.0
    private let kBolusLabelToRectGap: CGFloat = 0.0
    private let kBolusLabelRectHeight: CGFloat = 12.0
    private let kBolusMinScaleValue: CGFloat = 0.0
    // Colors
    private let bolusTextBlue = Styles.mediumBlueColor
    private let bolusBlueRectColor = Styles.blueColor
    
    //
    // Basal data
    //
    private let basalLightBlueRectColor = Styles.lightBlueColor
    private let kBasalMinScaleValue: CGFloat = 0.0
    
    //
    // MARK: - Graph vars based on view size and customization constants
    //
    
    // These are based on an origin on the lower left. For plotting, the y value needs to be adjusted for origin on the upper left.
    private var viewSize: CGSize
    private var timeIntervalForView: NSTimeInterval
    private var viewPixelsPerSec: CGFloat
    private var startTime: NSDate
    // Glucose readings go from 340(?) down to 0 in a section just below the header
    private var yTopOfGlucose: CGFloat
    private var yBottomOfGlucose: CGFloat
    private var yPixelsGlucose: CGFloat
    // Wizard readings overlap the bottom part of the glucose readings
    private var yBottomOfWizard: CGFloat
    // Bolus and Basal readings go in a section below glucose
    private var yTopOfBolus: CGFloat
    private var yBottomOfBolus: CGFloat
    private var yPixelsBolus: CGFloat
    private var yTopOfBasal: CGFloat
    private var yBottomOfBasal: CGFloat
    private var yPixelsBasal: CGFloat
    // Workout durations go in a section below Basal
    //private var yTopOfWorkout: CGFloat
    //private var yBottomOfWorkout: CGFloat
    //private var yPixelsWorkout: CGFloat

    //
    // MARK: - Interface
    //

    init(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate) {
        self.viewSize = viewSize
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
        
        // calculate the extra time we need data fetched for at the end of the graph time span so we draw the beginnings of next graph items
        timeExtensionForDataFetch = NSTimeInterval(kLargestGraphItemWidth/viewPixelsPerSec)

        // Tweak: if height is less than 320 pixels, let the wizard circles drift up into the low area of the blood glucose data since that should be clear
        let wizardHeight = viewSize.height < 320.0 ? 0.0 : kGraphWizardHeight
        
        // The pie to divide is what's left over after removing constant height areas
        let graphHeight = viewSize.height - kGraphHeaderHeight - wizardHeight
        
        // The largest section is for the glucose readings just below the header
        self.yTopOfGlucose = kGraphHeaderHeight
        self.yBottomOfGlucose = self.yTopOfGlucose + floor(kGraphFractionForGlucose * graphHeight) - kGraphGlucoseBaseOffset
        self.yPixelsGlucose = self.yBottomOfGlucose - self.yTopOfGlucose
        
        // Wizard data sits above the bolus readings, in a fixed space area, possibly overlapping the bottom of the glucose graph which should be empty of readings that low.
        // TODO: put wizard data on top of corresponding bolus data!
        self.yBottomOfWizard = self.yBottomOfGlucose + wizardHeight

        // At the bottom are the bolus and basal readings
        self.yTopOfBolus = self.yBottomOfWizard + kGraphWizardBaseOffset
        self.yBottomOfBolus = viewSize.height
        self.yPixelsBolus = self.yBottomOfBolus - self.yTopOfBolus

        // Basal values sit just below the bolus readings
        self.yTopOfBasal = self.yTopOfBolus
        self.yBottomOfBasal = self.yBottomOfBolus
        self.yPixelsBasal = self.yPixelsBolus

        // Workout durations go in the bottom section
        //self.yTopOfWorkout = yBottomOfBasal + kGraphBasalBaseOffset
        //self.yBottomOfWorkout = self.yTopOfWorkout + floor(kGraphFractionForWorkout * graphHeight) - kGraphWorkoutBaseOffset
        //self.yPixelsWorkout = self.yBottomOfWorkout - self.yTopOfWorkout
    }
    
    func updateTimeframe(timeIntervalForView: NSTimeInterval, startTime: NSDate) {
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)        
    }

    func imageOfFixedGraphBackground() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawFixedGraphBackground()
        
        let imageOfFixedGraphBackground = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfFixedGraphBackground
    }

    func imageOfXAxisHeader() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawXAxisHeader()
        
        let imageOfGraphBackground = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfGraphBackground
    }
    
    func imageOfCbgData(cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawCbgData(cbgData)
        
        let imageOfCbgData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfCbgData
    }
    
    func imageOfSmbgData(smbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawSmbgData(smbgData)
        
        let imageOfSmbgData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfSmbgData
    }

    func imageOfWizardData(wizardData: [(timeOffset: NSTimeInterval, value: NSNumber)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawWizardData(wizardData)
        
        let imageData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageData
    }

    func imageOfBolusData(bolusData: [(timeOffset: NSTimeInterval, value: NSNumber)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawBolusData(bolusData)
        
        let imageOfBolusData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfBolusData
    }

    func imageOfBasalData(basalData: [(timeOffset: NSTimeInterval, value: NSNumber)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawBasalData(basalData)
        
        let imageOfBasalData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfBasalData
    }

    func imageOfWorkoutData(workoutData: [(timeOffset: NSTimeInterval, duration: NSTimeInterval)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawWorkoutData(workoutData)
        
        let imageOfData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfData
    }

    func imageOfMealData(mealData: [(timeOffset: NSTimeInterval, mainEvent: Bool)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawMealData(mealData)
        
        let imageOfMealData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfMealData
    }

    //
    // MARK: - Private drawing methods
    //

    private func drawFixedGraphBackground() {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()
        
        //// Frames - use whole view for background
        let contents = CGRectMake(0, 0, viewSize.width, viewSize.height)
        
        //
        //  Draw the background block
        //
        let backgroundBlockRect = CGRect(x: 0.0, y: kGraphHeaderHeight, width: viewSize.width, height: viewSize.height - kGraphHeaderHeight)
        let backgroundPath = UIBezierPath(rect: backgroundBlockRect)
        backgroundLeftColor.setFill()
        backgroundPath.fill()
        
        //
        //  Draw the Y-axis labels and lines...
        //
        
        func drawYAxisLine(center: CGFloat) {
            let yAxisLinePath = UIBezierPath()
            yAxisLinePath.moveToPoint(CGPoint(x: kYAxisLineLeftMargin, y: center))
            yAxisLinePath.addLineToPoint(CGPoint(x: (viewSize.width - kYAxisLineRightMargin), y: center))
            yAxisLinePath.miterLimit = 4;
            yAxisLinePath.lineCapStyle = .Square;
            yAxisLinePath.lineJoinStyle = .Round;
            yAxisLinePath.usesEvenOddFillRule = true;
            
            horizontalLineColor.setStroke()
            yAxisLinePath.lineWidth = 1.5
            CGContextSaveGState(context)
            CGContextSetLineDash(context, 0, [2, 5], 2)
            yAxisLinePath.stroke()
            CGContextRestoreGState(context)
        }
        
        func drawYAxisLabel(yLabel: String, center: CGFloat) {
            
            // Don't draw labels too close to margins
            if center < 20.0 || center > (viewSize.width - 20.0) {
                print("skipping yAxis label \(yLabel)")
                return
            }
            
            let labelRect = CGRectMake(kGraphYLabelXOrigin, center-(kGraphYLabelHeight/2), kGraphYLabelWidth, kGraphYLabelHeight)
            let yAxisLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            yAxisLabelStyle.alignment = .Right
            
            let yAxisLabelFontAttributes = [NSFontAttributeName: Styles.smallRegularFont, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: yAxisLabelStyle]
            
            // center vertically - to do this we need font height
            let textHeight: CGFloat = yLabel.boundingRectWithSize(CGSizeMake(labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: yAxisLabelFontAttributes, context: nil).size.height
            CGContextSaveGState(context)
            CGContextClipToRect(context, labelRect);
            yLabel.drawInRect(CGRectMake(labelRect.minX, labelRect.minY + (labelRect.height - textHeight) / 2, labelRect.width, textHeight), withAttributes: yAxisLabelFontAttributes)
            CGContextRestoreGState(context)
        }
        
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange
        
        let yAxisLines = [80, 180]
        for yAxisLine in yAxisLines {
            let valueOffset = yBottomOfGlucose - (CGFloat(yAxisLine) * pixelsPerValue)
            drawYAxisLine(valueOffset)
        }

        let yAxisValues = [40, 80, 180, 300]
        for yAxisValue in yAxisValues {
            let valueOffset = yBottomOfGlucose - (CGFloat(yAxisValue) * pixelsPerValue)
            drawYAxisLabel(String(yAxisValue), center: valueOffset)
        }
    }

    private func drawXAxisHeader() {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()
        
        //// Frames - use whole view for background
        let contents = CGRectMake(0, 0, viewSize.width, viewSize.height)
        let graphStartSecs = startTime.timeIntervalSinceReferenceDate
        let pixelsPerHour = CGFloat(kHourInSecs) * viewPixelsPerSec

        // Remember last label rect so we don't overwrite previous...
        var lastLabelDrawn = CGRectNull

        //
        //  Draw the X-axis header...
        //
        
        func drawHourMarker(start: CGPoint, length: CGFloat) {
            let hourMarkerPath = UIBezierPath()
            hourMarkerPath.moveToPoint(start)
            hourMarkerPath.addLineToPoint(CGPointMake(start.x, start.y + length))
            hourMarkerPath.miterLimit = 4;
            
            hourMarkerPath.lineCapStyle = .Square;
            
            hourMarkerPath.usesEvenOddFillRule = true;
            
            hourMarkerStrokeColor.setStroke()
            hourMarkerPath.lineWidth = 1
            hourMarkerPath.stroke()
        }
        
        func drawHourLabel(hourStr: String, topCenter: CGPoint, midnight: Bool) {

            let hourlabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            hourlabelStyle.alignment = .Left
            
            let labelAttrStr = NSMutableAttributedString(string: hourStr, attributes: [NSFontAttributeName: Styles.smallRegularFont, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hourlabelStyle])
            
            if !midnight {
                // Make " a" or " p" lighter
                labelAttrStr.addAttribute(NSFontAttributeName, value: Styles.smallLightFont, range: NSRange(location: labelAttrStr.length - 2, length: 2))
            }
            
            let sizeNeeded = labelAttrStr.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
            
            let originX = midnight ? topCenter.x + 4.0 : topCenter.x - sizeNeeded.width/2.0
            let labelRect = CGRect(x: originX, y: 6.0, width: sizeNeeded.width, height: sizeNeeded.height)
            // skip label draw if we would overwrite previous label
            if (!lastLabelDrawn.intersects(labelRect)) {
                labelAttrStr.drawInRect(labelRect)
                lastLabelDrawn = labelRect
            } else {
                print("skipping x axis label")
            }
        }
        
        let df = NSDateFormatter()
        df.dateFormat = "h a"
        let hourlabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hourlabelStyle.alignment = .Center

        // Draw times a little early and going to a little later so collection views overlap correctly
        let earlyStartTime = graphStartSecs - timeExtensionForDataFetch
        let lateEndLocation = kLargestGraphItemWidth

        let nextHourBoundarySecs = ceil(earlyStartTime / kHourInSecs) * kHourInSecs
        var curDate = NSDate(timeIntervalSinceReferenceDate:nextHourBoundarySecs)
        let timeOffset: NSTimeInterval = nextHourBoundarySecs - graphStartSecs
        var viewXOffset = floor(CGFloat(timeOffset) * viewPixelsPerSec)

        repeat {
            
            var hourStr = df.stringFromDate(curDate)
            // Replace uppercase PM and AM with lowercase versions
            hourStr = hourStr.stringByReplacingOccurrencesOfString("PM", withString: "p", options: NSStringCompareOptions.LiteralSearch, range: nil)
            hourStr = hourStr.stringByReplacingOccurrencesOfString("AM", withString: "a", options: NSStringCompareOptions.LiteralSearch, range: nil)

            // TODO: don't overwrite this date with 1a, 2a, etc depending upon its length
            var midnight = false
            if hourStr == "12 a" {
                midnight = true
                hourStr = NutUtils.standardUIDayString(curDate)
            }
            
            // draw marker
            let markerLength = midnight ? kGraphHeaderHeight : 8.0
            let markerStart = CGPointMake(viewXOffset, kGraphHeaderHeight - markerLength)
            drawHourMarker(markerStart, length: markerLength)

            // draw hour label
            drawHourLabel(hourStr, topCenter: CGPoint(x: viewXOffset, y: 6.0), midnight: midnight)
            
            curDate = curDate.dateByAddingTimeInterval(kHourInSecs)
            viewXOffset += pixelsPerHour
            
        } while (viewXOffset < viewSize.width + lateEndLocation)
    }

    private func drawWorkoutData(workoutData: [(timeOffset: NSTimeInterval, duration: NSTimeInterval)]) {
        
//        for item in workoutData {
//            let timeOffset = item.0
//            let workoutDuration = item.1
//            
//            //// eventLine Drawing
//            let centerX: CGFloat = floor(CGFloat(timeOffset) * viewPixelsPerSec)
//            let eventLinePath = UIBezierPath(rect: CGRect(x: centerX, y: 0.0, width: 1.0, height: viewSize.height))
//            Styles.pinkColor.setFill()
//            eventLinePath.fill()
//            
//            //// eventRectangle Drawing
//            let workoutRectWidth = floor(CGFloat(workoutDuration) * viewPixelsPerSec)
//            let workoutRect = CGRect(x: centerX - (workoutRectWidth/2), y:yTopOfWorkout, width: workoutRectWidth, height: yPixelsWorkout)
//            let eventRectanglePath = UIBezierPath(rect: workoutRect)
//            Styles.pinkColor.setFill()
//            eventRectanglePath.fill()
//            
//        }
    }

    private func drawMeal(timeOffset: NSTimeInterval, isMain: Bool) {
        //// eventLine Drawing
        let lineColor = isMain ? mealLineColor : otherMealColor
        let triangleColor = isMain ? mealTriangleColor : otherMealColor
        let lineHeight: CGFloat = isMain ? viewSize.height : kGraphHeaderHeight
        let lineWidth: CGFloat = isMain ? 2.0 : 1.0
        
        let rect = CGRect(x: floor(CGFloat(timeOffset) * viewPixelsPerSec), y: 0.0, width: lineWidth, height: lineHeight)
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
    
    private func drawMealData(mealData: [(timeOffset: NSTimeInterval, mainEvent: Bool)]) {
        
        for item in mealData {
            drawMeal(item.0, isMain: item.1)
        }
    }

    private func drawBasalData(basalData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        
        // first figure out the range of data; scale rectangle to fill this
        var rangeHi = CGFloat(kBasalMinScaleValue)
        for item in basalData {
            let nextValue = CGFloat(item.1.doubleValue)
            if nextValue > rangeHi {
                rangeHi = nextValue
            }
        }

        let yPixelsPerUnit = yPixelsBasal / CGFloat(rangeHi)

        func drawBasalRect(startTimeOffset: NSTimeInterval, endTimeOffset: NSTimeInterval, value: NSNumber) {

            let rectLeft = floor(CGFloat(startTimeOffset) * viewPixelsPerSec)
            let rectRight = floor(CGFloat(endTimeOffset) * viewPixelsPerSec)
            let rectHeight = floor(yPixelsPerUnit * CGFloat(value))
            let basalRect = CGRect(x: rectLeft, y: yBottomOfBasal - rectHeight, width: rectRight - rectLeft, height: rectHeight)

            let basalValueRectPath = UIBezierPath(rect: basalRect)
            basalLightBlueRectColor.setFill()
            basalValueRectPath.fill()
        }

        var startValue: CGFloat = 0.0
        var startTimeOffset: NSTimeInterval = 0.0
        
        // draw the items, left to right. A zero value ends a rect, a new value ends any current rect and starts a new one.
        for item in basalData {
            // skip over values before starting time, but remember last value...
            let itemTime = item.0
            let itemValue = item.1
            if itemTime < 0 {
                startValue = CGFloat(itemValue)
            } else if startValue == 0.0 {
                if (itemValue > 0.0) {
                    // just starting a rect, note the time...
                    startTimeOffset = itemTime
                    startValue = CGFloat(itemValue)
                }
            } else {
                // got another value, draw the rect
                drawBasalRect(startTimeOffset, endTimeOffset: itemTime, value: startValue)
                // and start another rect...
                startValue = CGFloat(itemValue)
                startTimeOffset = itemTime
            }
        }
        // finish off any rect we started...
        if (startValue > 0.0) {
            drawBasalRect(startTimeOffset, endTimeOffset: timeIntervalForView, value: startValue)
        }
        
    }

    private func drawBolusData(bolusData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        
        // first figure out the range of data; scale rectangle to fill this
        var rangeHi = CGFloat(kBolusMinScaleValue)
        for item in bolusData {
            let nextValue = CGFloat(item.1.doubleValue)
            if nextValue > rangeHi {
                rangeHi = nextValue
            }
        }
        
        // bolus vertical area is split into a colored rect below, and label on top
        let yPixelsPerUnit = (yPixelsBolus - kBolusLabelRectHeight - kBolusLabelToRectGap) / CGFloat(rangeHi)

        // draw the items, with label on top.
        for item in bolusData {
            let context = UIGraphicsGetCurrentContext()
            
            // bolusValueRect Drawing
            // Bolus rect is center-aligned to time start
            // Carb circle should be centered at timeline
            let centerX: CGFloat = floor(CGFloat(item.0) * viewPixelsPerSec)
            let rectLeft = floor(centerX - (kBolusRectWidth/2))
            let bolusRectHeight = floor(yPixelsPerUnit * CGFloat(item.1.doubleValue))
            let bolusValueRect = CGRect(x: rectLeft, y: yBottomOfBolus - bolusRectHeight, width: kBolusRectWidth, height: bolusRectHeight)
            let bolusValueRectPath = UIBezierPath(rect: bolusValueRect)
            bolusBlueRectColor.setFill()
            bolusValueRectPath.fill()
            
            let bolusFloatValue = Float(item.1)
            let bolusLabelTextContent = String(format: "%.1f", bolusFloatValue)
            let bolusLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            bolusLabelStyle.alignment = .Center
            let bolusLabelFontAttributes = [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: bolusTextBlue, NSParagraphStyleAttributeName: bolusLabelStyle]
            let bolusLabelTextSize = bolusLabelTextContent.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: bolusLabelFontAttributes, context: nil).size
            let bolusLabelRect = CGRect(x:centerX-(bolusLabelTextSize.width/2), y:yBottomOfBolus - bolusRectHeight - kBolusLabelToRectGap - bolusLabelTextSize.height, width: bolusLabelTextSize.width, height: bolusLabelTextSize.height)
            
            let bolusLabelPath = UIBezierPath(rect: bolusLabelRect.insetBy(dx: 0.0, dy: 2.0))
            backgroundColor.setFill()
            bolusLabelPath.fill()

            CGContextSaveGState(context)
            CGContextClipToRect(context, bolusLabelRect);
            bolusLabelTextContent.drawInRect(bolusLabelRect, withAttributes: bolusLabelFontAttributes)
            CGContextRestoreGState(context)
        }

}

    private func drawWizardData(wizardData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        for item in wizardData {
            
            let context = UIGraphicsGetCurrentContext()
            
            // Carb circle should be centered at timeline
            let offsetX = floor((CGFloat(item.0) * viewPixelsPerSec) - (kWizardCircleDiameter/2))
            let wizardRect = CGRect(x: offsetX, y: yBottomOfWizard - kWizardCircleDiameter, width: kWizardCircleDiameter, height: kWizardCircleDiameter)
            let wizardOval = UIBezierPath(ovalInRect: wizardRect)
            Styles.goldColor.setFill()
            wizardOval.fill()
            // Draw background colored border to separate the circle from other objects
            backgroundColor.setStroke()
            wizardOval.lineWidth = 1.5
            wizardOval.stroke()
            
            // Label Drawing
            let labelRect = wizardRect
            let labelText = String(Int(item.1))
            let labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            labelStyle.alignment = .Center
            
            let labelAttrStr = NSMutableAttributedString(string: labelText, attributes: [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: Styles.darkPurpleColor, NSParagraphStyleAttributeName: labelStyle])
            
            let labelTextHeight: CGFloat = labelAttrStr.boundingRectWithSize(CGSizeMake(labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil).size.height
            CGContextSaveGState(context)
            CGContextClipToRect(context, labelRect);
            labelAttrStr.drawInRect(CGRectMake(labelRect.minX, labelRect.minY + (labelRect.height - labelTextHeight) / 2, labelRect.width, labelTextHeight))
            CGContextRestoreGState(context)
        }
    }
  
    private func drawCbgData(cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        //// General Declarations
    
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange
        let circleRadius: CGFloat = 3.5
        
        var lowValue: CGFloat = kGlucoseMaxValue
        var highValue: CGFloat = kGlucoseMinValue
        var lastCircleDrawn = CGRectNull
        
        for item in cbgData {
            let centerX: CGFloat = floor(CGFloat(item.0) * viewPixelsPerSec)
            var value = round(CGFloat(item.1) * kGlucoseConversionToMgDl)
            if value > kGlucoseMaxValue {
                value = kGlucoseMaxValue
            }
            if value < lowValue {
                lowValue = value
            }
            if value > highValue {
                highValue = value
            }
            // flip the Y to compensate for origin!
            let centerY: CGFloat = yTopOfGlucose + yPixelsGlucose - floor(value * pixelsPerValue)
            
            let circleColor = value < lowBoundary ? lowColor : value < highBoundary ? targetColor : highColor
            let circleRect = CGRectMake(centerX-circleRadius, centerY-circleRadius, circleRadius*2, circleRadius*2)
            let smallCircleRect = circleRect.insetBy(dx: 1.0, dy: 1.0)
            
            if !lastCircleDrawn.intersects(circleRect) {
                let smallCirclePath = UIBezierPath(ovalInRect: circleRect)
                circleColor.setFill()
                smallCirclePath.fill()
                backgroundColor.setStroke()
                smallCirclePath.lineWidth = 1.5
                smallCirclePath.stroke()
            } else {
                let smallCirclePath = UIBezierPath(ovalInRect: smallCircleRect)
                circleColor.setFill()
                smallCirclePath.fill()
            }
                
            lastCircleDrawn = circleRect
        }
        print("\(cbgData.count) cbg events, low: \(lowValue) high: \(highValue)")
    }
   
    private func drawSmbgData(smbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        //// General Declarations
        
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange
        let circleRadius: CGFloat = 9.0
        var lowValue: CGFloat = kGlucoseMaxValue
        var highValue: CGFloat = kGlucoseMinValue

        let context = UIGraphicsGetCurrentContext()

        for item in smbgData {
            let centerX: CGFloat = floor(CGFloat(item.0) * viewPixelsPerSec)
            var value = round(CGFloat(item.1) * kGlucoseConversionToMgDl)
            let valueForLabel = value
            if value > kGlucoseMaxValue {
                value = kGlucoseMaxValue
            }
            if value < lowValue {
                lowValue = value
            }
            if value > highValue {
                highValue = value
            }
            // flip the Y to compensate for origin!
            let centerY: CGFloat = yTopOfGlucose + yPixelsGlucose - floor(value * pixelsPerValue)
            
            let circleColor = value < lowBoundary ? lowColor : value < highBoundary ? targetColor : highColor
            let largeCirclePath = UIBezierPath(ovalInRect: CGRectMake(centerX-circleRadius, centerY-circleRadius, circleRadius*2, circleRadius*2))
            circleColor.setFill()
            largeCirclePath.fill()
            backgroundColor.setStroke()
            largeCirclePath.lineWidth = 1.5
            largeCirclePath.stroke()
            
            let intValue = Int(valueForLabel)
            let readingLabelTextContent = String(intValue)
            let readingLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            readingLabelStyle.alignment = .Center
            let readingLabelFontAttributes = [NSFontAttributeName: Styles.smallSemiboldFont, NSForegroundColorAttributeName: circleColor, NSParagraphStyleAttributeName: readingLabelStyle]
            let readingLabelTextSize = readingLabelTextContent.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: readingLabelFontAttributes, context: nil).size
            let readingLabelRect = CGRectMake(centerX-(readingLabelTextSize.width/2), centerY+circleRadius, readingLabelTextSize.width, readingLabelTextSize.height)
            
            let readingLabelPath = UIBezierPath(rect: readingLabelRect.insetBy(dx: 1.0, dy: 2.5))
            backgroundColor.setFill()
            readingLabelPath.fill()
            
            CGContextSaveGState(context)
            
            CGContextClipToRect(context, readingLabelRect);
            readingLabelTextContent.drawInRect(readingLabelRect, withAttributes: readingLabelFontAttributes)
            CGContextRestoreGState(context)
        }
        print("\(smbgData.count) smbg events, low: \(lowValue) high: \(highValue)")
    }

}
