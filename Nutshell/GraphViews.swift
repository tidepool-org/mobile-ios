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

    //
    // MARK: - Graph parameters set at init time.
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
    // Bolus readings go in a section below glucose
    private var yTopOfBolus: CGFloat
    private var yBottomOfBolus: CGFloat
    private var yPixelsBolus: CGFloat
    // Basal readings go in a section below Bolus
    private var yTopOfBasal: CGFloat
    private var yBottomOfBasal: CGFloat
    private var yPixelsBasal: CGFloat
    // Workout durations go in a section below Basal
    private var yTopOfWorkout: CGFloat
    private var yBottomOfWorkout: CGFloat
    private var yPixelsWorkout: CGFloat

    //
    // MARK: - Constants used to set graph parameters
    //

    private let kGraphHeaderHeight: CGFloat = 32.0
    // After removing a constant height for the header, the remaining graph vertical space is divided into four sections based on the following fractions (which should add to 1.0)
    private let kGraphFractionForGlucose: CGFloat = 180.0/266.0
    private let kGraphFractionForBolus: CGFloat = 42.0/266.0
    private let kGraphFractionForBasal: CGFloat = 28.0/266.0
    private let kGraphFractionForWorkout: CGFloat = 16.0/266.0
    // Each section has some base offset as well
    private let kGraphWorkoutGlucoseOffset: CGFloat = 2.0
    private let kGraphWorkoutBolusOffset: CGFloat = 2.0
    private let kGraphWorkoutBasalOffset: CGFloat = 2.0
    private let kGraphWorkoutBaseOffset: CGFloat = 2.0
    // Some margin constants
    private let kGraphYLabelHeight: CGFloat = 18.0
    private let kGraphYLabelWidth: CGFloat = 20.0
    private let kGraphYLabelXOrigin: CGFloat = 0.0
    private let kYAxisLineLeftMargin: CGFloat = 24.0
    private let kYAxisLineRightMargin: CGFloat = 10.0

    // Some area-specific constants
    // NOTE: only supports minvalue==0 right now!
    private let kGlucoseMinValue: CGFloat = 0.0
    private let kGlucoseMaxValue: CGFloat = 340.0
    private let kGlucoseRange: CGFloat = 340.0
    private let kGlucoseConversionToMgDl: CGFloat = 18.0
    private let kSkipOverlappingValues = false
    private let kHourInSecs:NSTimeInterval = 3600.0
    private let k3HourInSecs:NSTimeInterval = 3*3600.0
    private let kWizardCircleDiameter: CGFloat = 27.0
    private let kBolusRectWidth: CGFloat = 14.0
    private let kBolusRectYOffset: CGFloat = 2.0
    private let kBolusLabelToRectGap: CGFloat = 3.0
    private let kBolusLabelRectWidth: CGFloat = 30.0
    private let kBolusLabelRectHeight: CGFloat = 10.0
    
    //
    // MARK: - Interface
    //

    init(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate) {
        self.viewSize = viewSize
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
        
        let graphHeight = viewSize.height - kGraphHeaderHeight
        
        // The largest section is for the glucose readings just below the header
        self.yTopOfGlucose = kGraphHeaderHeight
        self.yBottomOfGlucose = self.yTopOfGlucose + floor(kGraphFractionForGlucose * graphHeight) - kGraphWorkoutGlucoseOffset
        self.yPixelsGlucose = self.yBottomOfGlucose - self.yTopOfGlucose
        
        // Wizard data sits above the bolus readings, overlapping the bottom of the glucose graph which should be empty of readings that low
        self.yBottomOfWizard = self.yBottomOfGlucose

        // Next down are the bolus readings
        self.yTopOfBolus = self.yBottomOfGlucose + kGraphWorkoutGlucoseOffset
        self.yBottomOfBolus = self.yTopOfBolus + floor(kGraphFractionForBolus * graphHeight) - kGraphWorkoutBolusOffset
        self.yPixelsBolus = self.yBottomOfBolus - self.yTopOfBolus

        // Basal values sit just below the bolus readings
        self.yTopOfBasal = self.yBottomOfBolus + kGraphWorkoutBolusOffset
        self.yBottomOfBasal = self.yTopOfBasal + floor(kGraphFractionForBasal * graphHeight) - kGraphWorkoutBasalOffset
        self.yPixelsBasal = self.yBottomOfBasal - self.yTopOfBasal

        // Workout durations go in the bottom section
        self.yTopOfWorkout = yBottomOfBasal + kGraphWorkoutBasalOffset
        self.yBottomOfWorkout = self.yTopOfWorkout + floor(kGraphFractionForWorkout * graphHeight) - kGraphWorkoutBaseOffset
        self.yPixelsWorkout = self.yBottomOfWorkout - self.yTopOfWorkout

    }

    func imageOfGraphBackground() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawGraphBackground()
        
        let imageOfGraphBackground = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfGraphBackground
    }
    
    // Blood glucose level readings are draw as circles on the graph: large, labeled ones for manual readings, and small circles for those created from monitors. They are colored red, green, or purple, depending upon whether the values are below, within, or above target bounds.
    // The imageView will cover the width of the graph view, assuming 6 hours, time offsets may be passed in or calculated here. An array of points, probably containing tuples like (reading, time, manualFlag), or (Float, Float, Bool) values is probably minimal.
    
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

    func imageOfMealData(mealData: [NSTimeInterval]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawMealData(mealData)
        
        let imageOfMealData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfMealData
    }

    //
    // MARK: - Private drawing methods
    //

    private let hourMarkerStrokeColor = UIColor(hex: 0xe2e4e7)
    private let axisTextColor = UIColor(hex: 0x281946)

    private func drawGraphBackground() {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()
        
        //// Color Declarations
        let backgroundRightColor = UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1.000)
        let backgroundLeftColor = UIColor(red: 0.918, green: 0.937, blue: 0.941, alpha: 1.000)
        let horizontalLineColor = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)
        
        //// Frames - use whole view for background
        let contents = CGRectMake(0, 0, viewSize.width, viewSize.height)
        
        let graphStartSecs = startTime.timeIntervalSinceReferenceDate
        let next3HourBoundarySecs = ceil(graphStartSecs / k3HourInSecs) * k3HourInSecs
        let firstBoundarytimeOffset: NSTimeInterval = next3HourBoundarySecs - graphStartSecs
        var nextXBoundary = floor(CGFloat(firstBoundarytimeOffset) * viewPixelsPerSec)
        let pixelsPer3Hour = CGFloat(k3HourInSecs) * viewPixelsPerSec
        print("first 3 hour boundary at \(firstBoundarytimeOffset/60) minutes")
        var backgroundBlockOrigin = CGPoint(x: 0.0, y: kGraphHeaderHeight)
        // first background block width is odd
        var backgroundBlockSize = CGSize(width: nextXBoundary, height: viewSize.height - kGraphHeaderHeight)
        var evenBlock = true
        
        while backgroundBlockOrigin.x < viewSize.width {
            
            let backgroundBlockRect = CGRect(origin: backgroundBlockOrigin, size: backgroundBlockSize)
            let backgroundPath = UIBezierPath(rect: backgroundBlockRect)
            
            if evenBlock {
                backgroundLeftColor.setFill()
            } else {
                backgroundRightColor.setFill()
            }
            backgroundPath.fill()
            
            evenBlock = !evenBlock
            backgroundBlockSize.width = min(viewSize.width-nextXBoundary, pixelsPer3Hour)
            backgroundBlockOrigin.x = nextXBoundary
            nextXBoundary += pixelsPer3Hour
        }
        
        func drawYAxisLine(center: CGFloat) {
            let yAxisLinePath = UIBezierPath()
            yAxisLinePath.moveToPoint(CGPoint(x: kYAxisLineLeftMargin, y: center))
            yAxisLinePath.addLineToPoint(CGPoint(x: (viewSize.width - kYAxisLineRightMargin), y: center))
            yAxisLinePath.miterLimit = 4;
            yAxisLinePath.lineCapStyle = .Square;
            yAxisLinePath.lineJoinStyle = .Round;
            yAxisLinePath.usesEvenOddFillRule = true;
            
            horizontalLineColor.setStroke()
            yAxisLinePath.lineWidth = 3
            CGContextSaveGState(context)
            CGContextSetLineDash(context, 0, [3, 11], 2)
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
            
            let yAxisLabelFontAttributes = [NSFontAttributeName: Styles.verySmallRegularFont, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: yAxisLabelStyle]
            
            // center vertically - to do this we need font height
            let textHeight: CGFloat = yLabel.boundingRectWithSize(CGSizeMake(labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: yAxisLabelFontAttributes, context: nil).size.height
            CGContextSaveGState(context)
            CGContextClipToRect(context, labelRect);
            yLabel.drawInRect(CGRectMake(labelRect.minX, labelRect.minY + (labelRect.height - textHeight) / 2, labelRect.width, textHeight), withAttributes: yAxisLabelFontAttributes)
            CGContextRestoreGState(context)
        }
        
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange

        let yAxisValues = [40, 80, 180, 300]
        for yAxisValue in yAxisValues {
            let valueOffset = yBottomOfGlucose - (CGFloat(yAxisValue) * pixelsPerValue)
            drawYAxisLabel(String(yAxisValue), center: valueOffset)
        }

        let yAxisLines = [80, 180]
        for yAxisLine in yAxisLines {
            let valueOffset = yBottomOfGlucose - (CGFloat(yAxisLine) * pixelsPerValue)
            drawYAxisLine(valueOffset)
        }

        //
        //  Next draw the X-axis header...
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
        
        func drawHourLabel(hourStr: String, topCenter: CGPoint) {
    
            // Don't draw labels too close to margins
            if topCenter.x < 20.0 || topCenter.x > (viewSize.width - 20) {
                return
            }
            
            let labelRect = CGRectMake(topCenter.x - 16.0, topCenter.y, 32.0, 18.0)
            let hourlabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            hourlabelStyle.alignment = .Center
            
            let labelFontAttributes = [NSFontAttributeName: Styles.verySmallRegularFont, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hourlabelStyle]
            
            hourStr.drawInRect(labelRect, withAttributes: labelFontAttributes)
        }
        
        let df = NSDateFormatter()
        df.dateFormat = "h a"
        let hourlabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hourlabelStyle.alignment = .Center
        
        let nextHourBoundarySecs = ceil(graphStartSecs / kHourInSecs) * kHourInSecs
        var curDate = NSDate(timeIntervalSinceReferenceDate:nextHourBoundarySecs)
        let timeOffset: NSTimeInterval = nextHourBoundarySecs - graphStartSecs
        var viewXOffset = floor(CGFloat(timeOffset) * viewPixelsPerSec)
        let pixelsPerHour = CGFloat(kHourInSecs) * viewPixelsPerSec
        print("first hour boundary at \(timeOffset/60) minutes")
        repeat {
            
            let markerStart = CGPointMake(viewXOffset, kGraphHeaderHeight - 8.0)
            drawHourMarker(markerStart, length: 8.0)
                
            var hourStr = df.stringFromDate(curDate)
            // Replace uppercase PM and AM with lowercase versions
            hourStr = hourStr.stringByReplacingOccurrencesOfString("PM", withString: "p", options: NSStringCompareOptions.LiteralSearch, range: nil)
            hourStr = hourStr.stringByReplacingOccurrencesOfString("AM", withString: "a", options: NSStringCompareOptions.LiteralSearch, range: nil)

            // draw hour label
            drawHourLabel(hourStr, topCenter: CGPoint(x: viewXOffset, y: 6.0))
            
            curDate = curDate.dateByAddingTimeInterval(kHourInSecs)
            viewXOffset += pixelsPerHour
            
        } while (viewXOffset < viewSize.width)
        
        
    }

    private func drawWorkoutData(workoutData: [(timeOffset: NSTimeInterval, duration: NSTimeInterval)]) {
        
        for item in workoutData {
            let timeOffset = item.0
            let workoutDuration = item.1
            
            //// eventLine Drawing
            let centerX: CGFloat = floor(CGFloat(timeOffset) * viewPixelsPerSec)
            let eventLinePath = UIBezierPath(rect: CGRect(x: centerX, y: 0.0, width: 1.0, height: viewSize.height))
            Styles.pinkColor.setFill()
            eventLinePath.fill()
            
            //// eventRectangle Drawing
            let workoutRectWidth = floor(CGFloat(workoutDuration) * viewPixelsPerSec)
            let workoutRect = CGRect(x: centerX - (workoutRectWidth/2), y:yTopOfWorkout, width: workoutRectWidth, height: yPixelsWorkout)
            let eventRectanglePath = UIBezierPath(rect: workoutRect)
            Styles.pinkColor.setFill()
            eventRectanglePath.fill()
            
        }
    }

    private func drawMealData(mealData: [NSTimeInterval]) {
        
        for timeOffset in mealData {
            //// eventLine Drawing
            let eventLinePath = UIBezierPath(rect: CGRect(x: floor(CGFloat(timeOffset) * viewPixelsPerSec), y: 0.0, width: 1.0, height: viewSize.height))
            axisTextColor.setFill()
            eventLinePath.fill()
        }
    }

    private func drawBasalData(basalData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        
        var evenRect = true
        let basalBlueRectColor = Styles.blueColor
        let basalLightBlueRectColor = Styles.lightBlueColor

        // first figure out the range of data; only need to scale if we exceed this
        var rangeMax = 2.0
        for item in basalData {
            let nextValue = item.1
            if nextValue > rangeMax {
                rangeMax = item.1.doubleValue
            }
        }
        let yPixelsPerUnit = yPixelsBasal / CGFloat(rangeMax)

        func drawBasalRect(startTimeOffset: NSTimeInterval, endTimeOffset: NSTimeInterval, value: NSNumber) {
            let rectColor = evenRect ? basalLightBlueRectColor : basalBlueRectColor
            evenRect = !evenRect

            let rectLeft = floor(CGFloat(startTimeOffset) * viewPixelsPerSec)
            let rectRight = floor(CGFloat(endTimeOffset) * viewPixelsPerSec)
            let rectHeight = floor(yPixelsPerUnit * CGFloat(value))
            let basalRect = CGRect(x: rectLeft, y: yBottomOfBasal - rectHeight, width: rectRight - rectLeft, height: rectHeight)

            let basalValueRectPath = UIBezierPath(rect: basalRect)
            rectColor.setFill()
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
        
        // first figure out the range of data; only need to scale if we exceed this
        var rangeMax = 6.0
        for item in bolusData {
            if item.1 > rangeMax {
                rangeMax = item.1.doubleValue
            }
        }
 
        let yPixelsPerUnit = yPixelsBolus / CGFloat(rangeMax)

        // draw the items, left to right, with label on left.
        for item in bolusData {
            let context = UIGraphicsGetCurrentContext()
            
            // Color Declarations
            let bolusTextBlue = Styles.mediumBlueColor
            let bolusBlueRectColor = Styles.blueColor
            
            // bolusValueRect Drawing
            // Bolus rect is left-aligned to time start
            let rectLeft = floor(CGFloat(item.0) * viewPixelsPerSec)
            let rectHeight = floor(yPixelsPerUnit * CGFloat(item.1.doubleValue))
            let bolusValueRectPath = UIBezierPath(rect: CGRect(x: rectLeft, y: yBottomOfBolus - rectHeight - kBolusRectYOffset, width: kBolusRectWidth, height: rectHeight))
            bolusBlueRectColor.setFill()
            bolusValueRectPath.fill()
           
            // bolusLabel Drawing
            let bolusLabelRect = CGRect(x: rectLeft - kBolusLabelToRectGap - kBolusLabelRectWidth, y: yBottomOfBolus - kBolusLabelRectHeight, width: kBolusLabelRectWidth, height: kBolusLabelRectHeight)
            let bolusLabelTextContent = String(item.1) + " u"
            let bolusLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            bolusLabelStyle.alignment = .Right
            
            let bolusLabelFontAttributes = [NSFontAttributeName: Styles.verySmallSemiboldFont, NSForegroundColorAttributeName: bolusTextBlue, NSParagraphStyleAttributeName: bolusLabelStyle]
            
            let bolusLabelTextHeight: CGFloat = bolusLabelTextContent.boundingRectWithSize(CGSizeMake(bolusLabelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: bolusLabelFontAttributes, context: nil).size.height
            CGContextSaveGState(context)
            CGContextClipToRect(context, bolusLabelRect);
            bolusLabelTextContent.drawInRect(CGRectMake(bolusLabelRect.minX, bolusLabelRect.minY + bolusLabelRect.height - bolusLabelTextHeight, bolusLabelRect.width, bolusLabelTextHeight), withAttributes: bolusLabelFontAttributes)
            CGContextRestoreGState(context)
            
        }

}

    private func drawWizardData(wizardData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        for item in wizardData {
            
            let context = UIGraphicsGetCurrentContext()
            
            //// wizardBolus
            //// Oval-38-Copy-980 Drawing
            let wizardRect = CGRect(x: floor(CGFloat(item.0) * viewPixelsPerSec), y: yBottomOfWizard - kWizardCircleDiameter, width: kWizardCircleDiameter, height: kWizardCircleDiameter)
            let wizardOval = UIBezierPath(ovalInRect: wizardRect)
            Styles.goldColor.setFill()
            wizardOval.fill()
            
            //// Label Drawing
            let labelRect = wizardRect
            let labelText = String(Int(item.1)) + " g"
            let labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            labelStyle.alignment = .Center
            
            let labelAttrStr = NSMutableAttributedString(string: labelText, attributes: [NSFontAttributeName: Styles.verySmallSemiboldFont, NSForegroundColorAttributeName: Styles.altDarkGreyColor, NSParagraphStyleAttributeName: labelStyle])
            // Make " g" extra small
            labelAttrStr.addAttribute(NSFontAttributeName, value: Styles.veryTinySemiboldFont, range: NSRange(location: labelAttrStr.length - 2, length: 2))
            
            let labelTextHeight: CGFloat = labelAttrStr.boundingRectWithSize(CGSizeMake(labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil).size.height
            CGContextSaveGState(context)
            CGContextClipToRect(context, labelRect);
            labelAttrStr.drawInRect(CGRectMake(labelRect.minX, labelRect.minY + (labelRect.height - labelTextHeight) / 2, labelRect.width, labelTextHeight))
//            labelTextContent.drawInRect(CGRectMake(labelRect.minX, labelRect.minY + (labelRect.height - labelTextHeight) / 2, labelRect.width, labelTextHeight), withAttributes: labelFontAttributes)
            CGContextRestoreGState(context)
        }
    }
  
    private func drawCbgData(cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        //// General Declarations
    
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange
        let circleRadius: CGFloat = 2.5
        
        let highColor = Styles.purpleColor
        let targetColor = Styles.greenColor
        let lowColor = Styles.peachColor
        let highBoundary: NSNumber = 180.0
        let lowBoundary: NSNumber = 90.0
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
            if (!kSkipOverlappingValues || !lastCircleDrawn.intersects(circleRect)) {
                let smallCirclePath = UIBezierPath(ovalInRect: circleRect)
                circleColor.setFill()
                smallCirclePath.fill()
                lastCircleDrawn = circleRect
            } else {
                print("skipping overlapping value \(value)")
            }
        }
        print("\(cbgData.count) cbg events, low: \(lowValue) high: \(highValue)")
    }
   
    private func drawSmbgData(smbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        //// General Declarations
        
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange
        let circleRadius: CGFloat = 7.5
        
        let highColor = Styles.purpleColor
        let targetColor = Styles.greenColor
        let lowColor = Styles.peachColor
        let highBoundary: NSNumber = 180.0
        let lowBoundary: NSNumber = 90.0
        var lowValue: CGFloat = kGlucoseMaxValue
        var highValue: CGFloat = kGlucoseMinValue

        let context = UIGraphicsGetCurrentContext()

        for item in smbgData {
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
            let smallCirclePath = UIBezierPath(ovalInRect: CGRectMake(centerX-circleRadius, centerY-circleRadius, circleRadius*2, circleRadius*2))
            circleColor.setFill()
            smallCirclePath.fill()
            
            let readingLabelRect = CGRectMake(centerX-18, centerY+circleRadius, 36, 20)
            let intValue = Int(value)
            let readingLabelTextContent = String(intValue)
            let readingLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            readingLabelStyle.alignment = .Center
            
            let readingLabelFontAttributes = [NSFontAttributeName: Styles.verySmallSemiboldFont, NSForegroundColorAttributeName: circleColor, NSParagraphStyleAttributeName: readingLabelStyle]
            
            let readingLabelTextHeight: CGFloat = readingLabelTextContent.boundingRectWithSize(CGSizeMake(readingLabelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: readingLabelFontAttributes, context: nil).size.height
            CGContextSaveGState(context)
            CGContextClipToRect(context, readingLabelRect);
            
            readingLabelTextContent.drawInRect(CGRectMake(readingLabelRect.minX, readingLabelRect.minY + (readingLabelRect.height - readingLabelTextHeight) / 2, readingLabelRect.width, readingLabelTextHeight), withAttributes: readingLabelFontAttributes)
            CGContextRestoreGState(context)
        }
        print("\(smbgData.count) smbg events, low: \(lowValue) high: \(highValue)")
    }

}
