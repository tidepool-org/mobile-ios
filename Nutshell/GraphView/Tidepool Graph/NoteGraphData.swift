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

class NoteGraphDataType: GraphDataType {
    
    var isMainEvent: Bool = false
    var id: String?
    var rectInGraph: CGRect = CGRect.zero
    
    init(timeOffset: TimeInterval, isMain: Bool, event: BlipNote) {
        self.isMainEvent = isMain
        // id needed if user taps on this item...
        self.id = event.id
        super.init(timeOffset: timeOffset)
    }
    
    override func typeString() -> String {
        return "note"
    }

}

class NoteGraphDataLayer: GraphDataLayer {

    var layout: TidepoolGraphLayout
    
    init(viewSize: CGSize, timeIntervalForView: TimeInterval, startTime: Date, layout: TidepoolGraphLayout) {
        self.layout = layout
        super.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime)
    }

    // Note config constants
    let kNoteLineColor = Styles.blackColor
    let kNoteTriangleColor = Styles.darkPurpleColor
    let kOtherNoteColor = UIColor(hex: 0x948ca3)
    let kNoteTriangleTopWidth: CGFloat = 15.5

    //
    // MARK: - Loading data
    //

    override func loadDataItems() {
        dataArray = []
        let timeExtensionForDataFetch = TimeInterval(kNoteTriangleTopWidth/viewPixelsPerSec)
        let earlyStartTime = startTime.addingTimeInterval(-timeExtensionForDataFetch)
        let endTimeInterval = timeIntervalForView + timeExtensionForDataFetch + TimeInterval(kNoteTriangleTopWidth/viewPixelsPerSec)
        if let notes = NutDataController.sharedInstance.currentNotes {
            for noteEvent in notes {
                let eventTime = noteEvent.timestamp
                let timeSinceEarlyStart = eventTime.timeIntervalSince(earlyStartTime)
                if timeSinceEarlyStart <= endTimeInterval {
                    let deltaTime = eventTime.timeIntervalSince(startTime)
                    var isMainEvent = false
                    isMainEvent = noteEvent.timestamp == layout.mainEventTime
                    dataArray.append(NoteGraphDataType(timeOffset: deltaTime, isMain: isMainEvent, event: noteEvent))
                }
            }
        }
        
    }
 
    //
    // MARK: - Drawing data points
    //

    override func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
        
        var isMain = false
        if let noteDataType = dataPoint as? NoteGraphDataType {
            isMain = noteDataType.isMainEvent

            // eventLine Drawing
            let lineColor = isMain ? kNoteLineColor : kOtherNoteColor
            let triangleColor = isMain ? kNoteTriangleColor : kOtherNoteColor
            let lineHeight: CGFloat = isMain ? layout.yBottomOfMeal - layout.yTopOfMeal : layout.headerHeight
            let lineWidth: CGFloat = isMain ? 2.0 : 1.0
            
            let rect = CGRect(x: xOffset, y: layout.yTopOfMeal, width: lineWidth, height: lineHeight)
            let eventLinePath = UIBezierPath(rect: rect)
            lineColor.setFill()
            eventLinePath.fill()
            
            let trianglePath = UIBezierPath()
            let centerX = rect.origin.x + lineWidth/2.0
            let triangleSize: CGFloat = kNoteTriangleTopWidth
            let triangleOrgX = centerX - triangleSize/2.0
            trianglePath.move(to: CGPoint(x: triangleOrgX, y: 0.0))
            trianglePath.addLine(to: CGPoint(x: triangleOrgX + triangleSize, y: 0.0))
            trianglePath.addLine(to: CGPoint(x: triangleOrgX + triangleSize/2.0, y: 13.5))
            trianglePath.addLine(to: CGPoint(x: triangleOrgX, y: 0))
            trianglePath.close()
            trianglePath.miterLimit = 4;
            trianglePath.usesEvenOddFillRule = true;
            triangleColor.setFill()
            trianglePath.fill()
            
            if !isMain {
                let noteHitAreaWidth: CGFloat = max(triangleSize, 30.0)
                let noteRect = CGRect(x: centerX - noteHitAreaWidth/2.0, y: 0.0, width: noteHitAreaWidth, height: lineHeight)
                noteDataType.rectInGraph = noteRect
            }
        }
    }
    
    // override to handle taps - return true if tap has been handled
    override func tappedAtPoint(_ point: CGPoint) -> GraphDataType? {
        for dataPoint in dataArray {
            if let noteDataPoint = dataPoint as? NoteGraphDataType {
                if noteDataPoint.rectInGraph.contains(point) {
                    return noteDataPoint
                }
            }
        }
        return nil
    }

}
