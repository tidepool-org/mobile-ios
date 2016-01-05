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
    
    var viewSize: CGSize
    init (viewSize: CGSize) {
        self.viewSize = viewSize
    }
    
    // Override in configure()!

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

    /// Set the configuration variables here
    func configure (viewSize: CGSize) {
        self.viewSize = viewSize
    }
    
    /// Returns the various layers used to compose the graph, other than the fixed background, and X-axis time values.
    func graphLayers(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate) -> [GraphDataLayer] {
        return []
    }
  
}
