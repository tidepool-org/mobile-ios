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

public class GraphingUtils {
    
    var layout: GraphLayout
    var viewSize: CGSize
    var timeIntervalForView: NSTimeInterval
    var startTime: NSDate
    //
    private var viewPixelsPerSec: CGFloat = 0.0

    //
    // MARK: - Interface
    //
    
    init(layout: GraphLayout, timeIntervalForView: NSTimeInterval, startTime: NSDate) {
        self.layout = layout
        self.viewSize = layout.viewSize
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

    //
    // MARK: - Private methods
    //

    private func configureGraphParameters() {
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
    }

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

}
