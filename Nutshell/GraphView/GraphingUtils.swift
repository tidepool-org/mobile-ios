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
open class GraphingUtils {
    
    var layout: GraphLayout
    /// viewSize is set at init, and can be updated via updateViewSize later, changing viewPixelsPerSec
    var viewSize: CGSize
    var viewPixelsPerSec: CGFloat = 0.0
    /// timeIntervalForView and startTime are invariant.
    var timeIntervalForView: TimeInterval
    var startTime: Date
    //
    
    //
    // MARK: - Interface
    //
    
    init(layout: GraphLayout, timeIntervalForView: TimeInterval, startTime: Date, viewSize: CGSize) {
        self.layout = layout
        self.viewSize = viewSize
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.configureGraphParameters()
    }
    
    func updateViewSize(_ newSize: CGSize) {
        self.viewSize = newSize
        self.configureGraphParameters()
    }
    
    func imageOfFixedGraphBackground() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawFixedGraphBackground()
        
        let imageOfFixedGraphBackground = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfFixedGraphBackground!
    }
    
    func imageOfXAxisHeader() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        drawXAxisHeader()
        
        let imageOfGraphBackground = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageOfGraphBackground
    }

    // TODO: Put in a more appropriate place?
    func timeIntervalToString(_ interval: TimeInterval) -> String {
        var time = Int(interval)
        let runSeconds = time % 60
        time /= 60
        let runMinutes = time % 60
        let runHours = time/60
        var timeStr = String(format: "%02d", runMinutes) + ":" + String(format: "%02d", runSeconds)
        if runHours > 0 {
            timeStr = String(format: "%01d", runHours) + ":" + timeStr
        }
        return timeStr
    }
    
    //
    // MARK: - Private methods
    //
    
    fileprivate func configureGraphParameters() {
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
        // calculate the extra time we need data fetched for at the end of the graph time span so we draw the beginnings of next graph items
    }
    
    // TODO: generalize so it can be shared!
    fileprivate func drawDashedHorizontalLine(_ start: CGPoint, length: CGFloat, lineWidth: CGFloat) {
        if let context = UIGraphicsGetCurrentContext() {
            let yAxisLinePath = UIBezierPath()
            yAxisLinePath.move(to: start)
            yAxisLinePath.addLine(to: CGPoint(x: start.x + length, y: start.y))
            yAxisLinePath.miterLimit = 4;
            yAxisLinePath.lineCapStyle = .square;
            yAxisLinePath.lineJoinStyle = .round;
            yAxisLinePath.usesEvenOddFillRule = true;
            
            layout.yAxisLineColor.setStroke()
            yAxisLinePath.lineWidth = lineWidth
            context.saveGState()
            context.setLineDash(phase: 0, lengths: [2, 5])
            yAxisLinePath.stroke()
            context.restoreGState()
        }
    }
    
    // TODO: generalize so it can be shared!
    fileprivate func drawLabelLeftOfPoint(_ label: String, rightCenter: CGPoint, font: UIFont, color: UIColor) {
        let alignRightStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        alignRightStyle.alignment = .right
        let labelFontAttributes = [NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: alignRightStyle]
        
        let textSize = label.boundingRect(with: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: labelFontAttributes, context: nil).size
        let textHeight = ceil(textSize.height)
        let textWidth = ceil(textSize.width)
        let labelRect = CGRect(x: (rightCenter.x - textWidth), y: rightCenter.y-textHeight/2.0, width: textWidth, height: textHeight)
        
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            context.clip(to: labelRect);
            label.draw(in: labelRect, withAttributes: labelFontAttributes)
            context.restoreGState()
        }
    }
    
    fileprivate func measureText(_ label: String, font: UIFont) -> CGSize {
        let textSize = label.boundingRect(with: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSFontAttributeName: font], context: nil).size
        return textSize
    }
    
    func drawLabelRightOfPoint(_ label: String, leftCenter: CGPoint, font: UIFont, color: UIColor) {
        let alignLeftStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        alignLeftStyle.alignment = .right
        let labelFontAttributes = [NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: alignLeftStyle]
        
        let textSize = label.boundingRect(with: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: labelFontAttributes, context: nil).size
        let textHeight = ceil(textSize.height)
        let textWidth = ceil(textSize.width)
        
        var labelRect = CGRect(x: leftCenter.x, y: leftCenter.y-textHeight/2.0, width: textWidth, height: textHeight)
        // don't go below bottom or above top of graph
        if labelRect.maxY > layout.graphViewSize.height {
            labelRect.origin.y = layout.graphViewSize.height - labelRect.height
        }
        if labelRect.minY < 0.0 {
            labelRect.origin.y = 0.0
        }
        
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            context.clip(to: labelRect);
            label.draw(in: labelRect, withAttributes: labelFontAttributes)
            context.restoreGState()
        }
    }
    
    /// Draws y-axis labels on left, and dashed lines at various y offsets.
    /// Override for more control over background.
    func drawFixedGraphBackground() {
        
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
        
        var maxRightLabelWidth: CGFloat = 0.0
        for label in layout.yAxisValuesWithRightEdgeLabels {
            let labelWidth = measureText(String(label), font: layout.axesLabelTextFont).width
            if labelWidth > maxRightLabelWidth {
                maxRightLabelWidth = labelWidth
            }
        }
        
        let lineLabelGap: CGFloat = 4.0
        let yAxisLineLeftMargin = layout.yAxisLineLeftMargin
        for yAxisLine in layout.yAxisValuesWithLines {
            let yOffset = round(yAxisBase - (CGFloat(yAxisLine) * pixelsPerValue))
            self.drawDashedHorizontalLine(CGPoint(x: yAxisLineLeftMargin, y: yOffset), length: viewSize.width - layout.yAxisLineRightMargin - yAxisLineLeftMargin - maxRightLabelWidth - lineLabelGap, lineWidth: 1.5)
        }
        
        for label in layout.yAxisValuesWithLabels {
            let yOffset = round(yAxisBase - (CGFloat(label) * pixelsPerValue))
            drawLabelLeftOfPoint(String(label), rightCenter: CGPoint(x: yAxisLineLeftMargin - lineLabelGap, y: yOffset), font: layout.axesLabelTextFont, color: layout.axesLeftLabelTextColor)
        }
        
        for label in layout.yAxisValuesWithRightEdgeLabels {
            let rightAxisPixelsPerValue = layout.yAxisPixels/layout.yAxisRightRange
            let valueAdjustedForBase = CGFloat(label) - layout.yAxisRightBase
            let yOffset = round(layout.yAxisBase - (valueAdjustedForBase * rightAxisPixelsPerValue))
            // TODO: 4.0 is to leave a little gap between the line and the label...
            drawLabelRightOfPoint(String(label), leftCenter: CGPoint(x: viewSize.width - layout.yAxisLineRightMargin - maxRightLabelWidth, y: yOffset), font: layout.axesLabelTextFont, color: layout.axesRightLabelTextColor)
        }
    }
    

    fileprivate let kHourInSecs:TimeInterval = 3600.0
    fileprivate func drawXAxisHeader() {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()
        layout.figureXAxisTickTiming()
        let tickTiming = layout.curXAxisLabelTickTiming
        
        //// Frames - use whole view for background
        let contents = CGRect(x: 0, y: 0, width: viewSize.width, height: viewSize.height)
        var graphStartSecs = startTime.timeIntervalSinceReferenceDate
        if layout.useRelativeTimes {
            graphStartSecs = startTime.timeIntervalSince(layout.graphStartTime as Date)
        }
        let pixelsPerTick = CGFloat(tickTiming) * viewPixelsPerSec
        
        // Remember last label rect so we don't overwrite previous...
        var lastLabelDrawn = CGRect.null
        
        //
        //  Draw the X-axis header...
        //
        
        func drawHourMarker(_ start: CGPoint, length: CGFloat) {
            let hourMarkerPath = UIBezierPath()
            hourMarkerPath.move(to: start)
            hourMarkerPath.addLine(to: CGPoint(x: start.x, y: start.y + length))
            hourMarkerPath.miterLimit = 4;
            
            hourMarkerPath.lineCapStyle = .square;
            
            hourMarkerPath.usesEvenOddFillRule = true;
            
            layout.hourMarkerStrokeColor.setStroke()
            hourMarkerPath.lineWidth = 1
            hourMarkerPath.stroke()
        }
        
        func drawHourLabel(_ timeStr: String, topCenter: CGPoint, lightenLastLetter: Bool = false, leftAlignLabel: Bool = false) {
            
            let hourlabelStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            hourlabelStyle.alignment = .left
            
            let labelAttrStr = NSMutableAttributedString(string: timeStr, attributes: [NSFontAttributeName: layout.xLabelRegularFont, NSForegroundColorAttributeName: layout.axesLabelTextColor, NSParagraphStyleAttributeName: hourlabelStyle])
            
            if lightenLastLetter {
                // Make " a" or " p" lighter
                labelAttrStr.addAttribute(NSFontAttributeName, value: layout.xLabelLightFont, range: NSRange(location: labelAttrStr.length - 2, length: 2))
            }
            
            var sizeNeeded = labelAttrStr.boundingRect(with: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil).size
            sizeNeeded = CGSize(width: ceil(sizeNeeded.width), height: ceil(sizeNeeded.height))
            
            let originX = leftAlignLabel ? topCenter.x + 4.0 : topCenter.x - sizeNeeded.width/2.0
            let labelRect = CGRect(x: originX, y: 6.0, width: sizeNeeded.width, height: sizeNeeded.height)
            // skip label draw if we would overwrite previous label
            if (!lastLabelDrawn.intersects(labelRect)) {
                labelAttrStr.draw(in: labelRect)
                lastLabelDrawn = lastLabelDrawn.union(labelRect)
            } else {
                //NSLog("skipping x axis label")
            }
        }
        
        // Draw times a little early and going to a little later so collection views overlap correctly
        let timeExtensionForDataFetch = TimeInterval(layout.largestXAxisDateWidth/viewPixelsPerSec)
        let earlyStartTime = graphStartSecs - timeExtensionForDataFetch
        let lateEndLocation = layout.largestXAxisDateWidth
        
        var nextTickBoundarySecs = floor(earlyStartTime / tickTiming) * tickTiming
        let timeOffset: TimeInterval = nextTickBoundarySecs - graphStartSecs
        var viewXOffset = floor(CGFloat(timeOffset) * viewPixelsPerSec)
        
        if layout.useRelativeTimes {
            
            repeat {
                
                if nextTickBoundarySecs > 0 {
                    let timeStr = timeIntervalToString(nextTickBoundarySecs)
                    // draw marker
                    let markerLength: CGFloat = 8.0
                    let markerStart = CGPoint(x: viewXOffset, y: layout.headerHeight - markerLength)
                    //NSLog("time marker \(timeStr) at x offset: \(markerStart.x)")
                    
                    drawHourMarker(markerStart, length: markerLength)
                    // draw hour label
                    drawHourLabel(timeStr, topCenter: CGPoint(x: viewXOffset, y: 6.0))
                }
                
                nextTickBoundarySecs += tickTiming
                viewXOffset += pixelsPerTick
                
            } while (viewXOffset < viewSize.width + lateEndLocation)
            
        } else {
            let df = DateFormatter()
            df.dateFormat = "h:mm a"
            df.timeZone = TimeZone(secondsFromGMT: layout.timezoneOffsetSecs)
            var curDate = Date(timeIntervalSinceReferenceDate:nextTickBoundarySecs)
            
            repeat {
                
                var timeStr = df.string(from: curDate)
                // Replace uppercase PM and AM with lowercase versions
                timeStr = timeStr.replacingOccurrences(of: "PM", with: "p", options: NSString.CompareOptions.literal, range: nil)
                timeStr = timeStr.replacingOccurrences(of: "AM", with: "a", options: NSString.CompareOptions.literal, range: nil)
                timeStr = timeStr.replacingOccurrences(of: ":00", with: "", options: NSString.CompareOptions.literal, range: nil)
                
                // TODO: don't overwrite this date with 1a, 2a, etc depending upon its length
                var midnight = false
                if timeStr == "12 a" || timeStr == "00" {
                    midnight = true
                    //NutUtils.setFormatterTimezone(layout.timezoneOffsetSecs)
                    //timeStr = NutUtils.standardUIDayString(curDate)
                }
                
                // draw marker
                let markerLength = midnight ? layout.headerHeight : 8.0
                let markerStart = CGPoint(x: viewXOffset, y: layout.headerHeight - markerLength)
                drawHourMarker(markerStart, length: markerLength)
                
                // draw hour label
                if midnight {
                    drawHourLabel(timeStr, topCenter: CGPoint(x: viewXOffset, y: 6.0), lightenLastLetter: false, leftAlignLabel: true)
                } else {
                    drawHourLabel(timeStr, topCenter: CGPoint(x: viewXOffset, y: 6.0), lightenLastLetter: true)
                }
                
                curDate = curDate.addingTimeInterval(tickTiming)
                viewXOffset += pixelsPerTick
                
            } while (viewXOffset < viewSize.width + lateEndLocation)
            
        }
        
    }
    
}
