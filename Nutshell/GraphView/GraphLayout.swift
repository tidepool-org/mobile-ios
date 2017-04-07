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
    let graphCenterTime: Date
    /// Time at x-origin of graph
    let graphStartTime: Date
    /// Time is displayed in the timezone at this offset
    var timezoneOffsetSecs: Int = 0
    /// Time interval covered by the entire graph.
    let graphTimeInterval: TimeInterval
    /// Starts at size of graph view, but varies with zoom.
    var cellViewSize: CGSize
    /// Time interval covered by one graph tile.
    let cellTimeInterval: TimeInterval
    ///
    var graphCellsInCollection: Int
    var graphCellFocusInCollection: Int
    var showDataLayers = true // allow suppression of data layers to just show axes and background...

    /// Use this init to create a graph that starts at a point in time.
    init(viewSize: CGSize, startTime: Date, timeIntervalPerTile: TimeInterval, numberOfTiles: Int, tilesInView: CGFloat, tzOffsetSecs: Int) {
        
        self.graphStartTime = startTime
        self.graphViewSize = viewSize
        self.cellTimeInterval = timeIntervalPerTile
        self.graphCellsInCollection = numberOfTiles
        self.graphCellFocusInCollection = numberOfTiles / 2
        self.graphTimeInterval = timeIntervalPerTile * TimeInterval(numberOfTiles)
        self.cellViewSize = CGSize(width: viewSize.width/tilesInView, height: viewSize.height)
        self.graphCenterTime = startTime.addingTimeInterval(self.graphTimeInterval/2.0)
        self.timezoneOffsetSecs = tzOffsetSecs
    }

    /// Use this init to create a graph centered around a point in time.
    convenience init(viewSize: CGSize, centerTime: Date, startPixelsPerHour: Int, numberOfTiles: Int, tzOffsetSecs: Int) {
        let cellViewSize = viewSize
        let cellTI = TimeInterval(cellViewSize.width * 3600.0/CGFloat(startPixelsPerHour))
        let graphTI = cellTI * TimeInterval(numberOfTiles)
        let startTime = centerTime.addingTimeInterval(-graphTI/2.0)
        self.init(viewSize: viewSize, startTime: startTime, timeIntervalPerTile: cellTI, numberOfTiles: numberOfTiles, tilesInView: 1, tzOffsetSecs: tzOffsetSecs)
    }
    
    /// Call as graph is zoomed in or out!
    func updateCellViewSize(_ newSize: CGSize) {
        self.cellViewSize = newSize
    }
    
    // Override in configure()!

    //
    // Graph sizing/tiling parameters
    //
    var zoomIncrement: CGFloat = 0.8
    // Place x-axis ticks every 8 hours down to every 15 minutes, depending upon the zoom level
    var xAxisLabelTickTimes: [TimeInterval] = [15*60, 30*60, 60*60, 2*60*60, 4*60*60, 8*60*60]
    var curXAxisLabelTickTiming: TimeInterval = 60*60
    var useRelativeTimes: Bool = false
    
    let kMaxPixelsPerTick: CGFloat = 90
    func figureXAxisTickTiming() {
        // We are trying to have about 70-80 pixels per tick...
        let maxTickIndex = xAxisLabelTickTimes.count - 1
        let secondsPerPixel = CGFloat(cellTimeInterval) / cellViewSize.width
        let secondsInGraphView = secondsPerPixel * graphViewSize.width
        var result: TimeInterval = xAxisLabelTickTimes[0]
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
    // Header, footer, and background configuration
    //
    var headerHeight: CGFloat = 32.0
    var footerHeight: CGFloat = 0.0
    var backgroundColor: UIColor = UIColor.gray

    //
    // Y-axis configuration
    //
    var yAxisLineLeftMargin: CGFloat = 20.0
    var yAxisLineRightMargin: CGFloat = 10.0
    var yAxisLineColor: UIColor = UIColor.black
    var yAxisValuesWithLines: [Int] = []
    // left side labels, corresponding to yAxisRange and yAxisBase
    var yAxisValuesWithLabels: [Int] = []
    var yAxisRange: CGFloat = 0.0
    var yAxisBase: CGFloat = 0.0
    var yAxisPixels: CGFloat = 0.0
    // right side labels can have a different range and base
    var yAxisValuesWithRightEdgeLabels: [Int] = []
    var yAxisRightRange: CGFloat = 0.0
    var yAxisRightBase: CGFloat = 0.0

    //
    // Y-axis and X-axis configuration
    //
    var axesLabelTextColor: UIColor = UIColor.black
    var axesLabelTextFont: UIFont = UIFont.systemFont(ofSize: 12.0)
    var axesLeftLabelTextColor: UIColor = UIColor.black
    var axesRightLabelTextColor: UIColor = UIColor.black
    
    //
    // X-axis configuration
    //
    var hourMarkerStrokeColor = UIColor.black
    var largestXAxisDateWidth: CGFloat = 30.0
    var xLabelRegularFont = UIFont.systemFont(ofSize: 9.0)
    var xLabelLightFont = UIFont.systemFont(ofSize: 8.0)
    
    //
    // Methods to override!
    //

    func graphUtilsForGraphView() -> GraphingUtils {
        return GraphingUtils(layout: self, timeIntervalForView: self.graphTimeInterval, startTime: self.graphStartTime, viewSize: self.graphViewSize)
    }

    func graphUtilsForTimeInterval(_ timeIntervalForView: TimeInterval, startTime: Date) -> GraphingUtils {
        return GraphingUtils(layout: self, timeIntervalForView: timeIntervalForView, startTime: startTime, viewSize: self.cellViewSize)
    }
    
    func configureGraph() {
        
    }
    
    /// Returns the various layers used to compose the graph, other than the fixed background, and X-axis time values.
    func graphLayers(_ viewSize: CGSize, timeIntervalForView: TimeInterval, startTime: Date, tileIndex: Int) -> [GraphDataLayer] {
        return []
    }
  
}
