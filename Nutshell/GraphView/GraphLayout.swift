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

/// Provides an ordered array of GraphDataLayer objects.
class GraphLayout {
    
    let graphViewSize: CGSize
    let graphCenterTime: NSDate
    /// Time at x-origin of graph
    let graphStartTime: NSDate
    /// Time is displayed in the timezone at this offset
    var timezoneOffsetSecs: Int = 0
    /// Time interval covered by the entire graph.
    let graphTimeInterval: NSTimeInterval
    /// Starts at size of graph view, but varies with zoom.
    var cellViewSize: CGSize
    /// Time interval covered by one graph tile.
    let cellTimeInterval: NSTimeInterval
    ///
    var graphCellsInCollection: Int
    var graphCellFocusInCollection: Int

    /// Use this init to create a graph that starts at a point in time.
    init(viewSize: CGSize, startTime: NSDate, timeIntervalPerTile: NSTimeInterval, numberOfTiles: Int, tilesInView: Int, tzOffsetSecs: Int) {
        
        self.graphStartTime = startTime
        self.graphViewSize = viewSize
        self.cellTimeInterval = timeIntervalPerTile
        self.graphCellsInCollection = numberOfTiles
        self.graphCellFocusInCollection = numberOfTiles / 2
        self.graphTimeInterval = timeIntervalPerTile * NSTimeInterval(numberOfTiles)
        self.cellViewSize = CGSize(width: viewSize.width/(CGFloat(tilesInView)), height: viewSize.height)
        self.graphCenterTime = startTime.dateByAddingTimeInterval(self.graphTimeInterval/2.0)
        self.timezoneOffsetSecs = tzOffsetSecs
    }

    /// Use this init to create a graph centered around a point in time.
    convenience init(viewSize: CGSize, centerTime: NSDate, startPixelsPerHour: Int, numberOfTiles: Int, tzOffsetSecs: Int) {
        let cellViewSize = viewSize
        let cellTI = NSTimeInterval(cellViewSize.width * 3600.0/CGFloat(startPixelsPerHour))
        let graphTI = cellTI * NSTimeInterval(numberOfTiles)
        let startTime = centerTime.dateByAddingTimeInterval(-graphTI/2.0)
        self.init(viewSize: viewSize, startTime: startTime, timeIntervalPerTile: cellTI, numberOfTiles: numberOfTiles, tilesInView: 1, tzOffsetSecs: tzOffsetSecs)
    }
    
    /// Call as graph is zoomed in or out!
    func updateCellViewSize(newSize: CGSize) {
        self.cellViewSize = newSize
    }
    
    // Override in configure()!

    //
    // Graph sizing/tiling parameters
    //
    var zoomIncrement: CGFloat = 0.8
    // Place x-axis ticks every 8 hours down to every 15 minutes, depending upon the zoom level
    var xAxisLabelTickTimes: [NSTimeInterval] = [15*60, 30*60, 60*60, 2*60*60, 4*60*60, 8*60*60]
    var curXAxisLabelTickTiming: NSTimeInterval = 60*60
    
    let kMaxPixelsPerTick: CGFloat = 90
    func figureXAxisTickTiming() {
        // We are trying to have about 70-80 pixels per tick...
        let maxTickIndex = xAxisLabelTickTimes.count - 1
        let secondsPerPixel = CGFloat(cellTimeInterval) / cellViewSize.width
        let secondsInGraphView = secondsPerPixel * graphViewSize.width
        var result: NSTimeInterval = xAxisLabelTickTimes[0]
        for index in 0...maxTickIndex  {
            let timePerTick = xAxisLabelTickTimes[index]
            let ticksInView = secondsInGraphView / CGFloat(timePerTick)
            let pixelsPerTick = graphViewSize.width / ticksInView
            if pixelsPerTick > kMaxPixelsPerTick {
                break
            }
            result = timePerTick
        }
        if curXAxisLabelTickTiming != result {
            curXAxisLabelTickTiming = result
            NSLog("New x-axis tick time interval = \(result)")
        }
    }
    
    /// Somewhat arbitrary max cell width.
    func zoomInMaxCellWidth() -> CGFloat {
        return min((4 * graphViewSize.width), 2000.0)
    }
    
    /// Cells need to at least cover the view width.
    func zoomOutMinCellWidth() -> CGFloat {
        return graphViewSize.width / CGFloat(graphCellsInCollection)
    }

    //
    // Header and background configuration
    //
    var headerHeight: CGFloat = 32.0
    var backgroundColor: UIColor = UIColor.grayColor()

    //
    // Y-axis configuration
    //
    var yAxisLineLeftMargin: CGFloat = 20.0
    var yAxisLineRightMargin: CGFloat = 10.0
    var yAxisLineColor: UIColor = UIColor.blackColor()
    var yAxisValuesWithLines: [Int] = []
    var yAxisValuesWithLabels: [Int] = []
    var yAxisRange: CGFloat = 0.0
    var yAxisBase: CGFloat = 0.0
    var yAxisPixels: CGFloat = 0.0
    
    //
    // Y-axis and X-axis configuration
    //
    var axesLabelTextColor: UIColor = UIColor.blackColor()
    var axesLabelTextFont: UIFont = UIFont.systemFontOfSize(12.0)
    
    //
    // X-axis configuration
    //
    var hourMarkerStrokeColor = UIColor.blackColor()
    var largestXAxisDateWidth: CGFloat = 80.0
    var xLabelRegularFont = UIFont.systemFontOfSize(9.0)
    var xLabelLightFont = UIFont.systemFontOfSize(8.0)
    
    //
    // Methods to override!
    //

    func graphUtilsForGraphView() -> GraphingUtils {
        return GraphingUtils(layout: self, timeIntervalForView: self.graphTimeInterval, startTime: self.graphStartTime, viewSize: self.graphViewSize)
    }

    func graphUtilsForTimeInterval(timeIntervalForView: NSTimeInterval, startTime: NSDate) -> GraphingUtils {
        return GraphingUtils(layout: self, timeIntervalForView: timeIntervalForView, startTime: startTime, viewSize: self.cellViewSize)
    }
    
    func configureGraph() {
        
    }
    
    /// Returns the various layers used to compose the graph, other than the fixed background, and X-axis time values.
    func graphLayers(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate, tileIndex: Int) -> [GraphDataLayer] {
        return []
    }
  
}
