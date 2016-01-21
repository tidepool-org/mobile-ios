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
    var timezoneOffsetSecs: Int
    /// Time interval covered by the entire graph.
    let graphTimeInterval: NSTimeInterval
    /// Starts at size of graph view, but varies with zoom.
    var cellViewSize: CGSize
    /// Time interval covered by one graph tile.
    let cellTimeInterval: NSTimeInterval
    /// Density of time on x-axis
    var graphPixelsPerSec: CGFloat = 0.0

    init (viewSize: CGSize, centerTime: NSDate, tzOffsetSecs: Int) {
        self.graphViewSize = viewSize
        self.cellViewSize = viewSize
        self.cellTimeInterval = NSTimeInterval(graphViewSize.width * 3600.0/initPixelsPerHour)
        self.graphTimeInterval = self.cellTimeInterval * NSTimeInterval(graphCellsInCollection)
        self.graphCenterTime = centerTime
        self.graphStartTime = centerTime.dateByAddingTimeInterval(-self.graphTimeInterval/2.0)
        self.timezoneOffsetSecs = tzOffsetSecs
    }
    
    /// Call as graph is zoomed in or out!
    func updateCellViewSize(newSize: CGSize) {
        self.cellViewSize = newSize
        self.graphPixelsPerSec = newSize.width/CGFloat(cellTimeInterval)
    }
    
    // Override in configure()!

    //
    // Graph sizing/tiling parameters
    //
    var initPixelsPerHour: CGFloat = 80
    var zoomIncrement: CGFloat = 0.8
    
    let graphCellsInCollection = 7
    let graphCenterCellInCollection = 3

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
    var hourMarkerStrokeColor = UIColor(hex: 0xe2e4e7)
    var largestXAxisDateWidth: CGFloat = 30.0

    //
    // Methods to override!
    //

    func configureGraph() {
        
    }
    
    /// Returns the various layers used to compose the graph, other than the fixed background, and X-axis time values.
    func graphLayers(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate) -> [GraphDataLayer] {
        return []
    }
  
}
