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

class GraphCursorLayer: GraphDataLayer {
    // Time offset of cursor within this layer, if it falls here
    var cursorTimeOffset: TimeInterval?
    let kCursorTriangleTopWidth: CGFloat = 15.5

    init(viewSize: CGSize, timeIntervalForView: TimeInterval, startTime: Date, cursorTime: Date) {
        super.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime)

        let timeToCursor = cursorTime.timeIntervalSince(startTime)
        let timeExtensionForViewWidth = TimeInterval(kCursorTriangleTopWidth/viewPixelsPerSec)
        if timeToCursor > -timeExtensionForViewWidth && timeToCursor < timeIntervalForView + timeExtensionForViewWidth {
            // cursor calls within this slice
            cursorTimeOffset = timeToCursor
        }
    }

    func imageView(_ cursorColor: UIColor) -> UIImageView? {
        if let cursorTimeOffset = cursorTimeOffset {
            UIGraphicsBeginImageContextWithOptions(cellViewSize, false, 0)
            
            let xOffset: CGFloat = floor(CGFloat(cursorTimeOffset) * viewPixelsPerSec)
            drawCursorAtOffset(xOffset, cursorColor: cursorColor)
            
            let imageOfLayerData = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return UIImageView(image:imageOfLayerData)
        } else {
            return nil
        }
    }
    
    fileprivate func drawCursorAtOffset(_ xOffset: CGFloat, cursorColor: UIColor) {
        // eventLine Drawing
        let lineHeight: CGFloat = self.cellViewSize.height
        let lineWidth: CGFloat = 2.0
        
        let rect = CGRect(x: xOffset - lineWidth/2, y: 0, width: lineWidth, height: lineHeight)
        let eventLinePath = UIBezierPath(rect: rect)
        cursorColor.setFill()
        eventLinePath.fill()
        
        let trianglePath = UIBezierPath()
        let centerX = rect.origin.x + lineWidth/2.0
        let triangleSize: CGFloat = kCursorTriangleTopWidth
        let triangleOrgX = centerX - triangleSize/2.0
        trianglePath.move(to: CGPoint(x: triangleOrgX, y: 0.0))
        trianglePath.addLine(to: CGPoint(x: triangleOrgX + triangleSize, y: 0.0))
        trianglePath.addLine(to: CGPoint(x: triangleOrgX + triangleSize/2.0, y: 13.5))
        trianglePath.addLine(to: CGPoint(x: triangleOrgX, y: 0))
        trianglePath.close()
        trianglePath.miterLimit = 4;
        trianglePath.usesEvenOddFillRule = true;
        cursorColor.setFill()
        trianglePath.fill()
    }

}
