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
    var viewSize: CGSize = CGSizeZero
    var timeIntervalForView: NSTimeInterval
    var startTime: NSDate
    var dataType: GraphDataType
    var layout: GraphLayout

    // dataPoint array, configured later by GraphDataSource
    var dataArray: [GraphDataType] = []

    // useful variables for subclasses and data source
    var timeExtensionForDataFetch: NSTimeInterval = 0.0
    var viewPixelsPerSec: CGFloat = 0.0

    init(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate, dataType: GraphDataType, layout: GraphLayout) {
        self.viewSize = viewSize
        self.timeIntervalForView = timeIntervalForView
        self.startTime = startTime
        self.dataType = dataType
        self.layout = layout
        self.configureGraphParameters()
    }

    func updateViewSize(newSize: CGSize) {
        self.viewSize = newSize
        self.configureGraphParameters()
    }
    
    private let kLargestGraphItemWidth: CGFloat = 30.0
    private func configureGraphParameters() {
        self.viewPixelsPerSec = viewSize.width/CGFloat(timeIntervalForView)
        // calculate the extra time we need data fetched for at the end of the graph time span so we draw the beginnings of next graph items
        timeExtensionForDataFetch = NSTimeInterval(kLargestGraphItemWidth/viewPixelsPerSec)
        self.configure()
    }
    
    func imageView(graphDraw: GraphingUtils) -> UIImageView? {
        if dataArray.count == 0 {
            return nil
        }
        UIGraphicsBeginImageContextWithOptions(viewSize, false, 0)
        configureForDrawing()
        for dataPoint in dataArray {
            let xOffset: CGFloat = floor(CGFloat(dataPoint.timeOffset) * viewPixelsPerSec)
            drawDataPointAtXOffset(xOffset, dataPoint: dataPoint, graphDraw: graphDraw)
        }
        finishDrawing()
        
        let imageOfCbgData = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return UIImageView(image:imageOfCbgData)
    }
    
    // override for any post-init or size-change configuration
    func configure() {
    }
    
    // override for any draw setup
    func configureForDrawing() {
    }

    // override!
    func drawDataPointAtXOffset(xOffset: CGFloat, dataPoint: GraphDataType, graphDraw: GraphingUtils) {
    }
    
    // override for any needed finish up...
    func finishDrawing() {
    }
}