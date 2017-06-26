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

class GraphUIView: UIView {

    var layout: GraphLayout
    fileprivate var graphUtils: GraphingUtils
    fileprivate var viewSize: CGSize = CGSize.zero
    fileprivate var graphLayers: [GraphDataLayer] = []
    fileprivate var tileIndex: Int
    fileprivate var cursorView: UIImageView?

    /// After init, call configure to create the graph.
    ///
    /// - parameter startTime:
    ///   The time at the origin of the X axis of the graph.
    ///
    /// - parameter timeIntervalForView:
    ///   The time span covered by the graph
    ///
    /// - parameter layout:
    ///   Provides the various graph layers and layout parameters for drawing them.
    
    init(frame: CGRect, startTime: Date, layout: GraphLayout, tileIndex: Int) {
        self.viewSize = frame.size
        self.cellStartTime = startTime
        self.cellTimeInterval = layout.cellTimeInterval
        self.layout = layout
        self.tileIndex = tileIndex
        self.graphUtils = layout.graphUtilsForTimeInterval(layout.cellTimeInterval, startTime: startTime)
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Graph set up
    ///
    /// Queries the core database for relevant events in the specified timeframe, and creates the graph view with that data.
    
    func configure() {
        graphLayers = layout.graphLayers(viewSize, timeIntervalForView: cellTimeInterval, startTime: cellStartTime, tileIndex: tileIndex)
        graphData()
    }
    
    override func layoutSubviews() {
        //NSLog("GraphUIView layoutSubviews size: \(self.bounds.size)")
    }
    
    func updateViewSize(_ newSize: CGSize) {
        // Quick way to update when data haven't changed...
        let currentSize = self.bounds.size
        NSLog("GraphUIView bounds: \(currentSize), size: \(viewSize), new size \(newSize)")
        if self.viewSize == newSize {
            //NSLog("updateViewSize skipped!")
            return
        }
        self.viewSize = newSize
        graphUtils.updateViewSize(newSize)
        for layer in graphLayers {
            layer.updateViewSize(newSize)
        }
        graphData()
    }
    
    /// Handle taps within this graph tile by letting layers check for hits - iterates thru layers in reverse order of drawing, last layer first. If a data point is found at the tap location, it is returned, otherwise nil.
    func tappedAtPoint(_ point: CGPoint) -> GraphDataType? {
        var layer = graphLayers.count
        while layer > 0 {
            if let dataPoint = graphLayers[layer-1].tappedAtPoint(point) {
                return dataPoint
            }
            layer -= 1
        }
        return nil
    }

    /// Update cursor in view if cursor time range overlaps view, otherwise remove any cursor layer. Pass nil to remove.
    // TODO: If cursor image already exists, just adjust view offset rather than redraw? Probably not worth it if this is just adjusted once a second.
    func updateCursorView(_ cursorTime: Date?, cursorColor: UIColor) {
        if cursorView != nil {
            cursorView!.removeFromSuperview()
            cursorView = nil
        }
        if let cursorTime = cursorTime {
            let graphCursorLayer = GraphCursorLayer(viewSize: self.viewSize, timeIntervalForView: cellTimeInterval, startTime: cellStartTime, cursorTime: cursorTime)
            cursorView = graphCursorLayer.imageView(cursorColor)
            if cursorView != nil {
                addSubview(cursorView!)
            }
        }
    }
    
    //
    // MARK: - Private data
    //
    
    var cellStartTime: Date
    var cellTimeInterval: TimeInterval

    //
    // MARK: - Private funcs
    //

    fileprivate func graphData() {
        // At this point data should be loaded, and we just need to plot the data
        // First remove any previously graphed data in case this is a resizing..
        let views = self.subviews
        for view in views {
            view.removeFromSuperview()
        }
        
        let xAxisImage = graphUtils.imageOfXAxisHeader()
        if let xAxisImage = xAxisImage {
            let xAxisImageView = UIImageView(image:xAxisImage)
            addSubview(xAxisImageView)
        }

        // if not showing the data layers, exit before load
        if !layout.showDataLayers {
            NSLog("data layers suppressed")
            return
        }

        // first load the data for all the layers in case there is any data inter-dependency
        for dataLayer in graphLayers {
            dataLayer.loadDataItems()
        }
        
        // then draw each layer, and add non-empty layers as subviews
        for dataLayer in graphLayers {
            let imageView = dataLayer.imageView()
            if imageView != nil {
                addSubview(imageView!)
            }
        }
        // add optional cursor layer...
        
    }

}
