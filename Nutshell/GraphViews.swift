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
    private var timeIntervalForView: CGFloat
    private var viewPixelsPerSec: CGFloat
    // Glucose readings go from 340(?) down to 0 in a section just below the header
    private var yTopOfGlucose: CGFloat
    private var yBottomOfGlucose: CGFloat
    private var yPixelsGlucose: CGFloat
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
    // Some area-specific constants
    private let kGlucoseRange: CGFloat = 340.0
    private let kGlucoseConversionToMgDl: CGFloat = 18.0
   
    
    //
    // MARK: - Interface
    //

    init(viewSize: CGSize, timeIntervalForView: CGFloat) {
        self.viewSize = viewSize
        self.timeIntervalForView = timeIntervalForView
        self.viewPixelsPerSec = viewSize.width/timeIntervalForView
        
        let graphHeight = viewSize.height - kGraphHeaderHeight
        
        // The largest section is for the glucose readings just below the header
        self.yTopOfGlucose = kGraphHeaderHeight
        self.yBottomOfGlucose = self.yTopOfGlucose + floor(kGraphFractionForGlucose * graphHeight) - kGraphWorkoutGlucoseOffset
        self.yPixelsGlucose = self.yBottomOfGlucose - self.yTopOfGlucose

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
    
    func imageOfGlucoseData(cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawGlucoseData(cbgData)
        
        let imageOfGlucoseData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfGlucoseData
    }
    
    func imageOfHealthEvent(duration: NSTimeInterval) -> UIImage {
        let healthEventToGraphBottomLeading: CGFloat = 5.0
        let imageHeight = viewSize.height - healthEventToGraphBottomLeading;
        let eventWidth = floor(CGFloat(duration) * viewPixelsPerSec)
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(eventWidth, imageHeight), false, 0)
        drawHealthEvent(eventWidth: eventWidth, imageHeight: imageHeight)
        
        let imageOfHealthEvent = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfHealthEvent
    }

    //
    // MARK: - Private drawing methods
    //

    private func drawGraphBackground() {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()
        
        //// Color Declarations
        let backgroundRightColor = UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1.000)
        let backgroundLeftColor = UIColor(red: 0.918, green: 0.937, blue: 0.941, alpha: 1.000)
        let horizontalLineColor = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)
        let axisTextColor = UIColor(red: 0.345, green: 0.349, blue: 0.357, alpha: 1.000)
        let hourMarkerStrokeColor = UIColor(red: 0.863, green: 0.882, blue: 0.886, alpha: 1.000)
        
        //// Frames - use whole view for background
        let backgroundFrame = CGRectMake(0, 0, viewSize.width, viewSize.height)
        
        //// Subframes
        let contents: CGRect = CGRectMake(backgroundFrame.minX, backgroundFrame.minY, backgroundFrame.width, backgroundFrame.height - 1)
        
        
        //// contents
        //// right-half-background Drawing
        let righthalfbackgroundPath = UIBezierPath(rect: CGRectMake(contents.minX + floor(contents.width * 0.49844 - 0.5) + 1, contents.minY + floor(contents.height * 0.08981 + 0.5), floor(contents.width * 1.00000 - 0.5) - floor(contents.width * 0.49844 - 0.5), floor(contents.height * 1.00000 + 0.5) - floor(contents.height * 0.08981 + 0.5)))
        backgroundRightColor.setFill()
        righthalfbackgroundPath.fill()
        
        
        //// left-half-background Drawing
        let lefthalfbackgroundPath = UIBezierPath(rect: CGRectMake(contents.minX + floor(contents.width * 0.00000 + 0.5), contents.minY + floor(contents.height * 0.08981 + 0.5), floor(contents.width * 0.50156 + 0.5) - floor(contents.width * 0.00000 + 0.5), floor(contents.height * 1.00000 + 0.5) - floor(contents.height * 0.08981 + 0.5)))
        backgroundLeftColor.setFill()
        lefthalfbackgroundPath.fill()
        
        
        //// line-at-180 Drawing
        let lineat180Path = UIBezierPath()
        lineat180Path.moveToPoint(CGPointMake(contents.minX + 0.07449 * contents.width, contents.minY + 0.29728 * contents.height))
        lineat180Path.addLineToPoint(CGPointMake(contents.minX + 0.99122 * contents.width, contents.minY + 0.29728 * contents.height))
        lineat180Path.miterLimit = 4;
        
        lineat180Path.lineCapStyle = .Square;
        
        lineat180Path.lineJoinStyle = .Round;
        
        lineat180Path.usesEvenOddFillRule = true;
        
        horizontalLineColor.setStroke()
        lineat180Path.lineWidth = 3
        CGContextSaveGState(context)
        CGContextSetLineDash(context, 0, [3, 11], 2)
        lineat180Path.stroke()
        CGContextRestoreGState(context)
        
        
        //// line-at-80 Drawing
        let lineat80Path = UIBezierPath()
        lineat80Path.moveToPoint(CGPointMake(contents.minX + 0.07449 * contents.width, contents.minY + 0.47105 * contents.height))
        lineat80Path.addLineToPoint(CGPointMake(contents.minX + 0.99122 * contents.width, contents.minY + 0.47105 * contents.height))
        lineat80Path.miterLimit = 4;
        
        lineat80Path.lineCapStyle = .Square;
        
        lineat80Path.lineJoinStyle = .Round;
        
        lineat80Path.usesEvenOddFillRule = true;
        
        horizontalLineColor.setStroke()
        lineat80Path.lineWidth = 3
        CGContextSaveGState(context)
        CGContextSetLineDash(context, 0, [3, 11], 2)
        lineat80Path.stroke()
        CGContextRestoreGState(context)
        
        
        //// y-axis-300-label Drawing
        let yaxis300labelRect = CGRectMake(contents.minX + floor(contents.width * 0.00000 + 0.5), contents.minY + floor(contents.height * 0.11572 + 0.5), floor(contents.width * 0.05919 + 0.5) - floor(contents.width * 0.00000 + 0.5), floor(contents.height * 0.17271 + 0.5) - floor(contents.height * 0.11572 + 0.5))
        let yaxis300labelTextContent = NSString(string: "300")
        let yaxis300labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        yaxis300labelStyle.alignment = .Right
        
        let yaxis300labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: yaxis300labelStyle]
        
        let yaxis300labelTextHeight: CGFloat = yaxis300labelTextContent.boundingRectWithSize(CGSizeMake(yaxis300labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: yaxis300labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, yaxis300labelRect);
        yaxis300labelTextContent.drawInRect(CGRectMake(yaxis300labelRect.minX, yaxis300labelRect.minY + (yaxis300labelRect.height - yaxis300labelTextHeight) / 2, yaxis300labelRect.width, yaxis300labelTextHeight), withAttributes: yaxis300labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// y-axis-180-label Drawing
        let yaxis180labelRect = CGRectMake(contents.minX + floor(contents.width * 0.00000 + 0.5), contents.minY + floor(contents.height * 0.26943 + 0.5), floor(contents.width * 0.05919 + 0.5) - floor(contents.width * 0.00000 + 0.5), floor(contents.height * 0.32642 + 0.5) - floor(contents.height * 0.26943 + 0.5))
        let yaxis180labelTextContent = NSString(string: "180")
        let yaxis180labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        yaxis180labelStyle.alignment = .Right
        
        let yaxis180labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: yaxis180labelStyle]
        
        let yaxis180labelTextHeight: CGFloat = yaxis180labelTextContent.boundingRectWithSize(CGSizeMake(yaxis180labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: yaxis180labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, yaxis180labelRect);
        yaxis180labelTextContent.drawInRect(CGRectMake(yaxis180labelRect.minX, yaxis180labelRect.minY + (yaxis180labelRect.height - yaxis180labelTextHeight) / 2, yaxis180labelRect.width, yaxis180labelTextHeight), withAttributes: yaxis180labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// y-axis-80-label Drawing
        let yaxis80labelRect = CGRectMake(contents.minX + floor(contents.width * 0.00000 + 0.5), contents.minY + floor(contents.height * 0.44387 + 0.5), floor(contents.width * 0.05919 + 0.5) - floor(contents.width * 0.00000 + 0.5), floor(contents.height * 0.50086 + 0.5) - floor(contents.height * 0.44387 + 0.5))
        let yaxis80labelTextContent = NSString(string: "80")
        let yaxis80labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        yaxis80labelStyle.alignment = .Right
        
        let yaxis80labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: yaxis80labelStyle]
        
        let yaxis80labelTextHeight: CGFloat = yaxis80labelTextContent.boundingRectWithSize(CGSizeMake(yaxis80labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: yaxis80labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, yaxis80labelRect);
        yaxis80labelTextContent.drawInRect(CGRectMake(yaxis80labelRect.minX, yaxis80labelRect.minY + (yaxis80labelRect.height - yaxis80labelTextHeight) / 2, yaxis80labelRect.width, yaxis80labelTextHeight), withAttributes: yaxis80labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// y-axis-40-label Drawing
        let yaxis40labelRect = CGRectMake(contents.minX + floor(contents.width * 0.00000 + 0.5), contents.minY + floor(contents.height * 0.60276 + 0.5), floor(contents.width * 0.05919 + 0.5) - floor(contents.width * 0.00000 + 0.5), floor(contents.height * 0.65976 + 0.5) - floor(contents.height * 0.60276 + 0.5))
        let yaxis40labelTextContent = NSString(string: "40")
        let yaxis40labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        yaxis40labelStyle.alignment = .Right
        
        let yaxis40labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: yaxis40labelStyle]
        
        let yaxis40labelTextHeight: CGFloat = yaxis40labelTextContent.boundingRectWithSize(CGSizeMake(yaxis40labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: yaxis40labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, yaxis40labelRect);
        yaxis40labelTextContent.drawInRect(CGRectMake(yaxis40labelRect.minX, yaxis40labelRect.minY + (yaxis40labelRect.height - yaxis40labelTextHeight) / 2, yaxis40labelRect.width, yaxis40labelTextHeight), withAttributes: yaxis40labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// hour-5-label Drawing
        let hour5labelRect = CGRectMake(contents.minX + floor(contents.width * 0.82087 + 0.5), contents.minY + floor(contents.height * 0.00000 + 0.5), floor(contents.width * 0.88941 + 0.5) - floor(contents.width * 0.82087 + 0.5), floor(contents.height * 0.05699 + 0.5) - floor(contents.height * 0.00000 + 0.5))
        let hour5labelTextContent = NSString(string: "12 p")
        let hour5labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hour5labelStyle.alignment = .Center
        
        let hour5labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hour5labelStyle]
        
        let hour5labelTextHeight: CGFloat = hour5labelTextContent.boundingRectWithSize(CGSizeMake(hour5labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: hour5labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, hour5labelRect);
        hour5labelTextContent.drawInRect(CGRectMake(hour5labelRect.minX, hour5labelRect.minY + (hour5labelRect.height - hour5labelTextHeight) / 2, hour5labelRect.width, hour5labelTextHeight), withAttributes: hour5labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// hour-4-label Drawing
        let hour4labelRect = CGRectMake(contents.minX + floor(contents.width * 0.63084 + 0.5), contents.minY + floor(contents.height * 0.00000 + 0.5), floor(contents.width * 0.69938 + 0.5) - floor(contents.width * 0.63084 + 0.5), floor(contents.height * 0.05699 + 0.5) - floor(contents.height * 0.00000 + 0.5))
        let hour4labelTextContent = NSString(string: "11 a")
        let hour4labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hour4labelStyle.alignment = .Center
        
        let hour4labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hour4labelStyle]
        
        let hour4labelTextHeight: CGFloat = hour4labelTextContent.boundingRectWithSize(CGSizeMake(hour4labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: hour4labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, hour4labelRect);
        hour4labelTextContent.drawInRect(CGRectMake(hour4labelRect.minX, hour4labelRect.minY + (hour4labelRect.height - hour4labelTextHeight) / 2, hour4labelRect.width, hour4labelTextHeight), withAttributes: hour4labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// hour-3-label Drawing
        let hour3labelRect = CGRectMake(contents.minX + floor(contents.width * 0.46417 + 0.5), contents.minY + floor(contents.height * 0.00000 + 0.5), floor(contents.width * 0.53271 + 0.5) - floor(contents.width * 0.46417 + 0.5), floor(contents.height * 0.05699 + 0.5) - floor(contents.height * 0.00000 + 0.5))
        let hour3labelTextContent = NSString(string: "10 a")
        let hour3labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hour3labelStyle.alignment = .Center
        
        let hour3labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hour3labelStyle]
        
        let hour3labelTextHeight: CGFloat = hour3labelTextContent.boundingRectWithSize(CGSizeMake(hour3labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: hour3labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, hour3labelRect);
        hour3labelTextContent.drawInRect(CGRectMake(hour3labelRect.minX, hour3labelRect.minY + (hour3labelRect.height - hour3labelTextHeight) / 2, hour3labelRect.width, hour3labelTextHeight), withAttributes: hour3labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// hour-2-label Drawing
        let hour2labelRect = CGRectMake(contents.minX + floor(contents.width * 0.29128 + 0.5), contents.minY + floor(contents.height * 0.00000 + 0.5), floor(contents.width * 0.35981 + 0.5) - floor(contents.width * 0.29128 + 0.5), floor(contents.height * 0.05699 + 0.5) - floor(contents.height * 0.00000 + 0.5))
        let hour2labelTextContent = NSString(string: "9 a")
        let hour2labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hour2labelStyle.alignment = .Center
        
        let hour2labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hour2labelStyle]
        
        let hour2labelTextHeight: CGFloat = hour2labelTextContent.boundingRectWithSize(CGSizeMake(hour2labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: hour2labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, hour2labelRect);
        hour2labelTextContent.drawInRect(CGRectMake(hour2labelRect.minX, hour2labelRect.minY + (hour2labelRect.height - hour2labelTextHeight) / 2, hour2labelRect.width, hour2labelTextHeight), withAttributes: hour2labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// hour-1-label Drawing
        let hour1labelRect = CGRectMake(contents.minX + floor(contents.width * 0.12773 + 0.5), contents.minY + floor(contents.height * 0.00000 + 0.5), floor(contents.width * 0.19626 + 0.5) - floor(contents.width * 0.12773 + 0.5), floor(contents.height * 0.05699 + 0.5) - floor(contents.height * 0.00000 + 0.5))
        let hour1labelTextContent = NSString(string: "8 a")
        let hour1labelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hour1labelStyle.alignment = .Center
        
        let hour1labelFontAttributes = [NSFontAttributeName: UIFont(name: "OpenSans", size: 10)!, NSForegroundColorAttributeName: axisTextColor, NSParagraphStyleAttributeName: hour1labelStyle]
        
        let hour1labelTextHeight: CGFloat = hour1labelTextContent.boundingRectWithSize(CGSizeMake(hour1labelRect.width, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: hour1labelFontAttributes, context: nil).size.height
        CGContextSaveGState(context)
        CGContextClipToRect(context, hour1labelRect);
        hour1labelTextContent.drawInRect(CGRectMake(hour1labelRect.minX, hour1labelRect.minY + (hour1labelRect.height - hour1labelTextHeight) / 2, hour1labelRect.width, hour1labelTextHeight), withAttributes: hour1labelFontAttributes)
        CGContextRestoreGState(context)
        
        
        //// hour-5-marker Drawing
        let hour5markerPath = UIBezierPath()
        hour5markerPath.moveToPoint(CGPointMake(contents.minX + 0.85518 * contents.width, contents.minY + 0.06377 * contents.height))
        hour5markerPath.addLineToPoint(CGPointMake(contents.minX + 0.85518 * contents.width, contents.minY + 0.09199 * contents.height))
        hour5markerPath.miterLimit = 4;
        
        hour5markerPath.lineCapStyle = .Square;
        
        hour5markerPath.usesEvenOddFillRule = true;
        
        hourMarkerStrokeColor.setStroke()
        hour5markerPath.lineWidth = 1
        hour5markerPath.stroke()
        
        
        //// hour-4-marker Drawing
        let hour4markerPath = UIBezierPath()
        hour4markerPath.moveToPoint(CGPointMake(contents.minX + 0.66612 * contents.width, contents.minY + 0.06377 * contents.height))
        hour4markerPath.addLineToPoint(CGPointMake(contents.minX + 0.66612 * contents.width, contents.minY + 0.09199 * contents.height))
        hour4markerPath.miterLimit = 4;
        
        hour4markerPath.lineCapStyle = .Square;
        
        hour4markerPath.usesEvenOddFillRule = true;
        
        hourMarkerStrokeColor.setStroke()
        hour4markerPath.lineWidth = 1
        hour4markerPath.stroke()
        
        
        //// hour-3-marker Drawing
        let hour3markerPath = UIBezierPath()
        hour3markerPath.moveToPoint(CGPointMake(contents.minX + 0.50049 * contents.width, contents.minY + 0.06718 * contents.height))
        hour3markerPath.addLineToPoint(CGPointMake(contents.minX + 0.50049 * contents.width, contents.minY + 0.09539 * contents.height))
        hour3markerPath.miterLimit = 4;
        
        hour3markerPath.lineCapStyle = .Square;
        
        hour3markerPath.usesEvenOddFillRule = true;
        
        hourMarkerStrokeColor.setStroke()
        hour3markerPath.lineWidth = 1
        hour3markerPath.stroke()
        
        
        //// hour-2-marker Drawing
        let hour2markerPath = UIBezierPath()
        hour2markerPath.moveToPoint(CGPointMake(contents.minX + 0.32549 * contents.width, contents.minY + 0.06377 * contents.height))
        hour2markerPath.addLineToPoint(CGPointMake(contents.minX + 0.32549 * contents.width, contents.minY + 0.09199 * contents.height))
        hour2markerPath.miterLimit = 4;
        
        hour2markerPath.lineCapStyle = .Square;
        
        hour2markerPath.usesEvenOddFillRule = true;
        
        hourMarkerStrokeColor.setStroke()
        hour2markerPath.lineWidth = 1
        hour2markerPath.stroke()
        
        
        //// hour-1-marker Drawing
        let hour1markerPath = UIBezierPath()
        hour1markerPath.moveToPoint(CGPointMake(contents.minX + 0.16143 * contents.width, contents.minY + 0.06377 * contents.height))
        hour1markerPath.addLineToPoint(CGPointMake(contents.minX + 0.16143 * contents.width, contents.minY + 0.09199 * contents.height))
        hour1markerPath.miterLimit = 4;
        
        hour1markerPath.lineCapStyle = .Square;
        
        hour1markerPath.usesEvenOddFillRule = true;
        
        hourMarkerStrokeColor.setStroke()
        hour1markerPath.lineWidth = 1
        hour1markerPath.stroke()
    }

    private func drawHealthEvent(eventWidth eventWidth: CGFloat, imageHeight: CGFloat) {
        
        //// Frames
        let frame = CGRectMake(0, 0, eventWidth, imageHeight)
        let healthRectHeight: CGFloat = 18.0
        
        //// eventRectangle Drawing
        let eventRectanglePath = UIBezierPath(rect: CGRectMake(0.0, frame.height - healthRectHeight, frame.width, healthRectHeight))
        Styles.pinkColor.setFill()
        eventRectanglePath.fill()
        
        
        //// eventLine Drawing
        let eventLinePath = UIBezierPath(rect: CGRectMake(floor(frame.width * 0.5 - 0.5) + 1.0, 0.0, 1.0, frame.height))
        Styles.pinkColor.setFill()
        eventLinePath.fill()
    }

    private func drawGlucoseData(cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)]) {
        //// General Declarations
        
        let pixelsPerValue: CGFloat = yPixelsGlucose/kGlucoseRange
        let circleRadius: CGFloat = 5.0
        
        let highColor = Styles.purpleColor
        let targetColor = Styles.greenColor
        let lowColor = Styles.peachColor
        let highBoundary: NSNumber = 180.0
        let lowBoundary: NSNumber = 90.0
        var lowValue: CGFloat = kGlucoseRange
        var highValue: CGFloat = 0.0
        
        for item in cbgData {
            let centerX: CGFloat = floor(CGFloat(item.0) * viewPixelsPerSec)
            var value = round(CGFloat(item.1) * kGlucoseConversionToMgDl)
            if value > kGlucoseRange {
                value = kGlucoseRange
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
        }
        print("\(cbgData.count) cbg events, low: \(lowValue) high: \(highValue)")
    }
   
}
