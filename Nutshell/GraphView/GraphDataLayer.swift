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

class GraphDataLayer {
    // size in pixels and time for this layer
    var cellViewSize: CGSize = CGSize.zero
    var timeIntervalForView: TimeInterval
    var startTime: Date

    // dataPoint array, configured later by GraphDataSource
    var dataArray: [GraphDataType] = []

    // useful variables for subclasses and data source
    var viewPixelsPerSec: CGFloat = 0.0

    init(viewSize: CGSize, timeIntervalForView: TimeInterval, startTime: Date) {
        self.cellViewSize = viewSize
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
    }

    func updateViewSize(_ newSize: CGSize) {
        self.cellViewSize = newSize
        self.viewPixelsPerSec = newSize.width/CGFloat(timeIntervalForView)
    }
    
    /// Override point for case where GraphDataLayer handles data loading.
    func loadDataItems() {
    }

    func imageView() -> UIImageView? {
        if dataArray.count == 0 {
            return nil
        }
        UIGraphicsBeginImageContextWithOptions(cellViewSize, false, 0)
        configureForDrawing()
        for dataPoint in dataArray {
            let xOffset: CGFloat = floor(CGFloat(dataPoint.timeOffset) * viewPixelsPerSec)
            drawDataPointAtXOffset(xOffset, dataPoint: dataPoint)
        }
        finishDrawing()
        
        let imageOfLayerData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return UIImageView(image:imageOfLayerData)
    }
    
    // override for any draw setup
    func configureForDrawing() {
    }

    // override!
    func drawDataPointAtXOffset(_ xOffset: CGFloat, dataPoint: GraphDataType) {
    }
    
    // override for any needed finish up...
    func finishDrawing() {
    }
    
    // override to handle taps - return true if tap has been handled
    func tappedAtPoint(_ point: CGPoint) -> GraphDataType? {
        return nil
    }

}
