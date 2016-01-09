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

/// Used for drawing within a graph view: handles the background, y-axis and x-axis drawing, and provides drawing methods that can be used to draw labels, circles, etc.
/// Note: an overall graph composed of multiple collection view cells would have a separate GraphingUtils object for each cell. 
public class GraphingUtils {
    
    var layout: GraphLayout
    /// viewSize is set at init, and can be updated via updateViewSize later, changing viewPixelsPerSec
    var viewSize: CGSize
    var viewPixelsPerSec: CGFloat = 0.0
    /// timeIntervalForView and startTime are invariant.
    var timeIntervalForView: NSTimeInterval
    var startTime: NSDate
    //

    //
    // MARK: - Interface
    //
    
    init(layout: GraphLayout, timeIntervalForView: NSTimeInterval, startTime: NSDate) {
        self.layout = layout
        self.viewSize = layout.cellViewSize
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.configureGraphParameters()
    }
    
    func updateViewSize(newSize: CGSize) {
        self.viewSize = newSize
        self.configureGraphParameters()
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

    //
    // MARK: - Private methods
    //

    private func configureGraphParameters() {
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
        // calculate the extra time we need data fetched for at the end of the graph time span so we draw the beginnings of next graph items
    }

    // TODO: generalize so it can be shared!
    private func drawDashedHorizontalLine(start: CGPoint, length: CGFloat, lineWidth: CGFloat) {
        let context = UIGraphicsGetCurrentContext()
        let yAxisLinePath = UIBezierPath()
        yAxisLinePath.moveToPoint(start)
        yAxisLinePath.addLineToPoint(CGPoint(x: start.x + length, y: start.y))
        yAxisLinePath.miterLimit = 4;
        yAxisLinePath.lineCapStyle = .Square;
        yAxisLinePath.lineJoinStyle = .Round;
        yAxisLinePath.usesEvenOddFillRule = true;
        
        layout.yAxisLineColor.setStroke()
        yAxisLinePath.lineWidth = lineWidth
        CGContextSaveGState(context)
        CGContextSetLineDash(context, 0, [2, 5], 2)
        yAxisLinePath.stroke()
        CGContextRestoreGState(context)
    }

    // TODO: generalize so it can be shared!
    private func drawLabelLeftOfPoint(label: String, rightCenter: CGPoint, font: UIFont, color: UIColor) {
        let alignRightStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        alignRightStyle.alignment = .Right
        let labelFontAttributes = [NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: alignRightStyle]
        
        let textSize = label.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: labelFontAttributes, context: nil).size
        let textHeight = ceil(textSize.height)
        let textWidth = ceil(textSize.width)
        let labelRect = CGRect(x: (rightCenter.x - textWidth), y: rightCenter.y-textHeight/2.0, width: textWidth, height: textHeight)
        
        let context = UIGraphicsGetCurrentContext()
        CGContextSaveGState(context)
        CGContextClipToRect(context, labelRect);
        label.drawInRect(labelRect, withAttributes: labelFontAttributes)
        CGContextRestoreGState(context)
    }

    private func drawFixedGraphBackground() {
        
        //
        //  Draw the background block
        //
        let graphHeaderHeight = layout.headerHeight
        let backgroundBlockRect = CGRect(x: 0.0, y: graphHeaderHeight, width: viewSize.width, height: viewSize.height - graphHeaderHeight)
        let backgroundPath = UIBezierPath(rect: backgroundBlockRect)
        layout.backgroundColor.setFill()
        backgroundPath.fill()
        
        //
        //  Draw the Y-axis labels and lines...
        //
        
        let yAxisBase = layout.yAxisBase
        let pixelsPerValue: CGFloat = layout.yAxisPixels/layout.yAxisRange
        
        let yAxisLineLeftMargin = layout.yAxisLineLeftMargin
        for yAxisLine in layout.yAxisValuesWithLines {
            let yOffset = round(yAxisBase - (CGFloat(yAxisLine) * pixelsPerValue))
            self.drawDashedHorizontalLine(CGPoint(x: yAxisLineLeftMargin, y: yOffset), length: viewSize.width - layout.yAxisLineRightMargin - yAxisLineLeftMargin, lineWidth: 1.5)
        }
        
        for label in layout.yAxisValuesWithLabels {
            let yOffset = round(yAxisBase - (CGFloat(label) * pixelsPerValue))
            drawLabelLeftOfPoint(String(label), rightCenter: CGPoint(x: yAxisLineLeftMargin, y: yOffset), font: layout.axesLabelTextFont, color: layout.axesLabelTextColor)
        }
    }

    private let kHourInSecs:NSTimeInterval = 3600.0
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
            
            layout.hourMarkerStrokeColor.setStroke()
            hourMarkerPath.lineWidth = 1
            hourMarkerPath.stroke()
        }
        
        func drawHourLabel(hourStr: String, topCenter: CGPoint, midnight: Bool) {
            
            let hourlabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            hourlabelStyle.alignment = .Left
            
            let labelAttrStr = NSMutableAttributedString(string: hourStr, attributes: [NSFontAttributeName: Styles.smallRegularFont, NSForegroundColorAttributeName: layout.axesLabelTextColor, NSParagraphStyleAttributeName: hourlabelStyle])
            
            if !midnight {
                // Make " a" or " p" lighter
                labelAttrStr.addAttribute(NSFontAttributeName, value: Styles.smallLightFont, range: NSRange(location: labelAttrStr.length - 2, length: 2))
            }
            
            var sizeNeeded = labelAttrStr.boundingRectWithSize(CGSizeMake(CGFloat.infinity, CGFloat.infinity), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil).size
            sizeNeeded = CGSize(width: ceil(sizeNeeded.width), height: ceil(sizeNeeded.height))
            
            let originX = midnight ? topCenter.x + 4.0 : topCenter.x - sizeNeeded.width/2.0
            let labelRect = CGRect(x: originX, y: 6.0, width: sizeNeeded.width, height: sizeNeeded.height)
            // skip label draw if we would overwrite previous label
            if (!lastLabelDrawn.intersects(labelRect)) {
                labelAttrStr.drawInRect(labelRect)
                lastLabelDrawn = labelRect
            } else {
                NSLog("skipping x axis label")
            }
        }
        
        let df = NSDateFormatter()
        df.dateFormat = "h a"
        let hourlabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        hourlabelStyle.alignment = .Center
        
        // Draw times a little early and going to a little later so collection views overlap correctly
        let timeExtensionForDataFetch = NSTimeInterval(layout.largestXAxisDateWidth/viewPixelsPerSec)
        let earlyStartTime = graphStartSecs - timeExtensionForDataFetch
        let lateEndLocation = layout.largestXAxisDateWidth
        
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
            let markerLength = midnight ? layout.headerHeight : 8.0
            let markerStart = CGPointMake(viewXOffset, layout.headerHeight - markerLength)
            drawHourMarker(markerStart, length: markerLength)
            
            // draw hour label
            drawHourLabel(hourStr, topCenter: CGPoint(x: viewXOffset, y: 6.0), midnight: midnight)
            
            curDate = curDate.dateByAddingTimeInterval(kHourInSecs)
            viewXOffset += pixelsPerHour
            
        } while (viewXOffset < viewSize.width + lateEndLocation)
    }

}
